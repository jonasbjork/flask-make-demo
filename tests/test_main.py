from app.main import app

def test_index():
    client = app.test_client()
    response = client.get("/")
    data = response.get_json()
    assert response.status_code == 200
    assert data["status"] == "ok"

def test_health():
    client = app.test_client()
    response = client.get("/health")
    data = response.get_json()
    assert response.status_code == 200
    assert data["healthy"] is True
