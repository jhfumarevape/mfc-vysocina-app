"""Posts (news feed / info panel) endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import desc

from ..database import get_db
from ..models import Post, User
from ..schemas import PostCreate, PostOut
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/posts", tags=["posts"])


@router.get("", response_model=list[PostOut])
def list_posts(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    _user=Depends(get_current_user),
):
    rows = (
        db.query(Post)
        .options(joinedload(Post.author))
        .order_by(desc(Post.pinned), desc(Post.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )
    return rows


@router.post("", response_model=PostOut, status_code=201)
def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),
):
    post = Post(author_id=user.id, content=payload.content, image_url=payload.image_url)
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


@router.delete("/{post_id}", status_code=204)
def delete_post(post_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")

    is_owner = post.author_id == user.id
    if is_owner:
        if not has_permission(user, "posts.delete_own", db):
            raise HTTPException(403, "Chybí oprávnění: posts.delete_own")
    else:
        if not has_permission(user, "posts.delete_any", db):
            raise HTTPException(403, "Chybí oprávnění: posts.delete_any")

    db.delete(post)
    db.commit()


@router.post("/{post_id}/pin", response_model=PostOut)
def pin_post(
    post_id: int,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.pin")),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")
    post.pinned = not post.pinned
    db.commit()
    db.refresh(post)
    return post
