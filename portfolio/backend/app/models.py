"""
SQLAlchemy models for the research portfolio platform.

Design notes
------------
* Target production database is Supabase Postgres, but models intentionally
  avoid Postgres-only column types (native ENUM, ARRAY, JSONB) in favour of
  portable `String` + `JSON`, so the exact same models also run against
  SQLite for local development and the automated test suite. Value sets for
  "enum-like" string columns are enforced in the API layer (marshmallow
  schemas), not just documented in comments.
* Every content table has an `is_draft` / `status` concept so the admin can
  save work-in-progress without it becoming publicly visible, matching the
  PRD's "draft vs published" requirement.
* `FileAsset.visibility` implements the PRD's public / view_only / private
  download permission model.
* `AuditLog` gives the single administrator a record of who (always them,
  but still logged with timestamp/IP) changed what and when.
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import CheckConstraint

from app.extensions import db


def _uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TimestampMixin:
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False
    )


class Admin(db.Model, TimestampMixin):
    """Single administrator account. The PRD explicitly forbids self-service
    registration or multiple admins, so there is no "role" column — presence
    of a row in this table *is* the admin role."""

    __tablename__ = "admins"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    totp_secret = db.Column(db.String(64), nullable=True)  # future 2FA (PRD "optional future support")
    is_2fa_enabled = db.Column(db.Boolean, default=False, nullable=False)
    last_login_at = db.Column(db.DateTime(timezone=True), nullable=True)
    last_login_ip = db.Column(db.String(64), nullable=True)
    failed_login_attempts = db.Column(db.Integer, default=0, nullable=False)
    locked_until = db.Column(db.DateTime(timezone=True), nullable=True)


class ResearchProject(db.Model, TimestampMixin):
    __tablename__ = "research_projects"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    slug = db.Column(db.String(255), unique=True, nullable=False, index=True)
    title = db.Column(db.String(500), nullable=False)
    category = db.Column(db.String(120), nullable=True)
    abstract = db.Column(db.Text, nullable=True)
    research_question = db.Column(db.Text, nullable=True)
    motivation = db.Column(db.Text, nullable=True)
    objectives = db.Column(db.Text, nullable=True)
    methodology = db.Column(db.Text, nullable=True)
    results = db.Column(db.Text, nullable=True)
    future_work = db.Column(db.Text, nullable=True)
    ethics_statement = db.Column(db.Text, nullable=True)
    references = db.Column(db.JSON, nullable=True)  # list[str]

    status = db.Column(db.String(20), nullable=False, default="planning")
    progress_percentage = db.Column(db.Integer, nullable=False, default=0)
    current_phase = db.Column(db.String(255), nullable=True)
    estimated_completion = db.Column(db.Date, nullable=True)
    admin_notes = db.Column(db.Text, nullable=True)  # PRD: "Personal notes (Admin only)"

    is_draft = db.Column(db.Boolean, default=True, nullable=False)
    published_at = db.Column(db.DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("progress_percentage >= 0 AND progress_percentage <= 100",
                         name="ck_research_progress_range"),
        CheckConstraint("status IN ('planning','active','completed','published')",
                         name="ck_research_status_values"),
    )


class Milestone(db.Model, TimestampMixin):
    """Research journal / progress milestones for a ResearchProject."""

    __tablename__ = "milestones"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    research_project_id = db.Column(
        db.String(36), db.ForeignKey("research_projects.id", ondelete="CASCADE"), nullable=False
    )
    title = db.Column(db.String(500), nullable=False)
    notes = db.Column(db.Text, nullable=True)
    milestone_date = db.Column(db.Date, nullable=True)
    is_complete = db.Column(db.Boolean, default=False, nullable=False)

    research_project = db.relationship(
        "ResearchProject", backref=db.backref("milestones", cascade="all, delete-orphan")
    )


class Publication(db.Model, TimestampMixin):
    __tablename__ = "publications"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    slug = db.Column(db.String(255), unique=True, nullable=False, index=True)
    title = db.Column(db.String(500), nullable=False)
    publication_type = db.Column(db.String(30), nullable=False, default="preprint")
    abstract = db.Column(db.Text, nullable=True)
    citation = db.Column(db.Text, nullable=True)
    authors = db.Column(db.JSON, nullable=True)  # list[str]
    publication_date = db.Column(db.Date, nullable=True)
    doi = db.Column(db.String(255), nullable=True)
    file_asset_id = db.Column(db.String(36), db.ForeignKey("file_assets.id"), nullable=True)

    is_draft = db.Column(db.Boolean, default=True, nullable=False)

    file_asset = db.relationship("FileAsset", foreign_keys=[file_asset_id])

    __table_args__ = (
        CheckConstraint(
            "publication_type IN ('paper','technical_report','conference','white_paper','preprint')",
            name="ck_publication_type_values",
        ),
    )


class SoftwareProject(db.Model, TimestampMixin):
    __tablename__ = "software_projects"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    slug = db.Column(db.String(255), unique=True, nullable=False, index=True)
    title = db.Column(db.String(500), nullable=False)
    description = db.Column(db.Text, nullable=True)
    features = db.Column(db.JSON, nullable=True)  # list[str]
    architecture = db.Column(db.Text, nullable=True)
    technologies = db.Column(db.JSON, nullable=True)  # list[str]
    github_url = db.Column(db.String(500), nullable=True)
    live_demo_url = db.Column(db.String(500), nullable=True)
    screenshots = db.Column(db.JSON, nullable=True)  # list[str] storage paths
    lessons_learned = db.Column(db.Text, nullable=True)
    future_improvements = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(20), nullable=False, default="active")
    progress_percentage = db.Column(db.Integer, nullable=False, default=0)

    is_draft = db.Column(db.Boolean, default=True, nullable=False)

    __table_args__ = (
        CheckConstraint("progress_percentage >= 0 AND progress_percentage <= 100",
                         name="ck_project_progress_range"),
    )


class BlogPost(db.Model, TimestampMixin):
    __tablename__ = "blog_posts"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    slug = db.Column(db.String(255), unique=True, nullable=False, index=True)
    title = db.Column(db.String(500), nullable=False)
    excerpt = db.Column(db.String(1000), nullable=True)
    content_markdown = db.Column(db.Text, nullable=False, default="")
    category = db.Column(db.String(120), nullable=True)
    tags = db.Column(db.JSON, nullable=True)  # list[str]
    status = db.Column(db.String(20), nullable=False, default="draft")
    scheduled_for = db.Column(db.DateTime(timezone=True), nullable=True)
    published_at = db.Column(db.DateTime(timezone=True), nullable=True)
    cover_image_url = db.Column(db.String(500), nullable=True)

    __table_args__ = (
        CheckConstraint("status IN ('draft','scheduled','published')", name="ck_blog_status_values"),
    )


class Skill(db.Model, TimestampMixin):
    __tablename__ = "skills"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    name = db.Column(db.String(255), nullable=False)
    category = db.Column(db.String(60), nullable=False)
    proficiency_level = db.Column(db.Integer, nullable=False, default=3)  # 1-5
    years_experience = db.Column(db.Float, nullable=True)
    display_order = db.Column(db.Integer, default=0, nullable=False)

    __table_args__ = (
        CheckConstraint("proficiency_level >= 1 AND proficiency_level <= 5",
                         name="ck_skill_level_range"),
        CheckConstraint(
            "category IN ('programming_languages','frameworks','cloud','databases',"
            "'cybersecurity','artificial_intelligence','operating_systems','tools')",
            name="ck_skill_category_values",
        ),
    )


class TimelineEvent(db.Model, TimestampMixin):
    __tablename__ = "timeline_events"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    title = db.Column(db.String(500), nullable=False)
    description = db.Column(db.Text, nullable=True)
    event_type = db.Column(db.String(30), nullable=False)
    event_date = db.Column(db.Date, nullable=False)
    photo_url = db.Column(db.String(500), nullable=True)

    __table_args__ = (
        CheckConstraint(
            "event_type IN ('education','award','research_milestone','internship',"
            "'project','leadership','publication','scholarship')",
            name="ck_timeline_event_type_values",
        ),
    )


class Achievement(db.Model, TimestampMixin):
    __tablename__ = "achievements"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    title = db.Column(db.String(500), nullable=False)
    description = db.Column(db.Text, nullable=True)
    category = db.Column(db.String(30), nullable=False)
    issuer = db.Column(db.String(255), nullable=True)
    date_awarded = db.Column(db.Date, nullable=True)
    certificate_file_id = db.Column(db.String(36), db.ForeignKey("file_assets.id"), nullable=True)

    certificate_file = db.relationship("FileAsset", foreign_keys=[certificate_file_id])

    __table_args__ = (
        CheckConstraint(
            "category IN ('academic','competition','leadership','scholarship','certificate')",
            name="ck_achievement_category_values",
        ),
    )


class GalleryItem(db.Model, TimestampMixin):
    __tablename__ = "gallery_items"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    title = db.Column(db.String(500), nullable=True)
    description = db.Column(db.Text, nullable=True)
    category = db.Column(db.String(30), nullable=False)
    image_url = db.Column(db.String(500), nullable=False)
    taken_at = db.Column(db.Date, nullable=True)

    __table_args__ = (
        CheckConstraint("category IN ('research','conference','project','laboratory')",
                         name="ck_gallery_category_values"),
    )


class FileAsset(db.Model, TimestampMixin):
    """Represents any uploaded file (CV, paper, certificate, image, video,
    slide deck) stored in Supabase Storage. Visibility implements the PRD's
    public / view_only / private permission model."""

    __tablename__ = "file_assets"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    filename = db.Column(db.String(500), nullable=False)
    storage_path = db.Column(db.String(1000), nullable=False)
    description = db.Column(db.Text, nullable=True)
    version = db.Column(db.String(50), nullable=True)
    size_bytes = db.Column(db.BigInteger, nullable=True)
    mime_type = db.Column(db.String(255), nullable=True)
    visibility = db.Column(db.String(20), nullable=False, default="private")
    download_count = db.Column(db.Integer, default=0, nullable=False)
    category = db.Column(db.String(60), nullable=True)  # cv, paper, presentation, certificate, image, video...

    __table_args__ = (
        CheckConstraint("visibility IN ('public','view_only','private')",
                         name="ck_file_visibility_values"),
    )


class ContactMessage(db.Model, TimestampMixin):
    __tablename__ = "contact_messages"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    name = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    subject = db.Column(db.String(500), nullable=True)
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False, nullable=False)
    ip_address = db.Column(db.String(64), nullable=True)


class SiteSetting(db.Model, TimestampMixin):
    """Simple key/value store for Website Settings (homepage text, theme,
    SEO, social links, contact info, resume/logo/favicon file refs)."""

    __tablename__ = "site_settings"

    key = db.Column(db.String(120), primary_key=True)
    value = db.Column(db.JSON, nullable=True)


class AuditLog(db.Model):
    __tablename__ = "audit_logs"

    id = db.Column(db.String(36), primary_key=True, default=_uuid)
    admin_id = db.Column(db.String(36), db.ForeignKey("admins.id"), nullable=True)
    action = db.Column(db.String(60), nullable=False)  # create/update/delete/publish/login/...
    entity_type = db.Column(db.String(60), nullable=False)
    entity_id = db.Column(db.String(36), nullable=True)
    details = db.Column(db.JSON, nullable=True)
    ip_address = db.Column(db.String(64), nullable=True)
    created_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)


class RevokedToken(db.Model):
    """JWT blocklist entry, used to support explicit logout / revocation."""

    __tablename__ = "revoked_tokens"

    id = db.Column(db.Integer, primary_key=True)
    jti = db.Column(db.String(64), unique=True, nullable=False, index=True)
    revoked_at = db.Column(db.DateTime(timezone=True), default=_utcnow, nullable=False)
