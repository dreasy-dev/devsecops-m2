"""Tests api-notes."""
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["message"] == "Hello"


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_list_notes_empty():
    response = client.get("/notes")
    assert response.status_code == 200
    assert response.json()["notes"] == []


def test_create_and_list_note():
    r = client.post("/notes", json={"title": "Test", "content": "Contenu"})
    assert r.status_code == 200
    data = r.json()
    assert data["title"] == "Test"
    assert data["content"] == "Contenu"
    assert "id" in data

    r2 = client.get("/notes")
    assert r2.status_code == 200
    assert len(r2.json()["notes"]) >= 1
