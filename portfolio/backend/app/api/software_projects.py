from flask import Blueprint, jsonify, request

from app.api.crud_helpers import commit_or_409, load_or_422, paginate, unique_slug
from app.extensions import db
from app.models import SoftwareProject
from app.schemas import SoftwareProjectSchema
from app.utils.decorators import admin_required, audit

software_projects_bp = Blueprint("software_projects", __name__)


def _serialize(project: SoftwareProject) -> dict:
    return {
        "id": project.id,
        "slug": project.slug,
        "title": project.title,
        "description": project.description,
        "features": project.features or [],
        "architecture": project.architecture,
        "technologies": project.technologies or [],
        "github_url": project.github_url,
        "live_demo_url": project.live_demo_url,
        "screenshots": project.screenshots or [],
        "lessons_learned": project.lessons_learned,
        "future_improvements": project.future_improvements,
        "status": project.status,
        "progress_percentage": project.progress_percentage,
        "is_draft": project.is_draft,
        "updated_at": project.updated_at.isoformat(),
    }


@software_projects_bp.get("")
def list_projects():
    query = SoftwareProject.query.filter_by(is_draft=False)
    status = request.args.get("status")
    if status:
        query = query.filter_by(status=status)
    query = query.order_by(SoftwareProject.updated_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@software_projects_bp.get("/<slug>")
def get_project(slug):
    project = SoftwareProject.query.filter_by(slug=slug, is_draft=False).first()
    if project is None:
        return jsonify({"error": "Not found."}), 404
    return jsonify(_serialize(project))


@software_projects_bp.get("/admin/all")
@admin_required
def admin_list_projects():
    query = SoftwareProject.query.order_by(SoftwareProject.updated_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@software_projects_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="software_project")
def create_project():
    data, error = load_or_422(SoftwareProjectSchema())
    if error:
        return error
    project = SoftwareProject(slug=unique_slug(SoftwareProject, data["title"]), **data)
    db.session.add(project)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(project)), 201


@software_projects_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="software_project")
def update_project(id):
    project = db.session.get(SoftwareProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(SoftwareProjectSchema(), partial=True)
    if error:
        return error
    if "title" in data and data["title"] != project.title:
        project.slug = unique_slug(SoftwareProject, data["title"], exclude_id=project.id)
    for key, value in data.items():
        setattr(project, key, value)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(project))


@software_projects_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="software_project")
def delete_project(id):
    project = db.session.get(SoftwareProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(project)
    db.session.commit()
    return "", 204


@software_projects_bp.post("/admin/<id>/publish")
@admin_required
@audit(action="publish", entity_type="software_project")
def publish_project(id):
    project = db.session.get(SoftwareProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    project.is_draft = False
    db.session.commit()
    return jsonify(_serialize(project))
