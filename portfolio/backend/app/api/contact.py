"""
Public contact form + admin inbox.

The public endpoint is rate limited and strictly validated (no HTML/script
content is ever rendered from it — the admin dashboard must treat message
bodies as plain text) to keep this the one endpoint anonymous users can
reach without becoming a spam or injection vector.
"""
from flask import Blueprint, jsonify, request

from app.api.crud_helpers import paginate
from app.extensions import db, limiter
from app.models import AuditLog, ContactMessage
from app.schemas import ContactMessageSchema
from app.utils.decorators import admin_required, audit

contact_bp = Blueprint("contact", __name__)


def _serialize(msg: ContactMessage) -> dict:
    return {
        "id": msg.id,
        "name": msg.name,
        "email": msg.email,
        "subject": msg.subject,
        "message": msg.message,
        "is_read": msg.is_read,
        "created_at": msg.created_at.isoformat(),
    }


@contact_bp.post("")
@limiter.limit("5 per minute; 20 per day")
def submit_contact():
    payload = request.get_json(silent=True) or {}
    errors = ContactMessageSchema().validate(payload)
    if errors:
        return jsonify({"error": "Validation failed.", "details": errors}), 422

    msg = ContactMessage(
        name=payload["name"].strip(),
        email=payload["email"].strip().lower(),
        subject=(payload.get("subject") or "").strip() or None,
        message=payload["message"].strip(),
        ip_address=request.headers.get("X-Forwarded-For", request.remote_addr),
    )
    db.session.add(msg)
    db.session.commit()
    # In production this is where an admin notification (email/webhook)
    # would be dispatched — see PRD "Notifications: New contact form submissions".
    return jsonify({"message": "Thanks for reaching out — I'll get back to you soon."}), 201


@contact_bp.get("/admin")
@admin_required
def admin_list_messages():
    query = ContactMessage.query.order_by(ContactMessage.created_at.desc())
    unread_only = request.args.get("unread_only")
    if unread_only == "true":
        query = query.filter_by(is_read=False)
    result = paginate(query)
    result["items"] = [_serialize(m) for m in result["items"]]
    return jsonify(result)


@contact_bp.put("/admin/<id>/read")
@admin_required
@audit(action="update", entity_type="contact_message")
def mark_read(id):
    msg = db.session.get(ContactMessage, id)
    if msg is None:
        return jsonify({"error": "Not found."}), 404
    msg.is_read = True
    db.session.commit()
    return jsonify(_serialize(msg))


@contact_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="contact_message")
def delete_message(id):
    msg = db.session.get(ContactMessage, id)
    if msg is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(msg)
    db.session.commit()
    return "", 204
