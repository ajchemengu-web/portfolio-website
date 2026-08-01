"""
Secure file upload endpoint (admin only).

Defense in depth against malicious uploads:
  1. Flask's MAX_CONTENT_LENGTH rejects oversized requests before the body
     is even fully read.
  2. Extension allow-list check on the client-supplied filename.
  3. Magic-byte (actual content) MIME sniffing via python-magic — the
     declared Content-Type header is never trusted on its own, since it is
     attacker-controlled.
  4. The filename is sanitised and a random UUID name is generated for
     storage — the original name is preserved only as metadata, never used
     as the on-disk/storage path, which also prevents path traversal.
  5. Uploaded files are written to a private Supabase Storage bucket; only
     the FileAsset.visibility flag (checked in app/api/downloads.py) governs
     whether an outside party can ever obtain a URL for it.
"""
from flask import Blueprint, current_app, jsonify, request

from app.extensions import db, limiter
from app.models import FileAsset
from app.utils.decorators import admin_required, audit
from app.utils.storage import StorageError, build_storage_path, upload_bytes
from app.utils.validators import safe_filename, validate_file_extension, validate_mime_type

uploads_bp = Blueprint("uploads", __name__)

try:
    import magic
except ImportError:  # pragma: no cover
    magic = None


@uploads_bp.post("")
@admin_required
@limiter.limit("20 per hour")
@audit(action="create", entity_type="file_asset")
def upload_file():
    if "file" not in request.files:
        return jsonify({"error": "No file provided (expected multipart field 'file')."}), 400

    upload = request.files["file"]
    if upload.filename == "":
        return jsonify({"error": "No file selected."}), 400

    original_name = safe_filename(upload.filename)
    if not validate_file_extension(original_name):
        return jsonify({"error": "File type not allowed."}), 415

    data = upload.read()
    if not data:
        return jsonify({"error": "Uploaded file is empty."}), 400
    if len(data) > current_app.config["MAX_CONTENT_LENGTH"]:
        return jsonify({"error": "File exceeds the maximum allowed size."}), 413

    if magic is not None:
        detected_mime = magic.from_buffer(data, mime=True)
        if not validate_mime_type(detected_mime):
            return jsonify({"error": "File content does not match an allowed type."}), 415
    else:
        detected_mime = upload.mimetype

    category = request.form.get("category", "misc")
    storage_path = build_storage_path(category, original_name)

    try:
        upload_bytes(storage_path, data, content_type=detected_mime)
    except StorageError as exc:
        return jsonify({"error": f"Storage is not configured: {exc}"}), 503

    asset = FileAsset(
        filename=original_name,
        storage_path=storage_path,
        description=request.form.get("description"),
        version=request.form.get("version"),
        size_bytes=len(data),
        mime_type=detected_mime,
        visibility=request.form.get("visibility", "private"),
        category=category,
    )
    db.session.add(asset)
    db.session.commit()

    return jsonify({
        "id": asset.id,
        "filename": asset.filename,
        "visibility": asset.visibility,
        "size_bytes": asset.size_bytes,
        "category": asset.category,
    }), 201
