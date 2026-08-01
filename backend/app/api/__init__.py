"""
API blueprint registration.

Each resource gets a public blueprint (read-only, published content only)
and, where mutation is needed, admin routes guarded by @admin_required living
in the same module. Registered under /api/... in the app factory.
"""
from app.api.achievements import achievements_bp
from app.api.admin_dashboard import admin_bp
from app.api.auth import auth_bp
from app.api.blog import blog_bp
from app.api.contact import contact_bp
from app.api.downloads import downloads_bp
from app.api.gallery import gallery_bp
from app.api.publications import publications_bp
from app.api.research import research_bp
from app.api.settings import settings_bp
from app.api.skills import skills_bp
from app.api.software_projects import software_projects_bp
from app.api.timeline import timeline_bp
from app.api.uploads import uploads_bp

ALL_BLUEPRINTS = [
    (auth_bp, "/api/auth"),
    (research_bp, "/api/research"),
    (publications_bp, "/api/publications"),
    (software_projects_bp, "/api/projects"),
    (blog_bp, "/api/blog"),
    (skills_bp, "/api/skills"),
    (timeline_bp, "/api/timeline"),
    (achievements_bp, "/api/achievements"),
    (gallery_bp, "/api/gallery"),
    (downloads_bp, "/api/downloads"),
    (contact_bp, "/api/contact"),
    (uploads_bp, "/api/uploads"),
    (admin_bp, "/api/admin"),
    (settings_bp, "/api/settings"),
]


def register_blueprints(app):
    for blueprint, url_prefix in ALL_BLUEPRINTS:
        app.register_blueprint(blueprint, url_prefix=url_prefix)
