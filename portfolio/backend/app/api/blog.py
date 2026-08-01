from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

from app.api.crud_helpers import commit_or_409, load_or_422, paginate, unique_slug
from app.extensions import db
from app.models import BlogPost
from app.schemas import BlogPostSchema
from app.utils.decorators import admin_required, audit

blog_bp = Blueprint("blog", __name__)


def _serialize(post: BlogPost) -> dict:
    return {
        "id": post.id,
        "slug": post.slug,
        "title": post.title,
        "excerpt": post.excerpt,
        "content_markdown": post.content_markdown,
        "category": post.category,
        "tags": post.tags or [],
        "status": post.status,
        "cover_image_url": post.cover_image_url,
        "published_at": post.published_at.isoformat() if post.published_at else None,
        "updated_at": post.updated_at.isoformat(),
    }


@blog_bp.get("")
def list_posts():
    query = BlogPost.query.filter_by(status="published")
    category = request.args.get("category")
    if category:
        query = query.filter_by(category=category)
    tag = request.args.get("tag")
    search = request.args.get("q")
    if search:
        like = f"%{search}%"
        query = query.filter(
            db.or_(BlogPost.title.ilike(like), BlogPost.excerpt.ilike(like))
        )
    query = query.order_by(BlogPost.published_at.desc())
    result = paginate(query)
    items = [_serialize(p) for p in result["items"]]
    if tag:
        items = [p for p in items if tag in (p["tags"] or [])]
    result["items"] = items
    return jsonify(result)


@blog_bp.get("/<slug>")
def get_post(slug):
    post = BlogPost.query.filter_by(slug=slug, status="published").first()
    if post is None:
        return jsonify({"error": "Not found."}), 404
    return jsonify(_serialize(post))


@blog_bp.get("/admin/all")
@admin_required
def admin_list_posts():
    query = BlogPost.query.order_by(BlogPost.updated_at.desc())
    result = paginate(query)
    result["items"] = [_serialize(p) for p in result["items"]]
    return jsonify(result)


@blog_bp.post("/admin")
@admin_required
@audit(action="create", entity_type="blog_post")
def create_post():
    data, error = load_or_422(BlogPostSchema())
    if error:
        return error
    post = BlogPost(slug=unique_slug(BlogPost, data["title"]), **data)
    db.session.add(post)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(post)), 201


@blog_bp.put("/admin/<id>")
@admin_required
@audit(action="update", entity_type="blog_post")
def update_post(id):
    post = db.session.get(BlogPost, id)
    if post is None:
        return jsonify({"error": "Not found."}), 404
    data, error = load_or_422(BlogPostSchema(), partial=True)
    if error:
        return error
    if "title" in data and data["title"] != post.title:
        post.slug = unique_slug(BlogPost, data["title"], exclude_id=post.id)
    for key, value in data.items():
        setattr(post, key, value)
    conflict = commit_or_409()
    if conflict:
        return conflict
    return jsonify(_serialize(post))


@blog_bp.delete("/admin/<id>")
@admin_required
@audit(action="delete", entity_type="blog_post")
def delete_post(id):
    post = db.session.get(BlogPost, id)
    if post is None:
        return jsonify({"error": "Not found."}), 404
    db.session.delete(post)
    db.session.commit()
    return "", 204


@blog_bp.post("/admin/<id>/publish")
@admin_required
@audit(action="publish", entity_type="blog_post")
def publish_post(id):
    post = db.session.get(BlogPost, id)
    if post is None:
        return jsonify({"error": "Not found."}), 404
    post.status = "published"
    post.published_at = datetime.now(timezone.utc)
    db.session.commit()
    return jsonify(_serialize(post))
