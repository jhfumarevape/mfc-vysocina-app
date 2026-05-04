"""Authentication: password hashing + JWT tokens + permission checks."""
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from sqlalchemy import or_

from .config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_DAYS
from .database import get_db
from .models import User, Role, RolePermission
from .permissions import PERMISSIONS

security = HTTPBearer()


def hash_password(plain: str) -> str:
    # bcrypt has a 72-byte limit on passwords; truncate for safety
    pw = plain.encode("utf-8")[:72]
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    pw = plain.encode("utf-8")[:72]
    try:
        return bcrypt.checkpw(pw, hashed.encode("utf-8"))
    except Exception:
        return False


def create_access_token(user_id: int) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def authenticate_user(db: Session, username_or_email: str, password: str) -> Optional[User]:
    """Look up user by username OR email, verify password."""
    user = db.query(User).filter(
        or_(User.username == username_or_email, User.email == username_or_email)
    ).first()
    if not user or not verify_password(password, user.password_hash):
        return None
    if not user.is_active:
        return None
    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    """FastAPI dependency: extracts user from JWT in Authorization header."""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str = payload.get("sub")
        if user_id_str is None:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
        user_id = int(user_id_str)
    except (JWTError, ValueError):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")

    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return user


# ─── Permission helpers ────────────────────────────────────────────────

def get_user_permissions(user: User, db: Session) -> set[str]:
    """Return the set of permission keys the user has via their role.

    The 'admin' role always has every permission, regardless of what's stored in DB
    (defensive — prevents lock-out if someone deletes admin permissions in DB).
    """
    if user.role == "admin":
        return set(PERMISSIONS.keys())

    role = db.query(Role).filter(Role.name == user.role).first()
    if not role:
        return set()
    return {rp.permission_key for rp in role.permissions}


def require_permission(permission_key: str):
    """FastAPI dependency factory. Use as: Depends(require_permission('users.list'))"""
    def dependency(
        user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        perms = get_user_permissions(user, db)
        if permission_key not in perms:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                f"Chybí oprávnění: {permission_key}",
            )
        return user
    return dependency


def has_permission(user: User, permission_key: str, db: Session) -> bool:
    """Inline check (for routes where ownership-or-permission logic is needed)."""
    return permission_key in get_user_permissions(user, db)
