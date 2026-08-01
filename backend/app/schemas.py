"""
Marshmallow schemas: request validation (loading untrusted input) and
response serialization. Keeping validation centralised here means every API
route gets consistent, explicit input checking instead of trusting raw
request.json — this is the app's primary defense against malformed or
malicious payloads (oversized strings, wrong types, unexpected fields).
"""
from marshmallow import EXCLUDE, Schema, fields, validate

# --- Auth -------------------------------------------------------------

class LoginSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    email = fields.Email(required=True)
    password = fields.Str(required=True, validate=validate.Length(min=1, max=255))


class ChangePasswordSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    current_password = fields.Str(required=True)
    new_password = fields.Str(required=True, validate=validate.Length(min=12, max=255))


# --- Contact ------------------------------------------------------------

class ContactMessageSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    name = fields.Str(required=True, validate=validate.Length(min=1, max=255))
    email = fields.Email(required=True)
    subject = fields.Str(required=False, allow_none=True, validate=validate.Length(max=500))
    message = fields.Str(required=True, validate=validate.Length(min=1, max=5000))


# --- Research -------------------------------------------------------------

RESEARCH_STATUS_VALUES = ["planning", "active", "completed", "published"]


class ResearchProjectSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    category = fields.Str(required=False, allow_none=True, validate=validate.Length(max=120))
    abstract = fields.Str(required=False, allow_none=True)
    research_question = fields.Str(required=False, allow_none=True)
    motivation = fields.Str(required=False, allow_none=True)
    objectives = fields.Str(required=False, allow_none=True)
    methodology = fields.Str(required=False, allow_none=True)
    results = fields.Str(required=False, allow_none=True)
    future_work = fields.Str(required=False, allow_none=True)
    ethics_statement = fields.Str(required=False, allow_none=True)
    references = fields.List(fields.Str(), required=False, allow_none=True)
    status = fields.Str(required=False, validate=validate.OneOf(RESEARCH_STATUS_VALUES))
    progress_percentage = fields.Int(required=False, validate=validate.Range(min=0, max=100))
    current_phase = fields.Str(required=False, allow_none=True, validate=validate.Length(max=255))
    estimated_completion = fields.Date(required=False, allow_none=True)
    admin_notes = fields.Str(required=False, allow_none=True)
    is_draft = fields.Bool(required=False)


# --- Publications -----------------------------------------------------------

PUBLICATION_TYPE_VALUES = ["paper", "technical_report", "conference", "white_paper", "preprint"]


class PublicationSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    publication_type = fields.Str(required=False, validate=validate.OneOf(PUBLICATION_TYPE_VALUES))
    abstract = fields.Str(required=False, allow_none=True)
    citation = fields.Str(required=False, allow_none=True)
    authors = fields.List(fields.Str(), required=False, allow_none=True)
    publication_date = fields.Date(required=False, allow_none=True)
    doi = fields.Str(required=False, allow_none=True, validate=validate.Length(max=255))
    file_asset_id = fields.Str(required=False, allow_none=True)
    is_draft = fields.Bool(required=False)


# --- Software projects -------------------------------------------------------

PROJECT_STATUS_VALUES = ["planning", "active", "completed", "published"]


class SoftwareProjectSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    description = fields.Str(required=False, allow_none=True)
    features = fields.List(fields.Str(), required=False, allow_none=True)
    architecture = fields.Str(required=False, allow_none=True)
    technologies = fields.List(fields.Str(), required=False, allow_none=True)
    github_url = fields.Url(required=False, allow_none=True)
    live_demo_url = fields.Url(required=False, allow_none=True)
    screenshots = fields.List(fields.Str(), required=False, allow_none=True)
    lessons_learned = fields.Str(required=False, allow_none=True)
    future_improvements = fields.Str(required=False, allow_none=True)
    status = fields.Str(required=False, validate=validate.OneOf(PROJECT_STATUS_VALUES))
    progress_percentage = fields.Int(required=False, validate=validate.Range(min=0, max=100))
    is_draft = fields.Bool(required=False)


# --- Blog ---------------------------------------------------------------

BLOG_STATUS_VALUES = ["draft", "scheduled", "published"]


class BlogPostSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    excerpt = fields.Str(required=False, allow_none=True, validate=validate.Length(max=1000))
    content_markdown = fields.Str(required=False, allow_none=True)
    category = fields.Str(required=False, allow_none=True, validate=validate.Length(max=120))
    tags = fields.List(fields.Str(), required=False, allow_none=True)
    status = fields.Str(required=False, validate=validate.OneOf(BLOG_STATUS_VALUES))
    scheduled_for = fields.DateTime(required=False, allow_none=True)
    cover_image_url = fields.Str(required=False, allow_none=True, validate=validate.Length(max=500))


# --- Skills -----------------------------------------------------------------

SKILL_CATEGORY_VALUES = [
    "programming_languages", "frameworks", "cloud", "databases",
    "cybersecurity", "artificial_intelligence", "operating_systems", "tools",
]


class SkillSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    name = fields.Str(required=True, validate=validate.Length(min=1, max=255))
    category = fields.Str(required=True, validate=validate.OneOf(SKILL_CATEGORY_VALUES))
    proficiency_level = fields.Int(required=True, validate=validate.Range(min=1, max=5))
    years_experience = fields.Float(required=False, allow_none=True)
    display_order = fields.Int(required=False)


# --- Timeline -----------------------------------------------------------

TIMELINE_EVENT_TYPES = [
    "education", "award", "research_milestone", "internship",
    "project", "leadership", "publication", "scholarship",
]


class TimelineEventSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    description = fields.Str(required=False, allow_none=True)
    event_type = fields.Str(required=True, validate=validate.OneOf(TIMELINE_EVENT_TYPES))
    event_date = fields.Date(required=True)
    photo_url = fields.Str(required=False, allow_none=True, validate=validate.Length(max=500))


# --- Achievements -------------------------------------------------------

ACHIEVEMENT_CATEGORY_VALUES = ["academic", "competition", "leadership", "scholarship", "certificate"]


class AchievementSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=True, validate=validate.Length(min=1, max=500))
    description = fields.Str(required=False, allow_none=True)
    category = fields.Str(required=True, validate=validate.OneOf(ACHIEVEMENT_CATEGORY_VALUES))
    issuer = fields.Str(required=False, allow_none=True, validate=validate.Length(max=255))
    date_awarded = fields.Date(required=False, allow_none=True)
    certificate_file_id = fields.Str(required=False, allow_none=True)


# --- Gallery --------------------------------------------------------------

GALLERY_CATEGORY_VALUES = ["research", "conference", "project", "laboratory"]


class GalleryItemSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    title = fields.Str(required=False, allow_none=True, validate=validate.Length(max=500))
    description = fields.Str(required=False, allow_none=True)
    category = fields.Str(required=True, validate=validate.OneOf(GALLERY_CATEGORY_VALUES))
    image_url = fields.Str(required=True, validate=validate.Length(max=500))
    taken_at = fields.Date(required=False, allow_none=True)


# --- File assets / downloads -------------------------------------------------

FILE_VISIBILITY_VALUES = ["public", "view_only", "private"]


class FileAssetUpdateSchema(Schema):
    class Meta:
        unknown = EXCLUDE

    description = fields.Str(required=False, allow_none=True)
    version = fields.Str(required=False, allow_none=True, validate=validate.Length(max=50))
    visibility = fields.Str(required=False, validate=validate.OneOf(FILE_VISIBILITY_VALUES))
    category = fields.Str(required=False, allow_none=True, validate=validate.Length(max=60))
