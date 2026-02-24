"""api-notes FastAPI application."""

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="api-notes")

notes: list[dict] = []


class NoteCreate(BaseModel):
    """Note creation model."""

    title: str
    content: str


@app.get("/")
def root():
    """Root endpoint - returns Hello Docker message."""
    return {"message": "Hello Docker"}


@app.get("/notes")
def list_notes():
    """List all notes."""
    return {"notes": notes}


@app.post("/notes")
def create_note(note: NoteCreate):
    """Create a new note."""
    new_note = {"id": len(notes) + 1, "title": note.title, "content": note.content}
    notes.append(new_note)
    return new_note
