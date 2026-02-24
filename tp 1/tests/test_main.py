"""Tests for api-notes FastAPI application."""

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_hello_docker():
    """Root endpoint returns Hello Docker message."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello Docker"}


def test_list_notes_empty():
    """List notes returns empty list initially."""
    response = client.get("/notes")
    assert response.status_code == 200
    assert response.json() == {"notes": []}


def test_create_and_list_note():
    """Create a note and list it."""
    create_response = client.post(
        "/notes",
        json={"title": "Test Note", "content": "Test content"},
    )
    assert create_response.status_code == 200
    data = create_response.json()
    assert data["title"] == "Test Note"
    assert data["content"] == "Test content"
    assert "id" in data

    list_response = client.get("/notes")
    assert list_response.status_code == 200
    assert len(list_response.json()["notes"]) >= 1
