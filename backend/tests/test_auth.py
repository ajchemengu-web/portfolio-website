def test_login_requires_valid_json(client):
    resp = client.post("/api/auth/login", json={"email": "not-an-email"})
    assert resp.status_code == 422


def test_login_rejects_unknown_email(client):
    resp = client.post("/api/auth/login", json={"email": "nobody@example.com", "password": "whatever123456"})
    assert resp.status_code == 401


def test_login_success_and_me(client, admin):
    resp = client.post("/api/auth/login", json={
        "email": "admin@example.com",
        "password": "SuperSecret123!",
    })
    assert resp.status_code == 200
    body = resp.get_json()
    assert "access_token" in body
    assert "refresh_token" in body

    me_resp = client.get("/api/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me_resp.status_code == 200
    assert me_resp.get_json()["email"] == "admin@example.com"


def test_login_wrong_password_locks_out_after_five_attempts(client, admin):
    for _ in range(5):
        resp = client.post("/api/auth/login", json={
            "email": "admin@example.com",
            "password": "wrong-password",
        })
        assert resp.status_code == 401

    locked_resp = client.post("/api/auth/login", json={
        "email": "admin@example.com",
        "password": "SuperSecret123!",  # even the correct password is now rejected
    })
    assert locked_resp.status_code == 423


def test_protected_route_requires_token(client):
    resp = client.get("/api/auth/me")
    assert resp.status_code == 401


def test_logout_revokes_token(client, auth_headers):
    logout_resp = client.post("/api/auth/logout", headers=auth_headers)
    assert logout_resp.status_code == 200

    me_resp = client.get("/api/auth/me", headers=auth_headers)
    assert me_resp.status_code == 401
