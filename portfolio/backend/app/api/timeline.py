from flask import Blueprint, jsonify, request

from app.api.crud_helpers import load_or_422, paginate
from app.extensions import db
from app.models import TimelineEvent
from app.schemas import TimelineEventSchema
from app.utils.decorators import admin_required, audit

timeline_bp = Blueprint("timeline", __name__)


def _serialize(event: TimelineEvent) -> dict:
    return {
        "id": event.id,
        "title": event.title,
        "description": event.description,
        "event_type": event.event_type,
        "event_date": event.event_date.isoformat(),
        "photo_url": event.photo_url,
    }


@timeline_bp.get("")
def list_events():
    query = TimelineEvent.query
    event_type = request.args.get("type")
    if event_type:
        query = query.filter_by(event_type=event_type)
    query = query.order_by(TimelineEvent.event_date.desc())
    result = paginate(query)
    result["items"] = [_serialize(e) for e in result["items"]]
    return jsonify(result)


@timeline_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="timeline_event")
def create_event():
    data, error = load_or_422(TimelineEventSchema())
    if error:
        return error
    event = TimelineEvent(**data)
    db.session.add(event)
    db.session.commit()
    return jsonify(_serialize(event)), 201


@timeline_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="timeline_event")
def update_event(id):
    event = db.session.get(TimelineEvent, id)
    if event is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(TimelineEventSchema(), partial=True)
    if error:
        return error
    for key, value in data.items():
        setattr(event, key, value)
    db.session.commit()
    return jsonify(_serialize(event))


@timeline_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="timeline_event")
def delete_event(id):
    event = db.session.get(TimelineEvent, id)
    if event is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(event)
    db.session.commit()
    return "", 204
