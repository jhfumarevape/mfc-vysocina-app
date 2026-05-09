"""Rules (aktuální pravidla buhurtu) — CRUD."""
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Rule
from ..schemas import RuleCreate, RuleUpdate, RuleOut
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/rules", tags=["rules"])


@router.get("", response_model=List[RuleOut])
def list_rules(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _user=Depends(get_current_user),
):
    q = db.query(Rule)
    if category:
        q = q.filter(Rule.category == category)
    return q.order_by(Rule.category.asc(), Rule.sort_order.asc(), Rule.id.asc()).all()


@router.post("", response_model=RuleOut, status_code=201)
def create_rule(
    payload: RuleCreate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),
):
    r = Rule(
        title=payload.title,
        content=payload.content,
        category=payload.category,
        document_url=payload.document_url,
        sort_order=payload.sort_order,
    )
    db.add(r)
    db.commit()
    db.refresh(r)
    return r


@router.patch("/{rule_id}", response_model=RuleOut)
def update_rule(
    rule_id: int,
    payload: RuleUpdate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.create")),
):
    r = db.query(Rule).filter(Rule.id == rule_id).first()
    if not r:
        raise HTTPException(404, "Pravidlo nenalezeno")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(r, k, v)
    db.commit()
    db.refresh(r)
    return r


@router.delete("/{rule_id}", status_code=204)
def delete_rule(
    rule_id: int,
    db: Session = Depends(get_db),
    user=Depends(require_permission("posts.delete_any")),
):
    r = db.query(Rule).filter(Rule.id == rule_id).first()
    if not r:
        raise HTTPException(404, "Pravidlo nenalezeno")
    db.delete(r)
    db.commit()
