from flask import Blueprint, jsonify, request

from app.api.crud_helpers import load_or_422, paginate
from app.extensions import db
from app.models import GalleryItem
from app.schemas import GalleryItemSchema
from app.utils.decorators import admin_required, audit

gallery_bp = Blueprint("gallery", __name__)


def _serialize(item: GalleryItem) -> dict:
    return {
        "id": item.id,
        "title": item.title,
        "description": item.description,
        "category": item.category,
        "image_url": item.image_url,
        "taken_at": item.taken_at.isoformat() if item.taken_at else None,
    }


@gallery_bp.get("")
def list_gallery():
    query = GalleryItem.query
    category = request.args.get("category")
    if category:
        query = query.filter_by(category=category)
    query = query.order_by(GalleryItem.taken_at.desc().nullslast())
    result = paginate(query)
    result["items"] = [_serialize(g) for g in result["items"]]
    return jsonify(result)


@gallery_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="gallery_item")
def create_gallery_item():
    data, error = load_or_422(GalleryItemSchema())
    if error:
        return error
    item = GalleryItem(**data)
    db.session.add(item)
    db.session.commit()
    return jsonify(_serialize(item)), 201


@gallery_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="gallery_item")
def update_gallery_item(id):
    item = db.session.get(GalleryItem, id)
    if item is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(GalleryItemSchema(), partial=True)
    if error:
        return error
    for key, value in data.items():
        setattr(item, key, value)
    db.session.commit()
    return jsonify(_serialize(item))


@gallery_bp.get("/admin/all")
@admin_required
def admin_list_gallery():
    query = GalleryItem.query.order_by(GalleryItem.created_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(g) for g in result["items"]]
    return jsonify(result)


@gallery_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="gallery_item")
def delete_gallery_item(id):
    item = db.session.get(GalleryItem, id)
    if item is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(item)
    db.session.commit()
    return "", 204
