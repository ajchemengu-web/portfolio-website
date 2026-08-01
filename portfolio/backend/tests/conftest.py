import pytest

from app import create_app
from app.config import TestingConfig
from app.extensions import db
from app.models import Admin
from app.utils.security import hash_password


@pytest.fixture()
def app():
    application = create_app(TestingConfig)
    with application.app_context():
        db.create_all()
        yield application
        db.session.remove()
        db.drop_all()


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def admin(app):
    with app.app_context():
        admin = Admin(email="admin@example.com", password_hash=hash_password("SuperSecret123!"))
        db.session.add(admin)
        db.session.commit()
        return admin.id


@pytest.fixture()
def auth_headers(client, admin):
    resp = client.post("/api/auth/login", json={
        "email": "admin@example.com",
        "password": "SuperSecret123!",
    })
    token = resp.get_json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
