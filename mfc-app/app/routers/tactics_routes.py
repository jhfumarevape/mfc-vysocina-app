"""Tactics (videa s taktikami) — CRUD."""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Tactic
from ..schemas import TacticCreate, TacticUpdate, TacticOut
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/tactics", tags=["tactics"])


@router.get("", response_model=List[TacticOut])
def list_tactics(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _user=Depends(get_current_user),
):
    q = db.query(Tactic)
    if category:
        q = q.filter(Tactic.category == category)
    return q.order_by(Tactic.sort_order.asc(), Tactic.created_at.desc()).all()


@router.post("", response_model=TacticOut, status_code=201)
def create_tactic(
    payload: TacticCreate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),  # admin/captain
):
    t = Tactic(
        title=payload.title,
        description=payload.description,
        video_url=payload.video_url,
        thumbnail_url=payload.thumbnail_url,
        category=payload.category,
        sort_order=payload.sort_order,
        created_by_id=user.id,
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    return t


@router.patch("/{tactic_id}", response_model=TacticOut)
def update_tactic(
    tactic_id: int,
    payload: TacticUpdate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),
):
    t = db.query(Tactic).filter(Tactic.id == tactic_id).first()
    if not t:
        raise HTTPException(404, "Taktika nenalezena")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(t, k, v)
    db.commit()
    db.refresh(t)
    return t


@router.delete("/{tactic_id}", status_code=204)
def delete_tactic(
    tactic_id: int,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.delete_any")),
):
    t = db.query(Tactic).filter(Tactic.id == tactic_id).first()
    if not t:
        raise HTTPException(404, "Taktika nenalezena")
    db.delete(t)
    db.commit()
