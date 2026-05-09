"""Database models."""
from datetime import datetime, timezone

from sqlalchemy import (
    Column, Integer, String, Text, DateTime, Boolean,
    ForeignKey, UniqueConstraint, Index,
)
from sqlalchemy.orm import relationship

from .database import Base


def utcnow():
    return datetime.now(timezone.utc)


# ─── Users ────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(120), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)

    full_name = Column(String(120))
    role = Column(String(30), default="member")  # member, captain, admin
    avatar_url = Column(String(255))
    bio = Column(Text)

    push_token = Column(String(255))  # FCM token for push notifications
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=utcnow)

    # Relationships
    posts = relationship("Post", back_populates="author", cascade="all, delete-orphan")
    rsvps = relationship("RSVP", back_populates="user", cascade="all, delete-orphan")
    memberships = relationship("GroupMember", back_populates="user", cascade="all, delete-orphan")
    messages = relationship("Message", back_populates="author", cascade="all, delete-orphan")


# ─── Feed posts ───────────────────────────────────────────────────────

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    image_url = Column(String(255))
    pinned = Column(Boolean, default=False)  # pinned info posts
    created_at = Column(DateTime, default=utcnow, index=True)

    author = relationship("User", back_populates="posts")


# ─── Post reactions & comments ────────────────────────────────────────

class PostReaction(Base):
    __tablename__ = "post_reactions"
    __table_args__ = (UniqueConstraint("post_id", "user_id", "emoji"),)

    id = Column(Integer, primary_key=True)
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    emoji = Column(String(20), nullable=False)  # 👍 ❤️ 💪 😄 🛡️ ⚔️ 🏆
    created_at = Column(DateTime, default=utcnow)


class PostComment(Base):
    __tablename__ = "post_comments"
    __table_args__ = (Index("ix_post_comments_post_time", "post_id", "created_at"),)

    id = Column(Integer, primary_key=True)
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    author_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=utcnow, index=True)

    author = relationship("User")


# ─── Polls (anketu připojená k postu) ─────────────────────────────────

class Poll(Base):
    __tablename__ = "polls"

    id = Column(Integer, primary_key=True)
    post_id = Column(Integer, ForeignKey("posts.id", ondelete="CASCADE"), unique=True, nullable=False)
    question = Column(String(255), nullable=False)
    multiple_choice = Column(Boolean, default=False)
    closes_at = Column(DateTime)  # volitelné — po kdy lze hlasovat
    created_at = Column(DateTime, default=utcnow)

    options = relationship("PollOption", back_populates="poll", cascade="all, delete-orphan", order_by="PollOption.sort_order")


class PollOption(Base):
    __tablename__ = "poll_options"

    id = Column(Integer, primary_key=True)
    poll_id = Column(Integer, ForeignKey("polls.id", ondelete="CASCADE"), nullable=False)
    label = Column(String(120), nullable=False)
    sort_order = Column(Integer, default=0)

    poll = relationship("Poll", back_populates="options")
    votes = relationship("PollVote", back_populates="option", cascade="all, delete-orphan")


class PollVote(Base):
    __tablename__ = "poll_votes"
    __table_args__ = (UniqueConstraint("option_id", "user_id"),)

    id = Column(Integer, primary_key=True)
    option_id = Column(Integer, ForeignKey("poll_options.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, default=utcnow)

    option = relationship("PollOption", back_populates="votes")


# ─── Calendar events ──────────────────────────────────────────────────

class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    location = Column(String(200))
    starts_at = Column(DateTime, nullable=False, index=True)
    ends_at = Column(DateTime)
    event_type = Column(String(30), default="trening")  # trening, turnaj, sraz, jine
    created_by_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=utcnow)

    rsvps = relationship("RSVP", back_populates="event", cascade="all, delete-orphan")


class RSVP(Base):
    __tablename__ = "rsvps"
    __table_args__ = (UniqueConstraint("event_id", "user_id"),)

    id = Column(Integer, primary_key=True)
    event_id = Column(Integer, ForeignKey("events.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="going")  # going, maybe, not_going
    note = Column(String(255))
    updated_at = Column(DateTime, default=utcnow)

    event = relationship("Event", back_populates="rsvps")
    user = relationship("User", back_populates="rsvps")


# ─── Chat groups & messages ───────────────────────────────────────────

class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    is_default = Column(Boolean, default=False)  # auto-join for new users
    created_by_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=utcnow)

    members = relationship("GroupMember", back_populates="group", cascade="all, delete-orphan")
    messages = relationship("Message", back_populates="group", cascade="all, delete-orphan")


class GroupMember(Base):
    __tablename__ = "group_members"
    __table_args__ = (UniqueConstraint("group_id", "user_id"),)

    id = Column(Integer, primary_key=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    is_admin = Column(Boolean, default=False)
    joined_at = Column(DateTime, default=utcnow)
    last_read_at = Column(DateTime, default=utcnow)  # for unread counts

    group = relationship("Group", back_populates="members")
    user = relationship("User", back_populates="memberships")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (Index("ix_messages_group_time", "group_id", "created_at"),)

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id"), nullable=False)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    image_url = Column(String(255))
    created_at = Column(DateTime, default=utcnow, index=True)

    group = relationship("Group", back_populates="messages")
    author = relationship("User", back_populates="messages")


# ─── Tactics (videa s taktikami) ──────────────────────────────────────

class Tactic(Base):
    __tablename__ = "tactics"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    video_url = Column(String(500), nullable=False)  # YouTube/Vimeo/přímý odkaz
    thumbnail_url = Column(String(500))  # volitelný custom náhled (jinak se vezme z YouTube)
    category = Column(String(50))  # např. "5v5", "duely", "pohyb", "obrana"
    sort_order = Column(Integer, default=0)
    created_by_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=utcnow)


# ─── Rules (aktuální pravidla buhurtu) ────────────────────────────────

class Rule(Base):
    __tablename__ = "rules"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)  # markdown
    category = Column(String(50))  # "obecná", "5v5", "duely", "vybavení", "bezpečnost"
    sort_order = Column(Integer, default=0)
    document_url = Column(String(500))  # volitelný odkaz na PDF/web s plným zněním
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    created_at = Column(DateTime, default=utcnow)


# ─── Roles & Permissions ──────────────────────────────────────────────

class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), unique=True, nullable=False, index=True)
    description = Column(String(200))
    is_system = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow)

    permissions = relationship("RolePermission", back_populates="role", cascade="all, delete-orphan")


class RolePermission(Base):
    __tablename__ = "role_permissions"
    __table_args__ = (UniqueConstraint("role_id", "permission_key"),)

    id = Column(Integer, primary_key=True)
    role_id = Column(Integer, ForeignKey("roles.id"), nullable=False)
    permission_key = Column(String(80), nullable=False)

    role = relationship("Role", back_populates="permissions")
