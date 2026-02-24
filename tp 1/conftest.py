"""Pytest configuration - ensure app is on Python path."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
