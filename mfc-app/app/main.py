"""FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Dict, Set
from datetime import datetime

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from jose import JWTError, jwt

from .config import APP_NAME, APP_VERSION, UPLOAD_DIR, SECRET_KEY, ALGORITHM, BASE_DIR
from .database import engine, Base, SessionLocal
from .models import User, Group, GroupMember, Message, Role, RolePermission
from .schemas import MessageOut
from .permissions import DEFAULT_ROLE_PERMISSIONS, SYSTEM_ROLES
from .routers import auth_routes, posts_routes, events_routes, groups_routes, upload_routes, admin_routes


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("mfc")


def _seed_roles(db: Session):
    """Create default roles + their permissions if missing.

    Existing roles are NOT modified (admin can edit captain/member permissions freely).
    """
    for role_name, perm_keys in DEFAULT_ROLE_PERMISSIONS.items():
        existing = db.query(Role).filter(Role.name == role_name).first()
        if existing:
            continue
        is_system = role_name in SYSTEM_ROLES
        descriptions = {
            "admin": "Plná práva na všechno (nelze smazat)",
            "captain": "Kapitán — moderace obsahu, vytváření událostí",
            "member": "Běžný člen týmu",
        }
        role = Role(name=role_name, description=descriptions.get(role_name), is_system=is_system)
        db.add(role)
        db.flush()
        for k in perm_keys:
            db.add(RolePermission(role_id=role.id, permission_key=k))
        logger.info(f"Seeded role '{role_name}' with {len(perm_keys)} permissions")
    db.commit()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Seed default roles + permissions (idempotent)
        _seed_roles(db)
        # Seed default group "MFC Vysočina — všichni" if no groups
        if db.query(Group).count() == 0:
            g = Group(name="Všichni", description="Hlavní skupina týmu", is_default=True)
            db.add(g)
            db.commit()
            logger.info("Default group 'Všichni' created")
    finally:
        db.close()
    logger.info(f"{APP_NAME} v{APP_VERSION} ready")
    yield


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static — uploaded files (avatars, post images)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

# Routers
app.include_router(auth_routes.router)
app.include_router(posts_routes.router)
app.include_router(events_routes.router)
app.include_router(groups_routes.router)
app.include_router(upload_routes.router)
app.include_router(admin_routes.router)
app.include_router(admin_routes.me_router)  # /auth/me/permissions

# Admin web UI (single-page HTML, served at /admin)
ADMIN_DIR = BASE_DIR / "admin_ui"
if ADMIN_DIR.exists():
    @app.get("/admin", include_in_schema=False)
    @app.get("/admin/", include_in_schema=False)
    def admin_index():
        return FileResponse(ADMIN_DIR / "index.html")

    app.mount("/admin/static", StaticFiles(directory=str(ADMIN_DIR)), name="admin_static")


@app.get("/")
def root():
    return {"app": APP_NAME, "version": APP_VERSION, "status": "ok"}


@app.get("/health")
def health():
    return {"status": "ok"}


# ─── WebSocket: real-time chat ────────────────────────────────────────

class ChatHub:
    """Tracks active WebSocket connections per group."""

    def __init__(self):
        self.connections: Dict[int, Set[WebSocket]] = {}  # group_id -> {ws, ws, ...}

    async def join(self, group_id: int, ws: WebSocket):
        self.connections.setdefault(group_id, set()).add(ws)

    def leave(self, group_id: int, ws: WebSocket):
        if group_id in self.connections:
            self.connections[group_id].discard(ws)
            if not self.connections[group_id]:
                self.connections.pop(group_id, None)

    async def broadcast(self, group_id: int, payload: dict):
        if group_id not in self.connections:
            return
        dead = []
        for ws in self.connections[group_id]:
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.leave(group_id, ws)


hub = ChatHub()


def _user_from_token(token: str, db: Session) -> User | None:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub", 0))
    except (JWTError, ValueError, TypeError):
        return None
    return db.query(User).filter(User.id == user_id, User.is_active == True).first()


@app.websocket("/ws/chat/{group_id}")
async def ws_chat(websocket: WebSocket, group_id: int, token: str):
    """Real-time chat for a single group.

    Client connects with: ws://host/ws/chat/{group_id}?token=JWT
    Sends: {"content": "msg text"}
    Receives: {message envelope as MessageOut JSON}
    """
    db = SessionLocal()
    try:
        user = _user_from_token(token, db)
        if not user:
            await websocket.close(code=4401)
            return

        # Verify membership
        membership = (
            db.query(GroupMember)
            .filter(GroupMember.group_id == group_id, GroupMember.user_id == user.id)
            .first()
        )
        if not membership:
            await websocket.close(code=4403)
            return

        await websocket.accept()
        await hub.join(group_id, websocket)
        logger.info(f"WS connected: user={user.username} group={group_id}")

        try:
            while True:
                data = await websocket.receive_json()
                content = (data.get("content") or "").strip()
                if not content:
                    continue
                image_url = data.get("image_url")

                msg = Message(
                    group_id=group_id, author_id=user.id,
                    content=content, image_url=image_url,
                )
                db.add(msg)
                db.commit()
                db.refresh(msg)
                msg = (
                    db.query(Message)
                    .options(joinedload(Message.author))
                    .filter(Message.id == msg.id)
                    .first()
                )

                payload = MessageOut.model_validate(msg).model_dump(mode="json")
                await hub.broadcast(group_id, payload)
        except WebSocketDisconnect:
            pass
        finally:
            hub.leave(group_id, websocket)
            logger.info(f"WS disconnected: user={user.username} group={group_id}")
    finally:
        db.close()
