"""Admin endpoints: user management + roles + permissions."""
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func

from ..database import get_db
from ..models import User, Role, RolePermission, Event, Group, GroupMember, Message, Post, RSVP
from ..schemas import (
    UserAdminOut, UserAdminUpdate,
    PermissionInfo, RoleCreate, RoleUpdate, RoleOut,
    MePermissionsOut,
)
from ..auth import get_current_user, require_permission, get_user_permissions
from ..permissions import PERMISSIONS, SYSTEM_ROLES, is_valid_permission

router = APIRouter(prefix="/admin", tags=["admin"])


# ─── /me/permissions (any authenticated user can call this) ───────────

me_router = APIRouter(prefix="/auth", tags=["auth"])


@me_router.get("/me/permissions", response_model=MePermissionsOut)
def my_permissions(db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Returns the current user's role and effective permissions list.

    Mobile app should call this after login to know what UI elements to show/hide.
    """
    perms = sorted(get_user_permissions(user, db))
    return MePermissionsOut(role=user.role, permissions=perms)


# ─── User management ──────────────────────────────────────────────────

@router.get("/users", response_model=List[UserAdminOut])
def list_users(
    db: Session = Depends(get_db),
    _user=Depends(require_permission("users.list")),
):
    return db.query(User).order_by(User.id).all()


@router.patch("/users/{user_id}", response_model=UserAdminOut)
def update_user(
    user_id: int,
    payload: UserAdminUpdate,
    db: Session = Depends(get_db),
    current=Depends(get_current_user),
):
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(404, "Uživatel nenalezen")

    data = payload.model_dump(exclude_unset=True)

    # Role change requires users.update_role
    if "role" in data and data["role"] != target.role:
        perms = get_user_permissions(current, db)
        if "users.update_role" not in perms:
            raise HTTPException(403, "Chybí oprávnění: users.update_role")
        # Verify new role exists
        new_role = db.query(Role).filter(Role.name == data["role"]).first()
        if not new_role:
            raise HTTPException(400, f"Role '{data['role']}' neexistuje")
        # Prevent demoting yourself out of admin (would lock you out)
        if current.id == target.id and target.role == "admin" and data["role"] != "admin":
            raise HTTPException(400, "Nemůžeš si sám sebrat admin roli")

    # is_active change requires users.deactivate
    if "is_active" in data and data["is_active"] != target.is_active:
        perms = get_user_permissions(current, db)
        if "users.deactivate" not in perms:
            raise HTTPException(403, "Chybí oprávnění: users.deactivate")
        if current.id == target.id and not data["is_active"]:
            raise HTTPException(400, "Nemůžeš deaktivovat sám sebe")

    # full_name editing - let user-management permission cover this too
    for field, value in data.items():
        setattr(target, field, value)

    db.commit()
    db.refresh(target)
    return target


@router.delete("/users/{user_id}", status_code=204)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current=Depends(require_permission("users.delete")),
):
    target = db.query(User).filter(User.id == user_id).first()
    if not target:
        raise HTTPException(404, "Uživatel nenalezen")
    if current.id == target.id:
        raise HTTPException(400, "Nemůžeš smazat sám sebe")

    # Reassign created_by to current admin to avoid FK violations
    db.query(Event).filter(Event.created_by_id == user_id).update({Event.created_by_id: current.id})
    db.query(Group).filter(Group.created_by_id == user_id).update({Group.created_by_id: current.id})

    db.delete(target)
    db.commit()


# ─── Permissions catalog ──────────────────────────────────────────────

@router.get("/permissions", response_model=List[PermissionInfo])
def list_permissions(_user=Depends(require_permission("roles.manage"))):
    """Returns the master list of available permissions in the application."""
    return [
        PermissionInfo(key=k, group=group, description=desc)
        for k, (group, desc) in PERMISSIONS.items()
    ]


# ─── Roles management ─────────────────────────────────────────────────

def _serialize_role(r: Role, db: Session) -> dict:
    perm_keys = [p.permission_key for p in r.permissions]
    # admin role always reports full permission set (defensive)
    if r.name == "admin":
        perm_keys = list(PERMISSIONS.keys())
    user_count = db.query(func.count(User.id)).filter(User.role == r.name).scalar() or 0
    return {
        "id": r.id,
        "name": r.name,
        "description": r.description,
        "is_system": r.is_system,
        "permissions": sorted(perm_keys),
        "user_count": user_count,
    }


@router.get("/roles", response_model=List[RoleOut])
def list_roles(
    db: Session = Depends(get_db),
    _user=Depends(require_permission("roles.manage")),
):
    roles = db.query(Role).options(joinedload(Role.permissions)).order_by(Role.id).all()
    return [_serialize_role(r, db) for r in roles]


@router.post("/roles", response_model=RoleOut, status_code=201)
def create_role(
    payload: RoleCreate,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("roles.manage")),
):
    if db.query(Role).filter(Role.name == payload.name).first():
        raise HTTPException(400, f"Role '{payload.name}' už existuje")
    # Validate permission keys
    for k in payload.permissions:
        if not is_valid_permission(k):
            raise HTTPException(400, f"Neznámé oprávnění: {k}")

    role = Role(name=payload.name, description=payload.description, is_system=False)
    db.add(role)
    db.flush()
    for k in set(payload.permissions):
        db.add(RolePermission(role_id=role.id, permission_key=k))
    db.commit()
    db.refresh(role)
    return _serialize_role(role, db)


@router.patch("/roles/{role_id}", response_model=RoleOut)
def update_role(
    role_id: int,
    payload: RoleUpdate,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("roles.manage")),
):
    role = db.query(Role).filter(Role.id == role_id).first()
    if not role:
        raise HTTPException(404, "Role nenalezena")

    if payload.description is not None:
        role.description = payload.description

    if payload.permissions is not None:
        # admin always has full permissions — silently ignore attempted edits
        if role.name == "admin":
            db.commit()
            db.refresh(role)
            return _serialize_role(role, db)

        # validate
        for k in payload.permissions:
            if not is_valid_permission(k):
                raise HTTPException(400, f"Neznámé oprávnění: {k}")

        # replace
        db.query(RolePermission).filter(RolePermission.role_id == role.id).delete()
        for k in set(payload.permissions):
            db.add(RolePermission(role_id=role.id, permission_key=k))

    db.commit()
    db.refresh(role)
    return _serialize_role(role, db)


@router.delete("/roles/{role_id}", status_code=204)
def delete_role(
    role_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("roles.manage")),
):
    role = db.query(Role).filter(Role.id == role_id).first()
    if not role:
        raise HTTPException(404, "Role nenalezena")
    if role.name in SYSTEM_ROLES:
        raise HTTPException(400, f"Systémovou roli '{role.name}' nelze smazat")

    # Demote all users with this role to 'member'
    db.query(User).filter(User.role == role.name).update({User.role: "member"})
    db.delete(role)
    db.commit()


# ─── Stats / overview ─────────────────────────────────────────────────

@router.get("/stats")
def admin_stats(
    db: Session = Depends(get_db),
    _user=Depends(require_permission("admin.access")),
):
    """Souhrnna cisla pro admin dashboard."""
    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    five_min_ago = now - timedelta(minutes=5)

    return {
        "total_users": db.query(func.count(User.id)).filter(User.is_active == True).scalar() or 0,
        "online_users": (
            db.query(func.count(User.id))
            .filter(User.is_active == True, User.created_at != None)  # placeholder
            .scalar() or 0
        ),  # Note: User model nema 'last_seen' fieldu, takze online=0 zatim
        "active_users_7d": db.query(func.count(User.id)).filter(User.created_at > week_ago).scalar() or 0,
        "total_posts": db.query(func.count(Post.id)).scalar() or 0,
        "total_events": db.query(func.count(Event.id)).scalar() or 0,
        "total_messages": db.query(func.count(Message.id)).scalar() or 0,
    }


# ─── Events admin (list + delete) ─────────────────────────────────────

@router.get("/events")
def admin_list_events(
    db: Session = Depends(get_db),
    _user=Depends(require_permission("events.delete_any")),
):
    """List vsech akci pro admin tab — incl. rsvp_count."""
    rows = db.query(Event).order_by(Event.starts_at.desc()).all()
    out = []
    for e in rows:
        rsvp_count = db.query(func.count(RSVP.id)).filter(RSVP.event_id == e.id).scalar() or 0
        out.append({
            "id": e.id,
            "title": e.title,
            "event_type": e.event_type,
            "location": e.location,
            "starts_at": e.starts_at.isoformat() if e.starts_at else None,
            "rsvp_count": rsvp_count,
        })
    return out


@router.delete("/events/{event_id}", status_code=204)
def admin_delete_event(
    event_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("events.delete_any")),
):
    e = db.query(Event).filter(Event.id == event_id).first()
    if not e:
        raise HTTPException(404, "Akce neexistuje")
    db.delete(e)
    db.commit()


# ─── Groups admin (list + toggle-default + delete) ────────────────────

@router.get("/groups")
def admin_list_groups(
    db: Session = Depends(get_db),
    _user=Depends(require_permission("groups.delete_any")),
):
    """List všech skupin (i těch, kde admin není member) s počty."""
    rows = db.query(Group).order_by(Group.id).all()
    out = []
    for g in rows:
        member_count = db.query(func.count(GroupMember.id)).filter(GroupMember.group_id == g.id).scalar() or 0
        message_count = db.query(func.count(Message.id)).filter(Message.group_id == g.id).scalar() or 0
        out.append({
            "id": g.id,
            "name": g.name,
            "description": g.description,
            "is_default": g.is_default,
            "member_count": member_count,
            "message_count": message_count,
        })
    return out


@router.post("/groups/{group_id}/toggle-default")
def admin_toggle_default(
    group_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("groups.delete_any")),
):
    """Přepne flag is_default. Pokud zapínáme → přidá VŠECHNY existující
    aktivní uživatele do skupiny (ti, co už členi nejsou). Vypínání
    nikoho nevyhazuje — jen budoucí registrace nebudou auto-join."""
    g = db.query(Group).filter(Group.id == group_id).first()
    if not g:
        raise HTTPException(404, "Skupina neexistuje")

    g.is_default = not g.is_default
    added = 0
    if g.is_default:
        # Přidej všechny aktivní uživatele co tam ještě nejsou
        existing_member_ids = {m.user_id for m in db.query(GroupMember).filter(GroupMember.group_id == g.id).all()}
        all_active = db.query(User).filter(User.is_active == True).all()
        for u in all_active:
            if u.id not in existing_member_ids:
                db.add(GroupMember(group_id=g.id, user_id=u.id))
                added += 1
    db.commit()
    return {
        "id": g.id,
        "is_default": g.is_default,
        "newly_added": added,
        "message": f"Přidáno {added} členů" if added else "is_default přepnut",
    }


@router.delete("/groups/{group_id}", status_code=204)
def admin_delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_permission("groups.delete_any")),
):
    g = db.query(Group).filter(Group.id == group_id).first()
    if not g:
        raise HTTPException(404, "Skupina neexistuje")
    if g.is_default:
        raise HTTPException(400, "Defaultní skupinu nelze smazat — nejdřív zruš 'is_default'")
    db.delete(g)
    db.commit()
