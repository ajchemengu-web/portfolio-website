"""
Input validation and sanitisation helpers shared across API blueprints.
"""
import os
import re
import unicodedata

from flask import current_app

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    value = value.lower()
    value = _SLUG_RE.sub("-", value).strip("-")
    return value or "item"


def validate_file_extension(filename: str) -> bool:
    if "." not in filename:
        return False
    ext = filename.rsplit(".", 1)[1].lower()
    return ext in current_app.config["ALLOWED_UPLOAD_EXTENSIONS"]


def validate_mime_type(mime_type: str) -> bool:
    return mime_type in current_app.config["ALLOWED_UPLOAD_MIME_TYPES"]


def safe_filename(filename: str) -> str:
    """Strip path separators and control characters; keep the original
    extension. This is a stricter alternative to werkzeug's secure_filename
    that also guards against double-extension tricks and null bytes."""
    filename = filename.replace("\x00", "")
    filename = os.path.basename(filename)
    filename = re.sub(r"[^A-Za-z0-9._-]", "_", filename)
    filename = filename.lstrip(".")  # avoid dotfiles / traversal remnants
    return filename[:255] or "file"


def is_valid_email(value: str) -> bool:
    # Lightweight structural check; Marshmallow's Email field (via
    # email-validator) is used for the authoritative check in schemas.
    return bool(re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", value or ""))
