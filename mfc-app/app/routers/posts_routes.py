"""Posts (news feed / info panel) endpoints — incl. reactions, comments, polls."""
from datetime import datetime
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import desc, func

from ..database import get_db
from ..models import (
    Post, User, PostReaction, PostComment,
    Poll, PollOption, PollVote,
)
from ..schemas import (
    PostCreate, PostCreateExtended, PostOut,
    CommentCreate, CommentOut,
    PollOut, PollOptionOut,
)
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/posts", tags=["posts"])


# Povolená emoji (zabraňuje DB záplavě jakýmkoliv stringem)
ALLOWED_EMOJI = {"👍", "❤️", "💪", "😄", "🔥", "🛡️", "⚔️", "🏆"}


# ─── Helpers ──────────────────────────────────────────────────────────

def _serialize_poll(poll: Poll, db: Session, user_id: int) -> dict[str, Any]:
    """Returns a dict matching PollOut shape — including per-option vote counts."""
    options = []
    total = 0
    for opt in poll.options:
        count = db.query(func.count(PollVote.id)).filter(PollVote.option_id == opt.id).scalar() or 0
        voted = (
            db.query(PollVote)
            .filter(PollVote.option_id == opt.id, PollVote.user_id == user_id)
            .first()
        ) is not None
        options.append({
            "id": opt.id,
            "label": opt.label,
            "vote_count": count,
            "voted": voted,
        })
        total += count
    return {
        "id": poll.id,
        "question": poll.question,
        "multiple_choice": poll.multiple_choice,
        "closes_at": poll.closes_at,
        "total_votes": total,
        "options": options,
    }


def _serialize_post(post: Post, db: Session, user_id: int) -> dict[str, Any]:
    # Reactions: emoji -> count
    rows = (
        db.query(PostReaction.emoji, func.count(PostReaction.id))
        .filter(PostReaction.post_id == post.id)
        .group_by(PostReaction.emoji)
        .all()
    )
    reactions = {e: c for e, c in rows}

    my_emojis = [
        r.emoji for r in
        db.query(PostReaction).filter(PostReaction.post_id == post.id, PostReaction.user_id == user_id).all()
    ]

    comment_count = (
        db.query(func.count(PostComment.id))
        .filter(PostComment.post_id == post.id)
        .scalar()
    ) or 0

    poll_obj = db.query(Poll).filter(Poll.post_id == post.id).first()
    poll_data = _serialize_poll(poll_obj, db, user_id) if poll_obj else None

    return {
        "id": post.id,
        "author": post.author,
        "content": post.content,
        "image_url": post.image_url,
        "pinned": post.pinned,
        "created_at": post.created_at,
        "reactions": reactions,
        "my_reactions": my_emojis,
        "comment_count": comment_count,
        "poll": poll_data,
    }


# ─── List + create ────────────────────────────────────────────────────

