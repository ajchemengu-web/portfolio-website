"""
Reusable request-handling decorators.
"""
from functools import wraps

from flask import jsonify, request
from flask_jwt_extended import get_jwt, verify_jwt_in_request

from app.extensions import db
from app.models import AuditLog


def admin_required(fn):
    """Require a valid, non-revoked JWT. With a single-administrator system
    the presence of a valid access token *is* the authorization check — there
    is no separate role to compare against, which keeps the trust boundary
    simple and auditable."""

    @wraps(fn)
    def wrapper(*args, **kwargs):
        verify_jwt_in_request()
        return fn(*args, **kwargs)

    return wrapper


def audit(action: str, entity_type: str):
    """Record an admin action to the audit log after a successful mutating
    request. Applied to admin-only create/update/delete/publish endpoints."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            response = fn(*args, **kwargs)
            try:
                claims = get_jwt()
                admin_id = claims.get("sub")
                entity_id = kwargs.get("id") or kwargs.get("entity_id")
                log = AuditLog(
                    admin_id=admin_id,
                    action=action,
                    entity_type=entity_type,
                    entity_id=str(entity_id) if entity_id else None,
                    ip_address=request.headers.get("X-Forwarded-For", request.remote_addr),
                )
                db.session.add(log)
                db.session.commit()
            except Exception:
                # Audit logging must never break the primary request; log
                # failures are swallowed here (in production these should
                # additionally go to application logging/monitoring).
                db.session.rollback()
            return response

        return wrapper

    return decorator
