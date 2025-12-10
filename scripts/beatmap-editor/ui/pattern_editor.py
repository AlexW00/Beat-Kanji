"""
Pattern Editor Modal for editing beat patterns in a selection.
Displays a pattern like "oxoxooxx" where 'o' is a beat marker and 'x' is empty.
Allows visual editing with live preview before applying changes.
"""

import dearpygui.dearpygui as dpg
from typing import TYPE_CHECKING, Optional, Callable, List
from dataclasses import dataclass

if TYPE_CHECKING:
    from core.project import Project
    from core.beatmap import Note


@dataclass
class PatternSlot:
    """Represents a single slot in the pattern."""

    time: float  # Grid time position
    has_marker: bool  # Whether there's a marker at this position
    original_marker: bool  # Original state (for preview/cancel)
    note: Optional["Note"] = None  # Reference to existing note (if any)


class PatternEditor:
    """
    Modal dialog for editing beat patterns within a selection.
    Shows pattern like "oxxxxoxoxo" where 'o' = marker, 'x' = empty.
    Supports live preview and apply/cancel actions.
    """

    MODAL_WIDTH = 600
    MODAL_HEIGHT = 380
    SLOT_SIZE = 24  # Size of each pattern slot button
    SLOT_SPACING = 2

    def __init__(self, project: "Project"):
        self.project = project

        # Pattern state
        self.pattern_slots: List[PatternSlot] = []
        self.selected_notes: List["Note"] = []
        self.lane_type: Optional[str] = None
        self.level: int = 1

        # Original state for restoration on cancel
        self._original_notes: List["Note"] = []
        # Store the original beatmap state for cancel
        self._original_beatmap_notes: List["Note"] = []
        # Store the original pattern string for "Apply to All"
        self._original_pattern: str = ""
        # Store the grid step duration for pattern matching
        self._grid_step: float = 0.0

        # UI tags
        self._modal_tag: Optional[int] = None
        self._pattern_group_tag: Optional[int] = None
        self._pattern_text_tag: Optional[int] = None

        # Callbacks - now includes notes_added and notes_removed for history
        self.on_apply: Optional[Callable[[List["Note"], List["Note"]], None]] = None
        self.on_apply_to_all: Optional[
            Callable[[List["Note"], List["Note"], int], None]
        ] = None
        self.on_cancel: Optional[Callable[[], None]] = None

    def open(self, selected_notes: List["Note"], grid_times: List[float]) -> bool:
        """
        Open the pattern editor modal for the given selection.

        Args:
            selected_notes: The currently selected notes (must be from single lane)
            grid_times: All grid positions within the selection range

        Returns:
            True if modal was opened, False if invalid selection
        """
        if not selected_notes:
            return False

        # Verify all notes are from the same lane
        lanes = set(n.type for n in selected_notes)
        if len(lanes) != 1:
            return False  # Can only edit single lane patterns

        self.lane_type = selected_notes[0].type
        self.level = selected_notes[0].level
        self.selected_notes = selected_notes

        # Store original notes for cancel restoration
        self._original_notes = [n.copy() for n in selected_notes]

        # Calculate grid step for pattern matching
        sorted_grid = sorted(grid_times)
        if len(sorted_grid) >= 2:
            self._grid_step = round(sorted_grid[1] - sorted_grid[0], 6)
        else:
            self._grid_step = 0.0

        # Build pattern slots from grid times
        note_times = {round(n.time, 3) for n in selected_notes}
        self.pattern_slots = []

        for grid_time in sorted_grid:
            rounded_time = round(grid_time, 3)
            has_marker = rounded_time in note_times

            # Find the actual note if it exists
            note = None
            for n in selected_notes:
                if round(n.time, 3) == rounded_time:
                    note = n
                    break

            self.pattern_slots.append(
                PatternSlot(
                    time=rounded_time,
                    has_marker=has_marker,
                    original_marker=has_marker,
                    note=note,
                )
            )

        if not self.pattern_slots:
            return False

        # Store original pattern for "Apply to All" matching
        self._original_pattern = self._get_original_pattern_string()

        self._create_modal()
        return True

    def _get_original_pattern_string(self) -> str:
        """Get the original pattern as a string."""
        return "".join(
            "o" if slot.original_marker else "x" for slot in self.pattern_slots
        )

    def _create_modal(self):
        """Create the modal dialog UI."""
        # Generate unique tag for this modal instance
        self._modal_tag = dpg.generate_uuid()

        with dpg.window(
            tag=self._modal_tag,
            label=f"Edit Pattern - {self.lane_type.upper()}",
            modal=True,
            width=self.MODAL_WIDTH,
            height=self.MODAL_HEIGHT,
            pos=(300, 200),
            no_resize=False,
            on_close=self._on_cancel,
        ):
            dpg.add_text(f"Lane: {self.lane_type.upper()} | Level: {self.level}")
            dpg.add_text("Click slots to toggle markers. 'o' = marker, 'x' = empty")
            dpg.add_separator()
            dpg.add_spacer(height=10)

            # Pattern display (text representation)
            self._pattern_text_tag = dpg.add_text(
                self._get_pattern_string(), color=(150, 200, 255, 255)
            )

            dpg.add_spacer(height=10)

            # Pattern slots container (scrollable if many slots)
            with dpg.child_window(
                height=120,
                horizontal_scrollbar=True,
                border=False,
            ):
                self._pattern_group_tag = dpg.add_group(horizontal=True)
                self._create_pattern_slots()

            dpg.add_spacer(height=10)
            dpg.add_separator()
            dpg.add_spacer(height=5)

            # Quick actions
            with dpg.group(horizontal=True):
                dpg.add_button(label="All On", callback=self._set_all_on, width=60)
                dpg.add_button(label="All Off", callback=self._set_all_off, width=60)
                dpg.add_button(label="Invert", callback=self._invert_pattern, width=60)
                dpg.add_button(label="Reset", callback=self._reset_pattern, width=60)

            dpg.add_spacer(height=10)

            # Apply/Cancel buttons
            with dpg.group(horizontal=True):
                dpg.add_button(label="Apply", callback=self._on_apply, width=100)
                dpg.add_spacer(width=10)
                dpg.add_button(
                    label="Apply to All", callback=self._on_apply_to_all, width=100
                )
                dpg.add_spacer(width=10)
                dpg.add_button(label="Cancel", callback=self._on_cancel, width=100)

            # Info text about Apply to All
            dpg.add_text(
                "Apply to All: finds all matching patterns in this lane and applies changes",
                color=(150, 150, 150, 255),
            )

    def _create_pattern_slots(self):
        """Create clickable slot buttons for each grid position."""
        if not self._pattern_group_tag:
            return

        # Clear existing children
        dpg.delete_item(self._pattern_group_tag, children_only=True)

        for i, slot in enumerate(self.pattern_slots):
            # Create a small button for each slot
            label = "o" if slot.has_marker else "x"
            color = (51, 204, 51, 255) if slot.has_marker else (100, 100, 100, 255)

            with dpg.group(parent=self._pattern_group_tag):
                btn = dpg.add_button(
                    label=label,
                    callback=self._on_slot_click,
                    user_data=i,
                    width=self.SLOT_SIZE,
                    height=self.SLOT_SIZE,
                )

                # Apply color theme
                with dpg.theme() as btn_theme:
                    with dpg.theme_component(dpg.mvButton):
                        dpg.add_theme_color(
                            dpg.mvThemeCol_Button,
                            color if slot.has_marker else (60, 60, 60, 255),
                        )
                        dpg.add_theme_color(
                            dpg.mvThemeCol_ButtonHovered,
                            (
                                (color[0] + 30, color[1] + 30, color[2] + 30, 255)
                                if slot.has_marker
                                else (80, 80, 80, 255)
                            ),
                        )
                dpg.bind_item_theme(btn, btn_theme)

    def _on_slot_click(self, sender, app_data, user_data):
        """Handle slot button click."""
        index = user_data
        self._toggle_slot(index)

    def _toggle_slot(self, index: int):
        """Toggle a slot's marker state."""
        if index is not None and 0 <= index < len(self.pattern_slots):
            self.pattern_slots[index].has_marker = not self.pattern_slots[
                index
            ].has_marker
            self._update_display()
            self._update_live_preview()

    def _get_pattern_string(self) -> str:
        """Get the pattern as a string like 'oxxooxoo'."""
        return "".join("o" if slot.has_marker else "x" for slot in self.pattern_slots)

    def _update_display(self):
        """Update the visual display of the pattern."""
        # Update text representation
        if self._pattern_text_tag:
            dpg.set_value(self._pattern_text_tag, self._get_pattern_string())

        # Recreate slot buttons to reflect new state
        self._create_pattern_slots()

    def _update_live_preview(self):
        """Apply live preview by modifying the beatmap temporarily."""
        # This is called on every change for live preview
        # The actual notes are modified in real-time

        # Find notes to add and remove
        times_to_add = []
        times_to_remove = []

        for slot in self.pattern_slots:
            if slot.has_marker and slot.note is None:
                # Need to add a marker here
                times_to_add.append(slot.time)
            elif not slot.has_marker and slot.note is not None:
                # Need to remove this marker
                times_to_remove.append(slot.time)

        # Apply preview changes to beatmap
        from core.beatmap import Note

        # Remove markers
        for slot in self.pattern_slots:
            if not slot.has_marker and slot.note is not None:
                if slot.note in self.project.beatmap.notes:
                    self.project.beatmap._notes.remove(slot.note)
                slot.note = None

        # Add markers
        for slot in self.pattern_slots:
            if slot.has_marker and slot.note is None:
                new_note = Note(time=slot.time, level=self.level, type=self.lane_type)
                self.project.beatmap._notes.append(new_note)
                self.project.beatmap._notes.sort(key=lambda n: n.time)
                slot.note = new_note
                # Select the new note to keep it in the selection
                new_note.selected = True

    def _set_all_on(self, sender=None, app_data=None):
        """Set all slots to have markers."""
        for slot in self.pattern_slots:
            slot.has_marker = True
        self._update_display()
        self._update_live_preview()

    def _set_all_off(self, sender=None, app_data=None):
        """Set all slots to be empty."""
        for slot in self.pattern_slots:
            slot.has_marker = False
        self._update_display()
        self._update_live_preview()

    def _invert_pattern(self, sender=None, app_data=None):
        """Invert the pattern (toggle all slots)."""
        for slot in self.pattern_slots:
            slot.has_marker = not slot.has_marker
        self._update_display()
        self._update_live_preview()

    def _reset_pattern(self, sender=None, app_data=None):
        """Reset pattern to original state."""
        for slot in self.pattern_slots:
            slot.has_marker = slot.original_marker
        self._update_display()
        self._update_live_preview()

    def _on_apply(self, sender=None, app_data=None):
        """Apply the pattern changes and close."""
        from core.beatmap import Note

        # Collect notes that were added and removed
        notes_added = []
        notes_removed = []

        for slot in self.pattern_slots:
            if slot.has_marker and not slot.original_marker:
                # This slot was added - find the note in the beatmap
                if slot.note:
                    notes_added.append(slot.note.copy())
            elif not slot.has_marker and slot.original_marker:
                # This slot was removed - find the original note
                for orig_note in self._original_notes:
                    if round(orig_note.time, 3) == round(slot.time, 3):
                        notes_removed.append(orig_note.copy())
                        break

        # Close the modal
        self._close()

        # Callback with the notes that were added and removed
        if self.on_apply:
            self.on_apply(notes_added, notes_removed)

    def _on_apply_to_all(self, sender=None, app_data=None):
        """Apply pattern changes to all matching occurrences in the lane."""
        from core.beatmap import Note

        # First, collect the changes for the current selection (same as _on_apply)
        notes_added = []
        notes_removed = []

        # Build the new pattern relative offsets
        # For each slot, determine if it changed from original
        pattern_length = len(self.pattern_slots)
        if pattern_length == 0 or self._grid_step <= 0:
            # Fall back to regular apply
            self._on_apply()
            return

        # Collect changes for current selection
        for slot in self.pattern_slots:
            if slot.has_marker and not slot.original_marker:
                if slot.note:
                    notes_added.append(slot.note.copy())
            elif not slot.has_marker and slot.original_marker:
                for orig_note in self._original_notes:
                    if round(orig_note.time, 3) == round(slot.time, 3):
                        notes_removed.append(orig_note.copy())
                        break

        # Now find all other occurrences of the original pattern in the lane
        # and apply the same transformation
        all_notes_in_lane = [
            n for n in self.project.beatmap.notes if n.type == self.lane_type
        ]
        all_note_times = {round(n.time, 3): n for n in all_notes_in_lane}

        # Get the current selection time range to exclude it
        current_min_time = min(slot.time for slot in self.pattern_slots) - 0.001
        current_max_time = max(slot.time for slot in self.pattern_slots) + 0.001

        # Find pattern matches by scanning through possible start positions
        pattern_duration = (pattern_length - 1) * self._grid_step
        matches_count = 0

        # Generate all possible start times on the grid
        min_note_time = min(all_note_times.keys()) if all_note_times else 0
        max_note_time = (
            max(all_note_times.keys()) if all_note_times else self.project.duration
        )

        # Scan through potential pattern start positions
        current_time = 0.0
        while current_time + pattern_duration <= self.project.duration:
            # Skip if this overlaps with the current selection
            pattern_end = current_time + pattern_duration
            if not (pattern_end < current_min_time or current_time > current_max_time):
                current_time += self._grid_step
                continue

            # Check if this position matches the original pattern
            matches = True
            for i, slot in enumerate(self.pattern_slots):
                check_time = round(current_time + i * self._grid_step, 3)
                has_note = check_time in all_note_times
                expected = slot.original_marker
                if has_note != expected:
                    matches = False
                    break

            if matches:
                matches_count += 1
                # Apply the same transformation to this occurrence
                for i, slot in enumerate(self.pattern_slots):
                    check_time = round(current_time + i * self._grid_step, 3)

                    if slot.has_marker and not slot.original_marker:
                        # Need to add a note here
                        if check_time not in all_note_times:
                            new_note = Note(
                                time=check_time, level=self.level, type=self.lane_type
                            )
                            self.project.beatmap._notes.append(new_note)
                            notes_added.append(new_note.copy())
                            all_note_times[check_time] = new_note

                    elif not slot.has_marker and slot.original_marker:
                        # Need to remove a note here
                        if check_time in all_note_times:
                            note_to_remove = all_note_times[check_time]
                            if note_to_remove in self.project.beatmap._notes:
                                notes_removed.append(note_to_remove.copy())
                                self.project.beatmap._notes.remove(note_to_remove)
                                del all_note_times[check_time]

            current_time += self._grid_step

        # Sort the notes after all modifications
        self.project.beatmap._notes.sort(key=lambda n: n.time)

        # Close the modal
        self._close()

        # Callback with all the notes that were added and removed, plus match count
        if self.on_apply_to_all:
            self.on_apply_to_all(notes_added, notes_removed, matches_count)
        elif self.on_apply:
            # Fallback to regular apply callback
            self.on_apply(notes_added, notes_removed)

    def _on_cancel(self, sender=None, app_data=None):
        """Cancel changes and restore original state."""
        # Restore original notes
        self._restore_original_state()

        # Close the modal
        self._close()

        # Callback
        if self.on_cancel:
            self.on_cancel()

    def _restore_original_state(self):
        """Restore the beatmap to its original state before editing."""
        from core.beatmap import Note

        # Remove all notes in the current selection range from this lane
        min_time = min(slot.time for slot in self.pattern_slots) - 0.001
        max_time = max(slot.time for slot in self.pattern_slots) + 0.001

        notes_to_remove = [
            n
            for n in self.project.beatmap.notes
            if n.type == self.lane_type and min_time <= n.time <= max_time
        ]

        for note in notes_to_remove:
            if note in self.project.beatmap._notes:
                self.project.beatmap._notes.remove(note)

        # Add back the original notes
        for original_note in self._original_notes:
            new_note = Note(
                time=original_note.time,
                level=original_note.level,
                type=original_note.type,
            )
            new_note.selected = True
            self.project.beatmap._notes.append(new_note)

        self.project.beatmap._notes.sort(key=lambda n: n.time)

    def _close(self):
        """Close the modal dialog."""
        if self._modal_tag:
            try:
                dpg.delete_item(self._modal_tag)
            except Exception:
                pass

        # Reset state
        self.pattern_slots = []
        self.selected_notes = []
        self._original_notes = []
        self._modal_tag = None
        self._pattern_group_tag = None
        self._pattern_text_tag = None
