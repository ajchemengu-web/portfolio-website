"""
Website Settings: homepage text, theme, SEO, social links, contact info,
analytics ID, resume/logo/favicon file references. Stored as a flat
key/value table so new settings can be added without a migration.
"""
from flask import Blueprint, jsonify, request

from app.extensions import db
from app.models import SiteSetting
from app.utils.decorators import admin_required, audit

settings_bp = Blueprint("settings", __name__)

PUBLIC_SETTING_KEYS = {
    "homepage_headline", "homepage_subheadline", "theme", "seo_title",
    "seo_description", "social_links", "contact_email", "resume_file_id",
    "logo_url", "favicon_url", "analytics_id",
}


@settings_bp.get("")
def public_settings():
    rows = SiteSetting.query.filter(SiteSetting.key.in_(PUBLIC_SETTING_KEYS)).all()
    return jsonify({row.key: row.value for row in rows})


@settings_bp.get("/admin")
@admin_required
def admin_settings():
    rows = SiteSetting.query.all()
    return jsonify({row.key: row.value for row in rows})


@settings_bp.put("/admin/<key>")
@admin_required
@audit(action="update", entity_type="site_setting")
def update_setting(key):
    payload = request.get_json(silent=True)
    if payload is None or "value" not in payload:
        return jsonify({"error": "Request body must include a 'value' field."}), 400

    setting = db.session.get(SiteSetting, key)
    if setting is None:
        setting = SiteSetting(key=key, value=payload["value"])
        db.session.add(setting)
    else:
        setting.value = payload["value"]
    db.session.commit()
    return jsonify({key: setting.value})
