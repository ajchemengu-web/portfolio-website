"""
Downloads directory: public listing of downloadable FileAssets plus the
admin Download Manager (toggle public / view_only / private visibility,
track download counts).
"""
from flask import Blueprint, jsonify, request

from app.api.crud_helpers import load_or_422, paginate
from app.extensions import db
from app.models import FileAsset
from app.schemas import FileAssetUpdateSchema
from app.utils.decorators import admin_required, audit
from app.utils.storage import create_signed_url, delete_object

downloads_bp = Blueprint("downloads", __name__)


def _serialize(asset: FileAsset, is_admin: bool = False) -> dict:
    data = {
        "id": asset.id,
        "filename": asset.filename,
        "description": asset.description,
        "version": asset.version,
        "size_bytes": asset.size_bytes,
        "category": asset.category,
        "visibility": asset.visibility,
        "download_count": asset.download_count,
        "uploaded_at": asset.created_at.isoformat(),
    }
    if is_admin:
        data["storage_path"] = asset.storage_path
    return data


@downloads_bp.get("")
def list_downloads():
    query = FileAsset.query.filter(FileAsset.visibility.in_(["public", "view_only"]))
    category = request.args.get("category")
    if category:
        query = query.filter_by(category=category)
    query = query.order_by(FileAsset.created_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(a) for a in result["items"]]
    return jsonify(result)


@downloads_bp.get("/<id>/download")
def download_file(id):
    asset = db.session.get(FileAsset, id)
    if asset is None or asset.visibility == "private":
        return jsonify({"error": "Not found."}), 404
    if asset.visibility == "view_only":
        return jsonify({"error": "This file is available to view only, not for download."}), 403

    asset.download_count = (asset.download_count or 0) + 1
    db.session.commit()
    url = create_signed_url(asset.storage_path, expires_in_seconds=300)
    return jsonify({"url": url})


@downloads_bp.get("/admin/all")
@admin_required
def admin_list_downloads():
    query = FileAsset.query.order_by(FileAsset.created_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(a, is_admin=True) for a in result["items"]]
    return jsonify(result)


@downloads_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="file_asset")
def update_download(id):
    asset = db.session.get(FileAsset, id)
    if asset is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(FileAssetUpdateSchema(), partial=True)
    if error:
        return error
    for key, value in data.items():
        setattr(asset, key, value)
    db.session.commit()
    return jsonify(_serialize(asset, is_admin=True))


@downloads_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="file_asset")
def delete_download(id):
    asset = db.session.get(FileAsset, id)
    if asset is None:
        return jsonify({"error": "Not found."}), 404
    try:
        delete_object(asset.storage_path)
    except Exception:
        pass  # storage backend may already be missing the object; DB record still gets removed
    db.session.delete(asset)
    db.session.commit()
    return "", 204
