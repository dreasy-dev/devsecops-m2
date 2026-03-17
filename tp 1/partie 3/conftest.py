"""Pytest config - DB temporaire par test."""
import os
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))


@pytest.fixture(autouse=True)
def temp_db():
    """DB SQLite temporaire pour chaque test."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        path = f.name
    os.environ["DATABASE_PATH"] = path
    from app.database import init_db
    init_db()
    yield
    try:
        os.unlink(path)
    except OSError:
        pass
