"""Pydantic schemas (request/response shapes)."""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field, ConfigDict


# ─── User ─────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6)
    full_name: Optional[str] = None


class UserLogin(BaseModel):
    username: str  # username or email
    password: str


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    push_token: Optional[str] = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    email: EmailStr
    full_name: Optional[str]
    role: str
    avatar_url: Optional[str]
    bio: Optional[str]
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ─── Posts ────────────────────────────────────────────────────────────

class PostCreate(BaseModel):
    content: str = Field(..., min_length=1)
    image_url: Optional[str] = None


class PostOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    author: UserOut
    content: str
    image_url: Optional[str]
    pinned: bool
    created_at: datetime
    # Reakce (sečtené per emoji + co user kliknul)
    reactions: dict[str, int] = Field(default_factory=dict)
    my_reactions: list[str] = Field(default_factory=list)
    # Komentáře — jen počet, plné na detail endpointu
    comment_count: int = 0
    # Volitelná anketa
    poll: Optional["PollOut"] = None


# ─── Comments ─────────────────────────────────────────────────────────

class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)


class CommentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    post_id: int
    author: UserOut
    content: str
    created_at: datetime


# ─── Polls (anketa připojená k postu) ────────────────────────────────

class PollOptionCreate(BaseModel):
    label: str = Field(..., min_length=1, max_length=120)


class PollCreate(BaseModel):
    question: str = Field(..., min_length=1, max_length=255)
    options: list[PollOptionCreate] = Field(..., min_length=2, max_length=10)
    multiple_choice: bool = False
    closes_at: Optional[datetime] = None


class PollOptionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    label: str
    vote_count: int
    voted: bool  # zda můj user kliknul tuhle


class PollOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    question: str
    multiple_choice: bool
    closes_at: Optional[datetime]
    total_votes: int
    options: list[PollOptionOut]


# Post create supports an optional inline poll.
class PostCreateExtended(PostCreate):
    poll: Optional[PollCreate] = None


# ─── Events ───────────────────────────────────────────────────────────

class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    location: Optional[str] = None
    starts_at: datetime
    ends_at: Optional[datetime] = None
    event_type: str = "trening"


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    location: Optional[str] = None
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None
    event_type: Optional[str] = None


class RSVPCreate(BaseModel):
    status: str = Field(..., pattern="^(going|maybe|not_going)$")
    note: Optional[str] = None


class RSVPOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user: UserOut
    status: str
    note: Optional[str]
    updated_at: datetime


class EventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    description: Optional[str]
    location: Optional[str]
    starts_at: datetime
    ends_at: Optional[datetime]
    event_type: str
    rsvps: List[RSVPOut] = []
    going_count: int = 0
    maybe_count: int = 0
    my_status: Optional[str] = None  # "going", "maybe", "not_going", or None


# ─── Tactics (videa) ──────────────────────────────────────────────────

class TacticCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = None
    video_url: str = Field(..., min_length=1, max_length=500)
    thumbnail_url: Optional[str] = None
    category: Optional[str] = None
    sort_order: int = 0


class TacticUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    video_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    category: Optional[str] = None
    sort_order: Optional[int] = None


class TacticOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    description: Optional[str]
    video_url: str
    thumbnail_url: Optional[str]
    category: Optional[str]
    sort_order: int
    created_at: datetime


# ─── Rules (pravidla buhurtu) ─────────────────────────────────────────

class RuleCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    content: str = Field(..., min_length=1)
    category: Optional[str] = None
    document_url: Optional[str] = None
    sort_order: int = 0


class RuleUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    category: Optional[str] = None
    document_url: Optional[str] = None
    sort_order: Optional[int] = None


class RuleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    content: str
    category: Optional[str]
    document_url: Optional[str]
    sort_order: int
    updated_at: datetime
    created_at: datetime


# ─── Groups & Messages ────────────────────────────────────────────────

class GroupCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    member_ids: Optional[List[int]] = None  # users to add at creation
    is_default: bool = False  # default skupiny — auto-join nově registrovaných


class GroupOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    description: Optional[str]
    member_count: int = 0
    last_message_at: Optional[datetime] = None
    last_message_preview: Optional[str] = None
    unread_count: int = 0


class MessageCreate(BaseModel):
    content: str = Field(..., min_length=1)
    image_url: Optional[str] = None


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    group_id: int
    author: UserOut
    content: str
    image_url: Optional[str]
    created_at: datetime


# ─── Admin: users ─────────────────────────────────────────────────────

class UserAdminOut(BaseModel):
    """Extended user view for admin panel — includes is_active + role."""
    model_config = ConfigDict(from_attributes=True)
    id: int
    username: str
    email: EmailStr
    full_name: Optional[str]
    role: str
    avatar_url: Optional[str]
    bio: Optional[str]
    is_active: bool
    created_at: datetime


class UserAdminUpdate(BaseModel):
    role: Optional[str] = None
    is_active: Optional[bool] = None
    full_name: Optional[str] = None


# ─── Admin: roles & permissions ───────────────────────────────────────

class PermissionInfo(BaseModel):
    """Describes one available permission."""
    key: str
    group: str
    description: str


class RoleCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    description: Optional[str] = None
    permissions: List[str] = Field(default_factory=list)


class RoleUpdate(BaseModel):
    description: Optional[str] = None
    permissions: Optional[List[str]] = None  # if provided, replaces full set


class RoleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    description: Optional[str]
    is_system: bool
    permissions: List[str] = []
    user_count: int = 0


# ─── /me extension: include permissions of the current user ──────────

class MePermissionsOut(BaseModel):
    """Returned by GET /auth/me/permissions — used by mobile app to know what to show."""
    role: str
    permissions: List[str]
