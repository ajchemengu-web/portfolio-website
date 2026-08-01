"""
Generic helpers shared by the resource blueprints (research, publications,
software projects, blog, skills, timeline, achievements, gallery). Each
blueprint is still an explicit, readable set of Flask routes — these helpers
just remove the repetitive pagination / validation-error / slug-collision
boilerplate that would otherwise be copy-pasted eight times.
"""
import math

from flask import jsonify, request
from marshmallow import ValidationError
from sqlalchemy.exc import IntegrityError

from app.extensions import db
from app.utils.validators import slugify

MAX_PAGE_SIZE = 100


def paginate(query):
    try:
        page = max(int(request.args.get("page", 1)), 1)
        page_size = min(max(int(request.args.get("page_size", 12)), 1), MAX_PAGE_SIZE)
    except (TypeError, ValueError):
        page, page_size = 1, 12

    total = query.count()
    items = query.offset((page - 1) * page_size).limit(page_size).all()
    return {
        "items": items,
        "page": page,
        "page_size": page_size,
        "total": total,
        "total_pages": max(math.ceil(total / page_size), 1),
    }


def load_or_422(schema, partial=False):
    payload = request.get_json(silent=True)
    if payload is None:
        return None, (jsonify({"error": "Request body must be valid JSON."}), 400)
    try:
        data = schema.load(payload, partial=partial)
        return data, None
    except ValidationError as exc:
        return None, (jsonify({"error": "Validation failed.", "details": exc.messages}), 422)


def unique_slug(model, base_text: str, exclude_id: str | None = None) -> str:
    base = slugify(base_text)
    candidate = base
    suffix = 2
    while True:
        query = model.query.filter_by(slug=candidate)
        if exclude_id:
            query = query.filter(model.id != exclude_id)
        if not query.first():
            return candidate
        candidate = f"{base}-{suffix}"
        suffix += 1


def commit_or_409():
    try:
        db.session.commit()
        return None
    except IntegrityError:
        db.session.rollback()
        return jsonify({"error": "A record with conflicting unique data already exists."}), 409
