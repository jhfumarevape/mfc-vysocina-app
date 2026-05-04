"""Calendar events + RSVP endpoints."""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_, and_

from ..database import get_db
from ..models import Event, RSVP, User
from ..schemas import EventCreate, EventUpdate, EventOut, RSVPCreate, RSVPOut, UserOut
from ..auth import get_current_user, has_permission, require_permission

router = APIRouter(prefix="/events", tags=["events"])


def _serialize_event(event: Event, current_user_id: int) -> dict:
    going = sum(1 for r in event.rsvps if r.status == "going")
    maybe = sum(1 for r in event.rsvps if r.status == "maybe")
    my_rsvp = next((r for r in event.rsvps if r.user_id == current_user_id), None)
    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "location": event.location,
        "starts_at": event.starts_at,
        "ends_at": event.ends_at,
        "event_type": event.event_type,
        "rsvps": [
            {"user": r.user, "status": r.status, "note": r.note, "updated_at": r.updated_at}
            for r in event.rsvps
        ],
        "going_count": going,
        "maybe_count": maybe,
        "my_status": my_rsvp.status if my_rsvp else None,
    }


@router.get("", response_model=list[EventOut])
def list_events(
    upcoming_only: bool = True,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    q = db.query(Event).options(joinedload(Event.rsvps).joinedload(RSVP.user))
    if upcoming_only:
        q = q.filter(or_(Event.ends_at >= datetime.utcnow(), Event.starts_at >= datetime.utcnow()))
    q = q.order_by(Event.starts_at.asc())
    return [_serialize_event(e, user.id) for e in q.all()]


@router.get("/{event_id}", response_model=EventOut)
def get_event(event_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    event = (
        db.query(Event)
        .options(joinedload(Event.rsvps).joinedload(RSVP.user))
        .filter(Event.id == event_id)
        .first()
    )
    if not event:
        raise HTTPException(404, "Akce nenalezena")
    return _serialize_event(event, user.id)


@router.post("", response_model=EventOut, status_code=201)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    user=Depends(require_permission("events.create")),
):
    event = Event(
        title=payload.title,
        description=payload.description,
        location=payload.location,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        event_type=payload.event_type,
        created_by_id=user.id,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    # Reload with relationships
    event = db.query(Event).options(joinedload(Event.rsvps).joinedload(RSVP.user)).filter(Event.id == event.id).first()
    return _serialize_event(event, user.id)


@router.patch("/{event_id}", response_model=EventOut)
def update_event(event_id: int, payload: EventUpdate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(404, "Akce nenalezena")

    is_owner = event.created_by_id == user.id
    if is_owner:
        if not has_permission(user, "events.update_own", db):
            raise HTTPException(403, "Chybí oprávnění: events.update_own")
    else:
        if not has_permission(user, "events.update_any", db):
            raise HTTPException(403, "Chybí oprávnění: events.update_any")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(event, field, value)
    db.commit()
    db.refresh(event)
    event = db.query(Event).options(joinedload(Event.rsvps).joinedload(RSVP.user)).filter(Event.id == event.id).first()
    return _serialize_event(event, user.id)


@router.delete("/{event_id}", status_code=204)
def delete_event(event_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(404, "Akce nenalezena")

    is_owner = event.created_by_id == user.id
    if is_owner:
        if not has_permission(user, "events.delete_own", db):
            raise HTTPException(403, "Chybí oprávnění: events.delete_own")
    else:
        if not has_permission(user, "events.delete_any", db):
            raise HTTPException(403, "Chybí oprávnění: events.delete_any")

    db.delete(event)
    db.commit()


@router.post("/{event_id}/rsvp", response_model=EventOut)
def set_rsvp(event_id: int, payload: RSVPCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(404, "Akce nenalezena")

    rsvp = db.query(RSVP).filter(RSVP.event_id == event_id, RSVP.user_id == user.id).first()
    if rsvp:
        rsvp.status = payload.status
        rsvp.note = payload.note
        rsvp.updated_at = datetime.utcnow()
    else:
        rsvp = RSVP(
            event_id=event_id, user_id=user.id,
            status=payload.status, note=payload.note,
        )
        db.add(rsvp)
    db.commit()
    event = db.query(Event).options(joinedload(Event.rsvps).joinedload(RSVP.user)).filter(Event.id == event_id).first()
    return _serialize_event(event, user.id)
