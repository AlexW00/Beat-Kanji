"""
Beat-based marker insertion controls UI.
Allows users to insert markers at regular beat intervals.
"""

import dearpygui.dearpygui as dpg
from typing import TYPE_CHECKING, Optional, Callable

from core.constants import LANES, LEVEL_NAMES
from utils.input import is_shift_down

if TYPE_CHECKING:
    from core.project import Project


class BeatInsertControls:
    """
    Beat-based marker insertion controls panel.
    Allows inserting markers at regular beat intervals (1/2, 1/4, 1/8, 1/16).
    """

    def __init__(self, project: "Project"):
        self.project = project

        # Callbacks
        # Args: lane, beats_interval, level, start_from_playhead
        self.on_insert_beat_markers: Optional[
            Callable[[str, float, int, bool], None]
        ] = None

    def create(self, parent: int):
        """Create the beat insert controls panel."""
        with dpg.child_window(
            parent=parent,
            width=200,
            height=245,
            label="Beat Insert",
            border=True,
        ):
            self._create_controls_inline()

    def _create_controls_inline(self):
        """Create the controls without a wrapper (for use in custom layouts)."""
        dpg.add_text("Beat Marker Insert", color=(180, 180, 180))
        dpg.add_separator()
        dpg.add_spacer(height=5)

        # Lane selector
        with dpg.group(horizontal=True):
            dpg.add_text("Lane:", color=(150, 150, 150))
            dpg.add_combo(
                items=LANES,
                default_value="base",
                width=100,
                tag="beat_insert_lane",
            )

        dpg.add_spacer(height=3)

        # Beat interval selector
        with dpg.group(horizontal=True):
            dpg.add_text("Every:", color=(150, 150, 150))
            dpg.add_combo(
                items=["4/1", "2/1", "1/1", "1/2", "1/4", "1/8", "1/16"],
                default_value="1/1",
                width=60,
                tag="beat_insert_interval",
            )
            dpg.add_text("beat", color=(150, 150, 150))

        dpg.add_spacer(height=3)

        # Level selector
        with dpg.group(horizontal=True):
            dpg.add_text("Level:", color=(150, 150, 150))
            dpg.add_combo(
                items=["1 (Easy)", "2 (Medium)", "3 (Hard)"],
                default_value="1 (Easy)",
                width=100,
                tag="beat_insert_level",
            )

        dpg.add_spacer(height=10)
        dpg.add_separator()
        dpg.add_spacer(height=5)

        dpg.add_button(
            label="+ Insert Beat Markers",
            callback=lambda: self._on_insert_beat_markers(),
            width=-1,  # Full width
        )

        dpg.add_spacer(height=10)

        # Help text
        dpg.add_text("Inserts markers at", color=(100, 100, 100))
        dpg.add_text("regular beat intervals.", color=(100, 100, 100))
        dpg.add_text("Shift+click: from playhead", color=(130, 130, 100))

    def _on_insert_beat_markers(self):
        """Handle insert beat markers button click."""
        if not self.on_insert_beat_markers:
            return

        # Check if shift is held (insert from playhead)
        start_from_playhead = is_shift_down()

        # Get selected values from UI
        lane = dpg.get_value("beat_insert_lane")
        interval_str = dpg.get_value("beat_insert_interval")
        level_str = dpg.get_value("beat_insert_level")

        # Parse interval string to beats (e.g., "2/1" -> 2.0 beats, "1/4" -> 0.25 beats)
        # Format is "N/D" where interval = N/D beats
        parts = interval_str.split("/")
        if len(parts) == 2:
            numerator = float(parts[0])
            denominator = float(parts[1])
            beats_interval = numerator / denominator
        else:
            beats_interval = 1.0  # Default to every beat

        # Parse level (e.g., "1 (Easy)" -> 1)
        level = int(level_str[0])

        self.on_insert_beat_markers(lane, beats_interval, level, start_from_playhead)

    def update(self):
        """Update the beat insert controls (currently no-op)."""
        pass
