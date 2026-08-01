"""
Dashboard overview: aggregate stats + recent activity feed (from the audit
log) shown on the admin dashboard landing page after login.
"""
from flask import Blueprint, jsonify

from app.api.crud_helpers import paginate
from app.models import (
    Achievement,
    AuditLog,
    BlogPost,
    ContactMessage,
    FileAsset,
    GalleryItem,
    Publication,
    ResearchProject,
    SoftwareProject,
    TimelineEvent,
)
from app.utils.decorators import admin_required

admin_bp = Blueprint("admin", __name__)


@admin_bp.get("/dashboard")
@admin_required
def dashboard():
    return jsonify({
        "counts": {
            "research_projects": ResearchProject.query.count(),
            "research_drafts": ResearchProject.query.filter_by(is_draft=True).count(),
            "publications": Publication.query.count(),
            "software_projects": SoftwareProject.query.count(),
            "blog_posts": BlogPost.query.count(),
            "blog_drafts": BlogPost.query.filter_by(status="draft").count(),
            "achievements": Achievement.query.count(),
            "gallery_items": GalleryItem.query.count(),
            "timeline_events": TimelineEvent.query.count(),
            "files": FileAsset.query.count(),
            "unread_messages": ContactMessage.query.filter_by(is_read=False).count(),
        },
    })


@admin_bp.get("/activity")
@admin_required
def recent_activity():
    query = AuditLog.query.order_by(AuditLog.created_at.desc())
    result = paginate(query)
    result["items"] = [
        {
            "id": log.id,
            "action": log.action,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "ip_address": log.ip_address,
            "created_at": log.created_at.isoformat(),
        }
        for log in result["items"]
    ]
    return jsonify(result)
