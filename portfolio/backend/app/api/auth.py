"""
Authentication for the single administrator account.

- POST /api/auth/login     — email + password -> access + refresh JWT
- POST /api/auth/refresh   — refresh token -> new access token
- POST /api/auth/logout    — revoke the current access token (blocklist)
- GET  /api/auth/me        — current admin profile
- POST /api/auth/change-password

Rate limited aggressively on /login to blunt credential-stuffing / brute
force attempts, on top of the account lockout in app/utils/security.py.
No registration endpoint exists anywhere in this API — the PRD requires
exactly one administrator, provisioned out-of-band via scripts/seed_admin.py.
"""
from datetime import datetime, timezone

from flask import Blueprint, current_app, jsonify, request
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    get_jwt,
    get_jwt_identity,
    jwt_required,
)

from app.extensions import db, limiter
from app.models import Admin, AuditLog, RevokedToken
from app.schemas import ChangePasswordSchema, LoginSchema
from app.utils.security import (
    hash_password,
    is_locked_out,
    register_failed_login,
    register_successful_login,
    verify_password,
)

auth_bp = Blueprint("auth", __name__)


def _client_ip() -> str:
    return request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")


@auth_bp.post("/login")
@limiter.limit("5 per minute; 20 per hour")
def login():
    payload = request.get_json(silent=True) or {}
    errors = LoginSchema().validate(payload)
    if errors:
        return jsonify({"error": "Validation failed.", "details": errors}), 422

    email = payload["email"].strip().lower()
    password = payload["password"]

    admin = Admin.query.filter_by(email=email).first()
    # Constant-shape response whether the email exists or not, to avoid
    # leaking account enumeration information.
    generic_error = jsonify({"error": "Invalid email or password."})

    if admin is None:
        return generic_error, 401

    if is_locked_out(admin):
        return jsonify({"error": "Account temporarily locked due to repeated failed logins. Try again later."}), 423

    if not verify_password(password, admin.password_hash):
        register_failed_login(admin, db.session)
        return generic_error, 401

    register_successful_login(admin, db.session, _client_ip())
    db.session.add(AuditLog(admin_id=admin.id, action="login", entity_type="admin",
                             entity_id=admin.id, ip_address=_client_ip()))
    db.session.commit()

    access_token = create_access_token(identity=admin.id, additional_claims={"email": admin.email})
    refresh_token = create_refresh_token(identity=admin.id)
    return jsonify({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "admin": {"id": admin.id, "email": admin.email},
    })


@auth_bp.post("/refresh")
@jwt_required(refresh=True)
@limiter.limit("30 per hour")
def refresh():
    identity = get_jwt_identity()
    access_token = create_access_token(identity=identity)
    return jsonify({"access_token": access_token})


@auth_bp.post("/logout")
@jwt_required()
def logout():
    jti = get_jwt()["jti"]
    db.session.add(RevokedToken(jti=jti))
    db.session.commit()
    return jsonify({"message": "Logged out."})


@auth_bp.get("/me")
@jwt_required()
def me():
    admin_id = get_jwt_identity()
    admin = db.session.get(Admin, admin_id)
    if admin is None:
        return jsonify({"error": "Not found."}), 404
    return jsonify({
        "id": admin.id,
        "email": admin.email,
        "last_login_at": admin.last_login_at.isoformat() if admin.last_login_at else None,
        "is_2fa_enabled": admin.is_2fa_enabled,
    })


@auth_bp.post("/change-password")
@jwt_required()
@limiter.limit("5 per hour")
def change_password():
    payload = request.get_json(silent=True) or {}
    errors = ChangePasswordSchema().validate(payload)
    if errors:
        return jsonify({"error": "Validation failed.", "details": errors}), 422

    admin_id = get_jwt_identity()
    admin = db.session.get(Admin, admin_id)
    if admin is None:
        return jsonify({"error": "Not found."}), 404

    if not verify_password(payload["current_password"], admin.password_hash):
        return jsonify({"error": "Current password is incorrect."}), 401

    admin.password_hash = hash_password(payload["new_password"])
    db.session.add(AuditLog(admin_id=admin.id, action="change_password", entity_type="admin",
                             entity_id=admin.id, ip_address=_client_ip()))
    db.session.commit()
    return jsonify({"message": "Password updated."})
