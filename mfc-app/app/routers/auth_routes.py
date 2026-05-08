"""Authentication endpoints: register, login, /me."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from ..database import get_db
from ..models import User, Group, GroupMember
from ..schemas import UserCreate, UserLogin, UserOut, UserUpdate, TokenResponse
from ..auth import hash_password, authenticate_user, create_access_token, get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
def register(payload: UserCreate, db: Session = Depends(get_db)):
    # Check duplicates
    exists = db.query(User).filter(
        or_(User.username == payload.username, User.email == payload.email)
    ).first()
    if exists:
        if exists.username == payload.username:
            raise HTTPException(400, "Toto uživatelské jméno už existuje")
        raise HTTPException(400, "Tento email už je zaregistrovaný")

    # První registrovaný uživatel se automaticky stává adminem (bootstrap).
    is_first_user = db.query(User).count() == 0

    user = User(
        username=payload.username,
        email=payload.email,
        password_hash=hash_password(payload.password),
        full_name=payload.full_name,
        role="admin" if is_first_user else "member",
    )
    db.add(user)
    db.flush()  # get user.id

    # Auto-join all default groups
    default_groups = db.query(Group).filter(Group.is_default == True).all()
    for g in default_groups:
        db.add(GroupMember(group_id=g.id, user_id=user.id))

    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user=user)


@router.post("/login", response_model=TokenResponse)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    user = authenticate_user(db, payload.username, payload.password)
    if not user:
        raise HTTPException(401, "Špatné přihlašovací údaje")
    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user=user)


@router.get("/me", response_model=UserOut)
def me(current=Depends(get_current_user)):
    return current


@router.patch("/me", response_model=UserOut)
def update_me(payload: UserUpdate, db: Session = Depends(get_db), current=Depends(get_current_user)):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(current, field, value)
    db.commit()
    db.refresh(current)
    return current
