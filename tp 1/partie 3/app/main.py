"""Mini API notes - FastAPI + SQLite."""

from contextlib import contextmanager

from fastapi import FastAPI
from pydantic import BaseModel

from app.database import get_connection, init_db

app = FastAPI(title="api-notes")


@contextmanager
def db_cursor():
    conn = get_connection()
    try:
        yield conn.cursor()
        conn.commit()
    finally:
        conn.close()


class NoteCreate(BaseModel):
    title: str
    content: str


@app.on_event("startup")
def startup():
    init_db()


@app.get("/")
def root():
    return {"message": "Hello", "status": "ok"}


@app.get("/notes")
def list_notes():
    with db_cursor() as cur:
        cur.execute("SELECT id, title, content, created_at FROM notes ORDER BY id")
        rows = cur.fetchall()
        notes = [
            {"id": r["id"], "title": r["title"], "content": r["content"], "created_at": r["created_at"]}
            for r in rows
        ]
    return {"notes": notes}


@app.post("/notes")
def create_note(note: NoteCreate):
    with db_cursor() as cur:
        cur.execute("INSERT INTO notes (title, content) VALUES (?, ?)", (note.title, note.content))
        row_id = cur.lastrowid
        cur.execute("SELECT id, title, content, created_at FROM notes WHERE id = ?", (row_id,))
        r = cur.fetchone()
    return {"id": r["id"], "title": r["title"], "content": r["content"], "created_at": r["created_at"]}
