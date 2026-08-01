"""
Application factory.
"""
from flask import Flask, jsonify

from app.config import get_config
from app.extensions import cors, db, jwt, limiter, migrate, talisman


def create_app(config_object=None):
    app = Flask(__name__)
    app.config.from_object(config_object or get_config())

    _init_extensions(app)
    _register_blueprints(app)
    _register_error_handlers(app)
    _register_health_check(app)

    return app


def _init_extensions(app: Flask) -> None:
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    limiter.init_app(app)

    cors.init_app(
        app,
        resources={r"/api/*": {"origins": app.config["ALLOWED_ORIGINS"]}},
        supports_credentials=False,  # Bearer-token auth only; no cookies to protect via credentials mode.
    )

    # Security headers: HSTS, X-Content-Type-Options, X-Frame-Options,
    # a conservative Content-Security-Policy, and Referrer-Policy.
    # force_https is env-gated because local development typically runs
    # over plain HTTP; Railway terminates TLS in front of the app in prod.
    talisman.init_app(
        app,
        force_https=app.config["FORCE_HTTPS"],
        strict_transport_security=app.config["FORCE_HTTPS"],
        content_security_policy={
            "default-src": "'self'",
            "img-src": "'self' data: https:",
            "connect-src": "'self'",
            "frame-ancestors": "'none'",
        },
        referrer_policy="strict-origin-when-cross-origin",
        session_cookie_secure=app.config["FORCE_HTTPS"],
    )

    from app.models import RevokedToken

    @jwt.token_in_blocklist_loader
    def check_if_token_revoked(jwt_header, jwt_payload):
        jti = jwt_payload["jti"]
        return db.session.query(RevokedToken.id).filter_by(jti=jti).first() is not None

    @jwt.expired_token_loader
    def expired_token_callback(jwt_header, jwt_payload):
        return jsonify({"error": "Token has expired."}), 401

    @jwt.invalid_token_loader
    def invalid_token_callback(reason):
        return jsonify({"error": "Invalid authentication token."}), 401

    @jwt.unauthorized_loader
    def missing_token_callback(reason):
        return jsonify({"error": "Authentication required."}), 401

    @jwt.revoked_token_loader
    def revoked_token_callback(jwt_header, jwt_payload):
        return jsonify({"error": "Token has been revoked."}), 401


def _register_blueprints(app: Flask) -> None:
    from app.api import register_blueprints

    register_blueprints(app)


def _register_error_handlers(app: Flask) -> None:
    @app.errorhandler(404)
    def not_found(err):
        return jsonify({"error": "Resource not found."}), 404

    @app.errorhandler(405)
    def method_not_allowed(err):
        return jsonify({"error": "Method not allowed."}), 405

    @app.errorhandler(413)
    def payload_too_large(err):
        return jsonify({"error": "Request payload too large."}), 413

    @app.errorhandler(429)
    def rate_limited(err):
        return jsonify({"error": "Too many requests. Please slow down."}), 429

    @app.errorhandler(500)
    def internal_error(err):
        db.session.rollback()
        # Deliberately generic — never leak stack traces / internals to clients.
        return jsonify({"error": "An unexpected error occurred."}), 500


def _register_health_check(app: Flask) -> None:
    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok"})
