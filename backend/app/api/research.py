"""
Research Manager: the PRD's primary content type, so this module is the
"reference implementation" other resource blueprints (publications,
projects, blog, ...) mirror. Public routes only ever return non-draft
records; every mutation requires a valid admin JWT.
"""
from flask import Blueprint, jsonify, request

from app.api.crud_helpers import commit_or_409, load_or_422, paginate, unique_slug
from app.extensions import db
from app.models import Milestone, ResearchProject
from app.schemas import ResearchProjectSchema
from app.utils.decorators import admin_required, audit

research_bp = Blueprint("research", __name__)


def _serialize(project: ResearchProject, include_admin_fields: bool = False) -> dict:
    data = {
        "id": project.id,
        "slug": project.slug,
        "title": project.title,
        "category": project.category,
        "abstract": project.abstract,
        "research_question": project.research_question,
        "motivation": project.motivation,
        "objectives": project.objectives,
        "methodology": project.methodology,
        "results": project.results,
        "future_work": project.future_work,
        "ethics_statement": project.ethics_statement,
        "references": project.references or [],
        "status": project.status,
        "progress_percentage": project.progress_percentage,
        "current_phase": project.current_phase,
        "estimated_completion": project.estimated_completion.isoformat() if project.estimated_completion else None,
        "is_draft": project.is_draft,
        "published_at": project.published_at.isoformat() if project.published_at else None,
        "updated_at": project.updated_at.isoformat(),
        "milestones": [
            {
                "id": m.id,
                "title": m.title,
                "notes": m.notes,
                "milestone_date": m.milestone_date.isoformat() if m.milestone_date else None,
                "is_complete": m.is_complete,
            }
            for m in project.milestones
        ],
    }
    if include_admin_fields:
        data["admin_notes"] = project.admin_notes
    return data


@research_bp.get("")
def list_research():
    query = ResearchProject.query.filter_by(is_draft=False)
    status = request.args.get("status")
    if status:
        query = query.filter_by(status=status)
    category = request.args.get("category")
    if category:
        query = query.filter_by(category=category)
    query = query.order_by(ResearchProject.updated_at.desc())

    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@research_bp.get("/<slug>")
def get_research(slug):
    project = ResearchProject.query.filter_by(slug=slug, is_draft=False).first()
    if project is None:
        return jsonify({"error": "Not found."}), 404
    return jsonify(_serialize(project))


# ---------------------------------------------------------------------------
# Admin routes
# ---------------------------------------------------------------------------

@research_bp.get("/admin/all")
@admin_required
def admin_list_research():
    query = ResearchProject.query.order_by(ResearchProject.updated_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(p, include_admin_fields=True) for p in result["items"]]
    return jsonify(result)


@research_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="research_project")
def create_research():
    data, error = load_or_422(ResearchProjectSchema())
    if error:
        return error

    project = ResearchProject(
        slug=unique_slug(ResearchProject, data["title"]),
        **data,
    )
    db.session.add(project)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(project, include_admin_fields=True)), 201


@research_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="research_project")
def update_research(id):
    project = db.session.get(ResearchProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404

    data, error = load_or_422(ResearchProjectSchema(), partial=True)
    if error:
        return error

    if "title" in data and data["title"] != project.title:
        project.slug = unique_slug(ResearchProject, data["title"], exclude_id=project.id)

    for key, value in data.items():
        setattr(project, key, value)

    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(project, include_admin_fields=True))


@research_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="research_project")
def delete_research(id):
    project = db.session.get(ResearchProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(project)
    db.session.commit()
    return "", 204


@research_bp.post("/admin/<id>/publish")
@admin_required
@audit(action="publish", entity_type="research_project")
def publish_research(id):
    from datetime import datetime, timezone

    project = db.session.get(ResearchProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    project.is_draft = False
    if project.published_at is None:
        project.published_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify(_serialize(project, include_admin_fields=True))


@research_bp.post("/admin/<id>/archive")
@admin_required
@audit(action="archive", entity_type="research_project")
def archive_research(id):
    project = db.session.get(ResearchProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404
    project.is_draft = True
    db.session.commit()
    return jsonify(_serialize(project, include_admin_fields=True))


@research_bp.post("/admin/<id>/milestones")
@admin_required
@audit(action="create", entity_type="milestone")
def add_milestone(id):
    project = db.session.get(ResearchProject, id)
    if project is None:
        return jsonify({"error": "Not found."}), 404

    payload = request.get_json(silent=True) or {}
    title = (payload.get("title") or "").strip()
    if not title:
        return jsonify({"error": "title is required."}), 422

    milestone = Milestone(
        research_project_id=project.id,
        title=title,
        notes=payload.get("notes"),
        milestone_date=payload.get("milestone_date"),
        is_complete=bool(payload.get("is_complete", False)),
    )
    db.session.add(milestone)
    db.session.commit()
    return jsonify(_serialize(project, include_admin_fields=True)), 201