@router.get("", response_model=list[PostOut])
def list_posts(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    rows = (
        db.query(Post)
        .options(joinedload(Post.author))
        .order_by(desc(Post.pinned), desc(Post.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_serialize_post(p, db, user.id) for p in rows]


@router.post("", response_model=PostOut, status_code=201)
def create_post(
    payload: PostCreateExtended,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),
):
    post = Post(author_id=user.id, content=payload.content, image_url=payload.image_url)
    db.add(post)
    db.flush()

    # Volitelná anketa
    if payload.poll:
        poll = Poll(
            post_id=post.id,
            question=payload.poll.question,
            multiple_choice=payload.poll.multiple_choice,
            closes_at=payload.poll.closes_at,
        )
        db.add(poll)
        db.flush()
        for i, opt in enumerate(payload.poll.options):
            db.add(PollOption(poll_id=poll.id, label=opt.label, sort_order=i))

    db.commit()
    db.refresh(post)
    # joinedload by se hodil, ale jednoduššeji: re-query
    post = db.query(Post).options(joinedload(Post.author)).filter(Post.id == post.id).first()
    return _serialize_post(post, db, user.id)


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
    post = db.query(Post).options(joinedload(Post.author)).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")
    post.pinned = not post.pinned
    db.commit()
    db.refresh(post)
    return _serialize_post(post, db, user.id)


# ─── Reactions ────────────────────────────────────────────────────────

@router.post("/{post_id}/react/{emoji}", response_model=PostOut)
def toggle_reaction(
    post_id: int,
    emoji: str,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """Toggle reaction (add if missing, remove if present)."""
    if emoji not in ALLOWED_EMOJI:
        raise HTTPException(400, f"Emoji '{emoji}' není povolený. Použij jedno z: {', '.join(ALLOWED_EMOJI)}")

    post = db.query(Post).options(joinedload(Post.author)).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")

    existing = (
        db.query(PostReaction)
        .filter(
            PostReaction.post_id == post_id,
            PostReaction.user_id == user.id,
            PostReaction.emoji == emoji,
        )
        .first()
    )
    if existing:
        db.delete(existing)
    else:
        db.add(PostReaction(post_id=post_id, user_id=user.id, emoji=emoji))
    db.commit()
    return _serialize_post(post, db, user.id)


# ─── Comments ─────────────────────────────────────────────────────────

@router.get("/{post_id}/comments", response_model=list[CommentOut])
def list_comments(
    post_id: int,
    db: Session = Depends(get_db),
    _user=Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")
    return (
        db.query(PostComment)
        .options(joinedload(PostComment.author))
        .filter(PostComment.post_id == post_id)
        .order_by(PostComment.created_at.asc())
        .all()
    )


@router.post("/{post_id}/comments", response_model=CommentOut, status_code=201)
def add_comment(
    post_id: int,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(404, "Příspěvek nenalezen")
    c = PostComment(post_id=post_id, author_id=user.id, content=payload.content.strip())
    db.add(c)
    db.commit()
    db.refresh(c)
    return db.query(PostComment).options(joinedload(PostComment.author)).filter(PostComment.id == c.id).first()


@router.delete("/{post_id}/comments/{comment_id}", status_code=204)
def delete_comment(
    post_id: int,
    comment_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    c = db.query(PostComment).filter(PostComment.id == comment_id, PostComment.post_id == post_id).first()
    if not c:
        raise HTTPException(404, "Komentář nenalezen")
    is_owner = c.author_id == user.id
    if not is_owner and not has_permission(user, "posts.delete_any", db):
        raise HTTPException(403, "Chybí oprávnění")
    db.delete(c)
    db.commit()


# ─── Poll voting ──────────────────────────────────────────────────────

@router.post("/{post_id}/poll/options/{option_id}/vote", response_model=PollOut)
def vote_poll(
    post_id: int,
    option_id: int,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    """Klepni: přidej hlas (toggle). U single-choice ankety to nahradí předchozí hlas."""
    poll = db.query(Poll).filter(Poll.post_id == post_id).first()
    if not poll:
        raise HTTPException(404, "Anketa neexistuje")
    if poll.closes_at and poll.closes_at < datetime.utcnow():
        raise HTTPException(400, "Anketa je už uzavřená")

    option = db.query(PollOption).filter(PollOption.id == option_id, PollOption.poll_id == poll.id).first()
    if not option:
        raise HTTPException(404, "Možnost neexistuje")

    existing = (
        db.query(PollVote)
        .filter(PollVote.option_id == option.id, PollVote.user_id == user.id)
        .first()
    )

    if existing:
        # Klepl podruhé → odhlasovat
        db.delete(existing)
    else:
        # Single-choice — smazat předchozí hlasy v této anketě
        if not poll.multiple_choice:
            opt_ids = [o.id for o in poll.options]
            db.query(PollVote).filter(
                PollVote.option_id.in_(opt_ids),
                PollVote.user_id == user.id,
            ).delete(synchronize_session=False)
        db.add(PollVote(option_id=option.id, user_id=user.id))

    db.commit()
    return _serialize_poll(poll, db, user.id)
