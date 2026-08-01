from flask import Blueprint, jsonify, request

from app.api.crud_helpers import load_or_422
from app.extensions import db
from app.models import Skill
from app.schemas import SkillSchema
from app.utils.decorators import admin_required, audit

skills_bp = Blueprint("skills", __name__)


def _serialize(skill: Skill) -> dict:
    return {
        "id": skill.id,
        "name": skill.name,
        "category": skill.category,
        "proficiency_level": skill.proficiency_level,
        "years_experience": skill.years_experience,
        "display_order": skill.display_order,
    }


@skills_bp.get("")
def list_skills():
    skills = Skill.query.order_by(Skill.category, Skill.display_order, Skill.name).all()
    grouped: dict[str, list] = {}
    for skill in skills:
        grouped.setdefault(skill.category, []).append(_serialize(skill))
    return jsonify(grouped)


@skills_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="skill")
def create_skill():
    data, error = load_or_422(SkillSchema())
    if error:
        return error
    skill = Skill(**data)
    db.session.add(skill)
    db.session.commit()
    return jsonify(_serialize(skill)), 201


@skills_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="skill")
def update_skill(id):
    skill = db.session.get(Skill, id)
    if skill is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(SkillSchema(), partial=True)
    if error:
        return error
    for key, value in data.items():
        setattr(skill, key, value)
    db.session.commit()
    return jsonify(_serialize(skill))


@skills_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="skill")
def delete_skill(id):
    skill = db.session.get(Skill, id)
    if skill is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(skill)
    db.session.commit()
    return "", 204
