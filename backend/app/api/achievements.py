from flask import Blueprint, jsonify, request

from app.api.crud_helpers import load_or_422, paginate
from app.extensions import db
from app.models import Achievement
from app.schemas import AchievementSchema
from app.utils.decorators import admin_required, audit

achievements_bp = Blueprint("achievements", __name__)


def _serialize(item: Achievement) -> dict:
    return {
        "id": item.id,
        "title": item.title,
        "description": item.description,
        "category": item.category,
        "issuer": item.issuer,
        "date_awarded": item.date_awarded.isoformat() if item.date_awarded else None,
        "certificate_file_id": item.certificate_file_id,
    }


@achievements_bp.get("")
def list_achievements():
    query = Achievement.query
    category = request.args.get("category")
    if category:
        query = query.filter_by(category=category)
    query = query.order_by(Achievement.date_awarded.desc().nullslast())
    result = paginate(query)
    result["items"] = [_serialize(a) for a in result["items"]]
    return jsonify(result)


@achievements_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="achievement")
def create_achievement():
    data, error = load_or_422(AchievementSchema())
    if error:
        return error
    achievement = Achievement(**data)
    db.session.add(achievement)
    db.session.commit()
    return jsonify(_serialize(achievement)), 201


@achievements_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="achievement")
def update_achievement(id):
    achievement = db.session.get(Achievement, id)
    if achievement is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(AchievementSchema(), partial=True)
    if error:
        return error
    for key, value in data.items():
        setattr(achievement, key, value)
    db.session.commit()
    return jsonify(_serialize(achievement))


@achievements_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="achievement")
def delete_achievement(id):
    achievement = db.session.get(Achievement, id)
    if achievement is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(achievement)
    db.session.commit()
    return "", 204
