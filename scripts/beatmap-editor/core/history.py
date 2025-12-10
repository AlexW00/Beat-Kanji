"""
Undo/Redo history management using Command pattern.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from .beatmap import Beatmap, Note


class Command(ABC):
    """Abstract base class for undoable commands."""

    @abstractmethod
    def execute(self):
        """Execute the command."""
        pass

    @abstractmethod
    def undo(self):
        """Undo the command."""
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """Human-readable description of the command."""
        pass


class AddNoteCommand(Command):
    """Command to add a note to the beatmap."""

    def __init__(self, beatmap: "Beatmap", note: "Note"):
        self.beatmap = beatmap
        self.note = note

    def execute(self):
        self.beatmap.add_note(self.note)

    def undo(self):
        self.beatmap.remove_note(self.note)

    @property
    def description(self) -> str:
        return f"Add {self.note.type} note at {self.note.time:.3f}s"


class AddNotesCommand(Command):
    """Command to add multiple notes to the beatmap."""

    def __init__(self, beatmap: "Beatmap", notes: list["Note"]):
        self.beatmap = beatmap
        self.notes = notes

    def execute(self):
        for note in self.notes:
            self.beatmap.add_note(note)

    def undo(self):
        self.beatmap.remove_notes(self.notes)

    @property
    def description(self) -> str:
        return f"Add {len(self.notes)} notes"


class RemoveNoteCommand(Command):
    """Command to remove a note from the beatmap."""

    def __init__(self, beatmap: "Beatmap", note: "Note"):
        self.beatmap = beatmap
        self.note = note.copy()  # Store a copy for undo

    def execute(self):
        self.beatmap.remove_note(self.note)

    def undo(self):
        self.beatmap.add_note(self.note)

    @property
    def description(self) -> str:
        return f"Remove {self.note.type} note at {self.note.time:.3f}s"


class RemoveNotesCommand(Command):
    """Command to remove multiple notes from the beatmap."""

    def __init__(self, beatmap: "Beatmap", notes: list["Note"]):
        self.beatmap = beatmap
        self.notes = [n.copy() for n in notes]  # Store copies for undo

    def execute(self):
        self.beatmap.remove_notes(self.notes)

    def undo(self):
        for note in self.notes:
            self.beatmap.add_note(note)

    @property
    def description(self) -> str:
        return f"Remove {len(self.notes)} notes"


class MoveNoteCommand(Command):
    """Command to move a note to a new time/type."""

    def __init__(
        self,
        beatmap: "Beatmap",
        note: "Note",
        new_time: float,
        new_type: Optional[str] = None,
    ):
        self.beatmap = beatmap
        self.note = note
        self.old_time = note.time
        self.new_time = new_time
        self.old_type = note.type
        self.new_type = new_type if new_type is not None else note.type

    def execute(self):
        self.note.time = self.new_time
        self.note.type = self.new_type
        # Re-sort the notes list
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    def undo(self):
        self.note.time = self.old_time
        self.note.type = self.old_type
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        if self.old_type != self.new_type:
            return f"Move note from {self.old_time:.3f}s to {self.new_time:.3f}s and change to {self.new_type}"
        return f"Move note from {self.old_time:.3f}s to {self.new_time:.3f}s"


class ChangeLevelCommand(Command):
    """Command to change the difficulty level of a note."""

    def __init__(self, beatmap: "Beatmap", note: "Note", new_level: int):
        self.beatmap = beatmap
        self.note = note
        self.old_level = note.level
        self.new_level = new_level

    def execute(self):
        self.note.level = self.new_level
        self.beatmap.mark_dirty()

    def undo(self):
        self.note.level = self.old_level
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        return f"Change level from {self.old_level} to {self.new_level}"


class ChangeLevelsCommand(Command):
    """Command to change the difficulty level of multiple notes."""

    def __init__(self, beatmap: "Beatmap", notes: list["Note"], new_level: int):
        self.beatmap = beatmap
        self.notes = notes
        self.old_levels = [n.level for n in notes]
        self.new_level = new_level

    def execute(self):
        for note in self.notes:
            note.level = self.new_level
        self.beatmap.mark_dirty()

    def undo(self):
        for note, old_level in zip(self.notes, self.old_levels):
            note.level = old_level
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        return f"Change {len(self.notes)} notes to level {self.new_level}"


class CompositeCommand(Command):
    """Command that groups multiple commands together."""

    def __init__(self, commands: list[Command], description_text: str = ""):
        self.commands = commands
        self._description = description_text or f"Composite ({len(commands)} actions)"

    def execute(self):
        for cmd in self.commands:
            cmd.execute()

    def undo(self):
        # Undo in reverse order
        for cmd in reversed(self.commands):
            cmd.undo()

    @property
    def description(self) -> str:
        return self._description


class SnapNotesCommand(Command):
    """Command to snap multiple notes to a grid."""

    def __init__(self, beatmap: "Beatmap", notes: list["Note"], new_times: list[float]):
        self.beatmap = beatmap
        self.notes = notes
        self.old_times = [n.time for n in notes]
        self.new_times = new_times

    def execute(self):
        for note, new_time in zip(self.notes, self.new_times):
            note.time = new_time
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    def undo(self):
        for note, old_time in zip(self.notes, self.old_times):
            note.time = old_time
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        return f"Snap {len(self.notes)} notes to grid"


class MoveNotesCommand(Command):
    """Command to move multiple notes (change time and/or lane)."""

    def __init__(
        self,
        beatmap: "Beatmap",
        notes: list["Note"],
        new_times: list[float] = None,
        new_types: list[str] = None,
        description_text: str = "",
    ):
        self.beatmap = beatmap
        self.notes = notes
        self.old_times = [n.time for n in notes]
        self.old_types = [n.type for n in notes]
        self.new_times = new_times if new_times is not None else self.old_times
        self.new_types = new_types if new_types is not None else self.old_types
        self._description = description_text

    def execute(self):
        for note, new_time, new_type in zip(self.notes, self.new_times, self.new_types):
            note.time = new_time
            note.type = new_type
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    def undo(self):
        for note, old_time, old_type in zip(self.notes, self.old_times, self.old_types):
            note.time = old_time
            note.type = old_type
        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        if self._description:
            return self._description
        return f"Move {len(self.notes)} notes"


class CleanupDuplicatesCommand(Command):
    """Command to remove duplicate notes at the same time."""

    def __init__(self, beatmap: "Beatmap", notes_to_remove: list["Note"]):
        self.beatmap = beatmap
        self.notes_to_remove = [n.copy() for n in notes_to_remove]

    def execute(self):
        self.beatmap.remove_notes(self.notes_to_remove)

    def undo(self):
        for note in self.notes_to_remove:
            self.beatmap.add_note(note)

    @property
    def description(self) -> str:
        return f"Clean up {len(self.notes_to_remove)} duplicate notes"


class PatternEditCommand(Command):
    """Command to edit a pattern (add/remove multiple notes in one operation)."""

    def __init__(
        self,
        beatmap: "Beatmap",
        notes_to_add: list["Note"],
        notes_to_remove: list["Note"],
        lane_type: str,
    ):
        self.beatmap = beatmap
        self.notes_to_add = [n.copy() for n in notes_to_add]
        self.notes_to_remove = [n.copy() for n in notes_to_remove]
        self.lane_type = lane_type

    def execute(self):
        # Remove notes first
        for note in self.notes_to_remove:
            # Find and remove matching note
            for existing in self.beatmap._notes[:]:
                if (
                    round(existing.time, 3) == round(note.time, 3)
                    and existing.type == note.type
                ):
                    self.beatmap._notes.remove(existing)
                    break

        # Then add new notes
        for note in self.notes_to_add:
            new_note = note.copy()
            new_note.selected = True
            self.beatmap._notes.append(new_note)

        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    def undo(self):
        # Remove added notes
        for note in self.notes_to_add:
            for existing in self.beatmap._notes[:]:
                if (
                    round(existing.time, 3) == round(note.time, 3)
                    and existing.type == note.type
                ):
                    self.beatmap._notes.remove(existing)
                    break

        # Re-add removed notes
        for note in self.notes_to_remove:
            new_note = note.copy()
            new_note.selected = True
            self.beatmap._notes.append(new_note)

        self.beatmap._notes.sort(key=lambda n: n.time)
        self.beatmap.mark_dirty()

    @property
    def description(self) -> str:
        added = len(self.notes_to_add)
        removed = len(self.notes_to_remove)
        return f"Edit {self.lane_type} pattern (+{added}, -{removed})"


class History:
    """
    Manages undo/redo history using a command stack.
    """

    def __init__(self, max_size: int = 100):
        self._undo_stack: list[Command] = []
        self._redo_stack: list[Command] = []
        self._max_size = max_size

    def execute(self, command: Command):
        """Execute a command and add it to the history."""
        command.execute()
        self._undo_stack.append(command)
        self._redo_stack.clear()  # Clear redo stack on new action
        self._trim_stack()

    def record(self, command: Command):
        """
        Record a command that was already executed (e.g., from live preview).
        Use this instead of directly manipulating _undo_stack.
        """
        self._undo_stack.append(command)
        self._redo_stack.clear()
        self._trim_stack()

    def _trim_stack(self):
        """Trim undo stack if it exceeds max size."""
        while len(self._undo_stack) > self._max_size:
            self._undo_stack.pop(0)

    def undo(self) -> Optional[str]:
        """
        Undo the last command.

        Returns:
            Description of undone command, or None if nothing to undo.
        """
        if not self._undo_stack:
            return None

        command = self._undo_stack.pop()
        command.undo()
        self._redo_stack.append(command)
        return command.description

    def redo(self) -> Optional[str]:
        """
        Redo the last undone command.

        Returns:
            Description of redone command, or None if nothing to redo.
        """
        if not self._redo_stack:
            return None

        command = self._redo_stack.pop()
        command.execute()
        self._undo_stack.append(command)
        return command.description

    def can_undo(self) -> bool:
        """Check if there are commands to undo."""
        return len(self._undo_stack) > 0

    def can_redo(self) -> bool:
        """Check if there are commands to redo."""
        return len(self._redo_stack) > 0

    def clear(self):
        """Clear all history."""
        self._undo_stack.clear()
        self._redo_stack.clear()

    @property
    def undo_description(self) -> Optional[str]:
        """Get description of next command to undo."""
        if self._undo_stack:
            return self._undo_stack[-1].description
        return None

    @property
    def redo_description(self) -> Optional[str]:
        """Get description of next command to redo."""
        if self._redo_stack:
            return self._redo_stack[-1].description
        return None
