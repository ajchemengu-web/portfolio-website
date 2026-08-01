def test_public_list_excludes_drafts(client, auth_headers):
    create_resp = client.post("/api/research/admin", json={"title": "My Draft Study"}, headers=auth_headers)
    assert create_resp.status_code == 201
    project_id = create_resp.get_json()["id"]
    assert create_resp.get_json()["is_draft"] is True

    public_resp = client.get("/api/research")
    assert public_resp.status_code == 200
    assert public_resp.get_json()["items"] == []

    publish_resp = client.post(f"/api/research/admin/{project_id}/publish", headers=auth_headers)
    assert publish_resp.status_code == 200
    assert publish_resp.get_json()["is_draft"] is False

    public_resp_2 = client.get("/api/research")
    assert len(public_resp_2.get_json()["items"]) == 1


def test_create_research_requires_auth(client):
    resp = client.post("/api/research/admin", json={"title": "Should Fail"})
    assert resp.status_code == 401


def test_create_research_validates_input(client, auth_headers):
    resp = client.post("/api/research/admin", json={"status": "not-a-real-status"}, headers=auth_headers)
    assert resp.status_code == 422


def test_slug_collision_gets_suffixed(client, auth_headers):
    first = client.post("/api/research/admin", json={"title": "AI Safety"}, headers=auth_headers)
    second = client.post("/api/research/admin", json={"title": "AI Safety"}, headers=auth_headers)
    assert first.get_json()["slug"] == "ai-safety"
    assert second.get_json()["slug"] == "ai-safety-2"


def test_contact_form_rejects_bad_payload(client):
    resp = client.post("/api/contact", json={"name": "", "email": "not-an-email", "message": ""})
    assert resp.status_code == 422


def test_contact_form_accepts_valid_payload(client):
    resp = client.post("/api/contact", json={
        "name": "Jane Reviewer",
        "email": "jane@example.com",
        "message": "Loved your research on federated learning!",
    })
    assert resp.status_code == 201
