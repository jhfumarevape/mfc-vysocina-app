"""Chat groups + messages REST endpoints (sending also via WebSocket)."""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import desc, func

from ..database import get_db
from ..models import Group, GroupMember, Message, User
from ..schemas import GroupCreate, GroupOut, MessageCreate, MessageOut, UserOut
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/groups", tags=["groups"])


def _membership_or_403(db: Session, group_id: int, user_id: int) -> GroupMember:
    membership = (
        db.query(GroupMember)
        .filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id)
        .first()
    )
    if not membership:
        raise HTTPException(403, "Nejsi členem této skupiny")
    return membership


def _serialize_group(g: Group, db: Session, user_id: int) -> dict:
    membership = next((m for m in g.members if m.user_id == user_id), None)
    last_msg = (
        db.query(Message)
        .filter(Message.group_id == g.id)
        .order_by(desc(Message.created_at))
        .first()
    )
    unread = 0
    if membership and membership.last_read_at:
        unread = (
            db.query(func.count(Message.id))
            .filter(Message.group_id == g.id, Message.created_at > membership.last_read_at)
            .scalar() or 0
        )
    return {
        "id": g.id,
        "name": g.name,
        "description": g.description,
        "member_count": len(g.members),
        "last_message_at": last_msg.created_at if last_msg else None,
        "last_message_preview": (last_msg.content[:80] if last_msg else None),
        "unread_count": unread,
    }


@router.get("", response_model=list[GroupOut])
def list_my_groups(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """List groups the user is member of, ordered by latest message."""
    groups = (
        db.query(Group)
        .options(joinedload(Group.members))
        .join(GroupMember, GroupMember.group_id == Group.id)
        .filter(GroupMember.user_id == user.id)
        .all()
    )
    serialized = [_serialize_group(g, db, user.id) for g in groups]
    serialized.sort(key=lambda x: x["last_message_at"] or datetime.min, reverse=True)
    return serialized


@router.post("", response_model=GroupOut, status_code=201)
def create_group(
    payload: GroupCreate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("groups.create")),
):
    g = Group(name=payload.name, description=payload.description, created_by_id=user.id)
    db.add(g)
    db.flush()
    # Always add creator as admin member
    db.add(GroupMember(group_id=g.id, user_id=user.id, is_admin=True))
    # Add other members
    if payload.member_ids:
        for uid in payload.member_ids:
            if uid == user.id:
                continue
            db.add(GroupMember(group_id=g.id, user_id=uid))
    db.commit()
    db.refresh(g)
    g = db.query(Group).options(joinedload(Group.members)).filter(Group.id == g.id).first()
    return _serialize_group(g, db, user.id)


@router.get("/{group_id}/members", response_model=list[UserOut])
def list_members(group_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    _membership_or_403(db, group_id, user.id)
    members = (
        db.query(User)
        .join(GroupMember, GroupMember.user_id == User.id)
        .filter(GroupMember.group_id == group_id)
        .order_by(User.username)
        .all()
    )
    return members


@router.patch("/{group_id}", response_model=GroupOut)
def update_group(
    group_id: int,
    payload: GroupCreate,  # reuse: only name/description matter
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """Rename group / change description.

    Allowed for: group admin, or holder of groups.delete_any (super-admin level).
    """
    g = db.query(Group).options(joinedload(Group.members)).filter(Group.id == group_id).first()
    if not g:
        raise HTTPException(404, "Skupina nenalezena")

    membership = next((m for m in g.members if m.user_id == user.id), None)
    is_group_admin = membership is not None and membership.is_admin
    if not is_group_admin and not has_permission(user, "groups.delete_any", db):
        raise HTTPException(403, "Pouze admin skupiny nebo držitel oprávnění groups.delete_any")

    g.name = payload.name
    if payload.description is not None:
        g.description = payload.description
    db.commit()
    db.refresh(g)
    g = db.query(Group).options(joinedload(Group.members)).filter(Group.id == g.id).first()
    return _serialize_group(g, db, user.id)


@router.delete("/{group_id}", status_code=204)
def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """Delete a chat group + all its messages.

    Allowed for: group admin, or holder of groups.delete_any.
    Default group cannot be deleted.
    """
    g = db.query(Group).options(joinedload(Group.members)).filter(Group.id == group_id).first()
    if not g:
        raise HTTPException(404, "Skupina nenalezena")
    if g.is_default:
        raise HTTPException(400, "Hlavní skupinu nelze smazat")

    membership = next((m for m in g.members if m.user_id == user.id), None)
    is_group_admin = membership is not None and membership.is_admin
    if not is_group_admin and not has_permission(user, "groups.delete_any", db):
        raise HTTPException(403, "Pouze admin skupiny nebo držitel oprávnění groups.delete_any")

    db.delete(g)  # cascades to members + messages
    db.commit()


@router.post("/{group_id}/members/{user_id}", status_code=204)
def add_member(group_id: int, user_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    membership = _membership_or_403(db, group_id, user.id)
    if not membership.is_admin and not has_permission(user, "groups.add_member_any", db):
        raise HTTPException(403, "Pouze admin skupiny nebo držitel oprávnění groups.add_member_any")
    exists = db.query(GroupMember).filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id).first()
    if exists:
        return
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(404, "Uživatel nenalezen")
    db.add(GroupMember(group_id=group_id, user_id=user_id))
    db.commit()


@router.delete("/{group_id}/members/{user_id}", status_code=204)
def remove_member(group_id: int, user_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    membership = _membership_or_403(db, group_id, user.id)
    # Allow self-leave, group-admin, or holder of groups.remove_member_any
    if (user.id != user_id
            and not membership.is_admin
            and not has_permission(user, "groups.remove_member_any", db)):
        raise HTTPException(403, "Pouze admin skupiny nebo sám sebe")
    db.query(GroupMember).filter(GroupMember.group_id == group_id, GroupMember.user_id == user_id).delete()
    db.commit()


@router.get("/{group_id}/messages", response_model=list[MessageOut])
def list_messages(
    group_id: int,
    before_id: Optional[int] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    _membership_or_403(db, group_id, user.id)
    q = db.query(Message).options(joinedload(Message.author)).filter(Message.group_id == group_id)
    if before_id:
        q = q.filter(Message.id < before_id)
    msgs = q.order_by(desc(Message.id)).limit(limit).all()
    msgs.reverse()  # return oldest-first
    return msgs


@router.post("/{group_id}/messages", response_model=MessageOut, status_code=201)
def send_message(group_id: int, payload: MessageCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    _membership_or_403(db, group_id, user.id)
    if not has_permission(user, "messages.send", db):
        raise HTTPException(403, "Chybí oprávnění: messages.send")
    msg = Message(
        group_id=group_id, author_id=user.id,
        content=payload.content, image_url=payload.image_url,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    msg = db.query(Message).options(joinedload(Message.author)).filter(Message.id == msg.id).first()
    return msg


@router.post("/{group_id}/read", status_code=204)
def mark_read(group_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Mark group as read up to now (for unread counts)."""
    membership = _membership_or_403(db, group_id, user.id)
    membership.last_read_at = datetime.utcnow()
    db.commit()


@router.get("/users", response_model=list[UserOut])
def list_all_users(db: Session = Depends(get_db), _user=Depends(get_current_user)):
    """Used when creating groups — list of users to pick from."""
    return db.query(User).filter(User.is_active == True).order_by(User.username).all()
