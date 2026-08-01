from flask import Blueprint, jsonify, request

from app.api.crud_helpers import commit_or_409, load_or_422, paginate, unique_slug
from app.extensions import db
from app.models import FileAsset, Publication
from app.schemas import PublicationSchema
from app.utils.decorators import admin_required, audit
from app.utils.storage import create_signed_url

publications_bp = Blueprint("publications", __name__)


def _serialize(pub: Publication) -> dict:
    file_info = None
    if pub.file_asset:
        fa = pub.file_asset
        file_info = {
            "id": fa.id,
            "filename": fa.filename,
            "visibility": fa.visibility,
            "size_bytes": fa.size_bytes,
            "download_url": fa.storage_path if fa.visibility == "public" else None,
        }
    return {
        "id": pub.id,
        "slug": pub.slug,
        "title": pub.title,
        "publication_type": pub.publication_type,
        "abstract": pub.abstract,
        "citation": pub.citation,
        "authors": pub.authors or [],
        "publication_date": pub.publication_date.isoformat() if pub.publication_date else None,
        "doi": pub.doi,
        "file": file_info,
        "is_draft": pub.is_draft,
        "updated_at": pub.updated_at.isoformat(),
    }


@publications_bp.get("")
def list_publications():
    query = Publication.query.filter_by(is_draft=False)
    pub_type = request.args.get("type")
    if pub_type:
        query = query.filter_by(publication_type=pub_type)
    query = query.order_by(Publication.publication_date.desc().nullslast())
    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@publications_bp.get("/<slug>")
def get_publication(slug):
    pub = Publication.query.filter_by(slug=slug, is_draft=False).first()
    if pub is None:
        return jsonify({"error": "Not found."}), 404
    return jsonify(_serialize(pub))


@publications_bp.get("/<slug>/download")
def download_publication(slug):
    pub = Publication.query.filter_by(slug=slug, is_draft=False).first()
    if pub is None or pub.file_asset is None:
        return jsonify({"error": "Not found."}), 404
    fa = pub.file_asset
    if fa.visibility == "private":
        return jsonify({"error": "This file is not publicly available."}), 403
    fa.download_count = (fa.download_count or 0) + 1
    db.session.commit()
    if fa.visibility == "public":
        return jsonify({"url": fa.storage_path})
    url = create_signed_url(fa.storage_path, expires_in_seconds=300)
    return jsonify({"url": url})


@publications_bp.get("/admin/all")
@admin_required
def admin_list_publications():
    query = Publication.query.order_by(Publication.updated_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@publications_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="publication")
def create_publication():
    data, error = load_or_422(PublicationSchema())
    if error:
        return error
    if data.get("file_asset_id") and not db.session.get(FileAsset, data["file_asset_id"]):
        return jsonify({"error": "file_asset_id does not reference an existing file."}), 422

    pub = Publication(slug=unique_slug(Publication, data["title"]), **data)
    db.session.add(pub)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(pub)), 201


@publications_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="publication")
def update_publication(id):
    pub = db.session.get(Publication, id)
    if pub is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(PublicationSchema(), partial=True)
    if error:
        return error
    if "title" in data and data["title"] != pub.title:
        pub.slug = unique_slug(Publication, data["title"], exclude_id=pub.id)
    for key, value in data.items():
        setattr(pub, key, value)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(pub))


@publications_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="publication")
def delete_publication(id):
    pub = db.session.get(Publication, id)
    if pub is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(pub)
    db.session.commit()
    return "", 204


@publications_bp.post("/admin/<id>/publish")
@admin_required
@audit(action="publish", entity_type="publication")
def publish_publication(id):
    pub = db.session.get(Publication, id)
    if pub is None:
        return jsonify({"error": "Not found."}), 404
    pub.is_draft = False
    db.session.commit()
    return jsonify(_serialize(pub))
