"""
Supabase Storage integration.

All file uploads (CV, papers, certificates, images, videos, slide decks) are
stored in a single Supabase Storage bucket, referenced from the FileAsset
table. Access control is enforced application-side: "public" files get a
public URL, "view_only" / "private" files are served through a signed URL
minted on demand by an authenticated/authorised request (see
app/api/downloads.py), never a permanently public path.
"""
import mimetypes
import uuid

from flask import current_app

try:
    from supabase import Client, create_client
except ImportError:  # pragma: no cover - allows the app to boot without the
    Client = None      # supabase package installed, e.g. in minimal test envs
    create_client = None


class StorageError(RuntimeError):
    pass


def get_supabase_client() -> "Client":
    if create_client is None:
        raise StorageError("supabase-py is not installed.")
    url = current_app.config["SUPABASE_URL"]
    key = current_app.config["SUPABASE_SERVICE_ROLE_KEY"]
    if not url or not key:
        raise StorageError("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not configured.")
    return create_client(url, key)


def build_storage_path(category: str, original_filename: str) -> str:
    ext = ""
    if "." in original_filename:
        ext = "." + original_filename.rsplit(".", 1)[1].lower()
    unique_name = f"{uuid.uuid4().hex}{ext}"
    category = category or "misc"
    return f"{category}/{unique_name}"


def upload_bytes(storage_path: str, data: bytes, content_type: str | None = None) -> None:
    client = get_supabase_client()
    bucket = current_app.config["SUPABASE_STORAGE_BUCKET"]
    content_type = content_type or mimetypes.guess_type(storage_path)[0] or "application/octet-stream"
    client.storage.from_(bucket).upload(
        storage_path,
        data,
        {"content-type": content_type, "upsert": "false"},
    )


def delete_object(storage_path: str) -> None:
    client = get_supabase_client()
    bucket = current_app.config["SUPABASE_STORAGE_BUCKET"]
    client.storage.from_(bucket).remove([storage_path])


def get_public_url(storage_path: str) -> str:
    client = get_supabase_client()
    bucket = current_app.config["SUPABASE_STORAGE_BUCKET"]
    return client.storage.from_(bucket).get_public_url(storage_path)


def create_signed_url(storage_path: str, expires_in_seconds: int = 300) -> str:
    """Used for view_only / private files — a short-lived URL rather than a
    permanently public one, minted only after the caller has already passed
    the relevant authorisation check."""
    client = get_supabase_client()
    bucket = current_app.config["SUPABASE_STORAGE_BUCKET"]
    result = client.storage.from_(bucket).create_signed_url(storage_path, expires_in_seconds)
    return result["signedURL"] if isinstance(result, dict) and "signedURL" in result else result
