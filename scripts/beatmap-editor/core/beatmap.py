"""
Beatmap data model.
Handles loading, saving, and manipulating beatmap data.
"""

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from core.constants import LANES

# Current beatmap version
BEATMAP_VERSION = "1.1"

# Note types mapped to lanes (alias for compatibility)
NOTE_TYPES = LANES

# Level colors (for UI) - kept here as they're in 0-1 float format
# which differs from MARKER_COLORS (0-255 int format)
LEVEL_COLORS = {
    1: (0.2, 0.8, 0.2, 1.0),  # Green - Easy
    2: (0.9, 0.8, 0.2, 1.0),  # Yellow - Medium
    3: (0.9, 0.2, 0.2, 1.0),  # Red - Hard
}


@dataclass
class Note:
    """Represents a single note/marker in the beatmap."""

    time: float  # Timestamp in seconds
    level: int  # Difficulty level: 1=Easy, 2=Medium, 3=Hard
    type: str  # Note type: base, drum, bass, vocal, lead

    # Editor-only fields (not saved to JSON)
    selected: bool = field(default=False, repr=False, compare=False)

    def __post_init__(self):
        # Validate level
        if self.level not in (1, 2, 3):
            raise ValueError(f"Level must be 1, 2, or 3, got {self.level}")
        # Validate type
        if self.type not in NOTE_TYPES:
            raise ValueError(f"Type must be one of {NOTE_TYPES}, got {self.type}")

    def to_dict(self) -> dict:
        """Convert to JSON-serializable dictionary."""
        return {
            "time": round(self.time, 3),
            "level": self.level,
            "type": self.type,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Note":
        """Create Note from dictionary."""
        return cls(
            time=data["time"],
            level=data["level"],
            type=data["type"],
        )

    def copy(self) -> "Note":
        """Create a copy of this note."""
        return Note(time=self.time, level=self.level, type=self.type)


@dataclass
class BeatmapMeta:
    """Metadata for a beatmap."""

    version: str = BEATMAP_VERSION
    filename: str = ""
    title: str = ""
    category: str = ""
    priority: int = 0
    bpm: float = 120.0
    total_duration: float = 0.0

    def to_dict(self) -> dict:
        """Convert to JSON-serializable dictionary."""
        result = {
            "version": self.version,
            "filename": self.filename,
        }
        # Only include title and category if they have values
        if self.title:
            result["title"] = self.title
        if self.category:
            result["category"] = self.category
        result["priority"] = int(self.priority)
        result["bpm"] = round(self.bpm, 1)
        result["total_duration"] = round(self.total_duration, 1)
        return result

    @classmethod
    def from_dict(cls, data: dict) -> "BeatmapMeta":
        """Create BeatmapMeta from dictionary."""
        return cls(
            version=data.get("version", BEATMAP_VERSION),
            filename=data.get("filename", ""),
            title=data.get("title", ""),
            category=data.get("category", ""),
            priority=data.get("priority", 0),
            bpm=data.get("bpm", 120.0),
            total_duration=data.get("total_duration", 0.0),
        )


class Beatmap:
    """
    Beatmap data container.
    Manages notes and metadata for a rhythm game beatmap.
    """

    def __init__(self, meta: Optional[BeatmapMeta] = None):
        self.meta = meta or BeatmapMeta()
        self._notes: list[Note] = []
        self._dirty = False  # Track unsaved changes

    @property
    def notes(self) -> list[Note]:
        """Get all notes (read-only view)."""
        return self._notes

    @property
    def dirty(self) -> bool:
        """Check if there are unsaved changes."""
        return self._dirty

    @dirty.setter
    def dirty(self, value: bool):
        """Set the dirty flag."""
        self._dirty = value

    def mark_dirty(self):
        """Mark the beatmap as having unsaved changes."""
        self._dirty = True

    def mark_clean(self):
        """Mark the beatmap as saved."""
        self._dirty = False

    def add_note(self, note: Note):
        """Add a note and keep list sorted by time."""
        self._notes.append(note)
        self._notes.sort(key=lambda n: n.time)
        self._dirty = True

    def remove_note(self, note: Note):
        """Remove a note from the beatmap."""
        if note in self._notes:
            self._notes.remove(note)
            self._dirty = True

    def remove_notes(self, notes: list[Note]):
        """Remove multiple notes from the beatmap."""
        for note in notes:
            if note in self._notes:
                self._notes.remove(note)
        self._dirty = True

    def get_note_at(self, time: float, tolerance: float = 0.01) -> Optional[Note]:
        """Find a note at approximately the given time."""
        for note in self._notes:
            if abs(note.time - time) <= tolerance:
                return note
        return None

    def get_notes_in_range(self, start_time: float, end_time: float) -> list[Note]:
        """Get all notes within a time range."""
        return [n for n in self._notes if start_time <= n.time <= end_time]

    def get_notes_by_type(self, note_type: str) -> list[Note]:
        """Get all notes of a specific type."""
        return [n for n in self._notes if n.type == note_type]

    def get_notes_by_level(self, level: int) -> list[Note]:
        """Get all notes at a specific difficulty level."""
        return [n for n in self._notes if n.level == level]

    def get_selected_notes(self) -> list[Note]:
        """Get all currently selected notes."""
        return [n for n in self._notes if n.selected]

    def clear_selection(self):
        """Deselect all notes."""
        for note in self._notes:
            note.selected = False

    def select_notes_in_range(
        self, start_time: float, end_time: float, note_type: Optional[str] = None
    ):
        """Select all notes in a time range, optionally filtered by type."""
        for note in self._notes:
            in_range = start_time <= note.time <= end_time
            type_match = note_type is None or note.type == note_type
            if in_range and type_match:
                note.selected = True

    def clear(self):
        """Clear all notes."""
        self._notes.clear()
        self._dirty = True

    def set_notes(self, notes: list[Note]):
        """Replace all notes with a new list."""
        self._notes = sorted(notes, key=lambda n: n.time)
        self._dirty = True

    def to_dict(self) -> dict:
        """Convert beatmap to JSON-serializable dictionary."""
        return {
            "meta": self.meta.to_dict(),
            "notes": [note.to_dict() for note in self._notes],
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Beatmap":
        """Create Beatmap from dictionary."""
        beatmap = cls(meta=BeatmapMeta.from_dict(data.get("meta", {})))
        beatmap._notes = [Note.from_dict(n) for n in data.get("notes", [])]
        beatmap._notes.sort(key=lambda n: n.time)
        return beatmap

    def save(self, path: str):
        """Save beatmap to JSON file."""
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f, indent=2, ensure_ascii=False)
        self._dirty = False

    @classmethod
    def load(cls, path: str) -> "Beatmap":
        """Load beatmap from JSON file."""
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls.from_dict(data)

    def __len__(self) -> int:
        return len(self._notes)

    def __repr__(self) -> str:
        return f"Beatmap({self.meta.filename}, {len(self._notes)} notes, {self.meta.bpm} BPM)"
