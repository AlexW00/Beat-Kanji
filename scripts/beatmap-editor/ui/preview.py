"""
Flying stroke preview window.
Simulates the game's flying stroke visualization.
"""

import dearpygui.dearpygui as dpg
import math
import time
from typing import TYPE_CHECKING, Optional
from dataclasses import dataclass

from core.constants import LANES, MARKER_COLORS

if TYPE_CHECKING:
    from core.project import Project


# Preview configuration (matching game values)
FLIGHT_DURATION = 2.0  # Seconds for stroke to fly from spawn to target
SPAWN_DEPTH = 10.0  # Depth units at spawn (matches game's spawnDepth)
PERSPECTIVE_FACTOR = 0.5  # Perspective scaling factor (matches game)
PREVIEW_WIDTH = 300
PREVIEW_HEIGHT = 200

# Conveyor belt configuration
HORIZON_Y_RATIO = (
    0.15  # Vanishing point Y position (from top, matches game's ConveyorHorizonY)
)
TARGET_Y_RATIO = 0.85  # Target line Y position (from top)

# Preview uses MARKER_COLORS from constants for level colors
LEVEL_COLORS = MARKER_COLORS  # Alias for backward compatibility


@dataclass
class ConveyorLine:
    """A single conveyor belt line."""

    spawn_time: float  # Time when the line was spawned (in song time)


class Preview:
    """
    Flying stroke preview window.
    Shows a simplified simulation of strokes flying toward the player.
    """

    def __init__(self, project: "Project"):
        self.project = project

        # DearPyGui tags
        self._drawlist_tag: Optional[int] = None

        # Filter state
        self._preview_level: int = 3  # Show notes up to this level (1, 2, or 3)
        self._visible_lanes: dict[str, bool] = {lane: True for lane in LANES}

        # UI tags for filter controls
        self._level_radio_tag: Optional[int] = None
        self._lane_checkbox_tags: dict[str, int] = {}

        # Conveyor belt state
        self._conveyor_lines: list[ConveyorLine] = []
        self._next_conveyor_spawn_time: float = 0.0
        self._last_playhead: float = 0.0

    def _should_show_note(self, note) -> bool:
        """Check if a note should be shown based on current filter settings."""
        # Check level filter (show notes with level <= preview_level)
        if note.level > self._preview_level:
            return False
        # Check lane filter
        if not self._visible_lanes.get(note.type, True):
            return False
        return True

    def _on_level_change(self, sender, app_data):
        """Handle level radio button change."""
        # app_data is the label of the selected radio button
        level_map = {"Easy": 1, "Medium": 2, "Hard": 3}
        self._preview_level = level_map.get(app_data, 3)

    def _on_lane_toggle(self, sender, app_data, user_data):
        """Handle lane checkbox toggle."""
        lane = user_data
        self._visible_lanes[lane] = app_data

    def create(self, parent: int):
        """Create the preview widget."""
        with dpg.child_window(
            parent=parent,
            width=PREVIEW_WIDTH + 20,
            height=PREVIEW_HEIGHT + 40,
            label="Preview",
        ):
            dpg.add_text("Flying Strokes Preview")

            self._drawlist_tag = dpg.add_drawlist(
                width=PREVIEW_WIDTH,
                height=PREVIEW_HEIGHT,
            )

        self.update()

    def _get_conveyor_spawn_interval(self) -> float:
        """Get the spawn interval based on BPM (one line per beat)."""
        bpm = self.project.bpm
        if bpm <= 0:
            return 0.5
        return 60.0 / bpm

    def _update_conveyor_lines(self, current_time: float):
        """Update conveyor belt lines, spawning new ones and removing old ones."""
        spawn_interval = self._get_conveyor_spawn_interval()

        # Detect if playhead jumped (seek or loop)
        if abs(current_time - self._last_playhead) > 0.5:
            # Reset conveyor lines on seek
            self._conveyor_lines.clear()

            # Pre-populate lines that should already be in flight at this time
            # Lines spawn at beat boundaries and take FLIGHT_DURATION to reach target
            if spawn_interval > 0:
                # Find the beat boundary at or before (current_time - FLIGHT_DURATION)
                earliest_visible_time = current_time - FLIGHT_DURATION
                first_beat = (earliest_visible_time // spawn_interval) * spawn_interval
                if first_beat < earliest_visible_time:
                    first_beat += spawn_interval

                # Spawn all lines that should be visible now
                spawn_time = first_beat
                while spawn_time <= current_time:
                    self._conveyor_lines.append(ConveyorLine(spawn_time=spawn_time))
                    spawn_time += spawn_interval

                # Set next spawn time to the next beat after current time
                self._next_conveyor_spawn_time = spawn_time
            else:
                self._next_conveyor_spawn_time = current_time

        self._last_playhead = current_time

        # Spawn new lines synced to BPM
        while current_time >= self._next_conveyor_spawn_time:
            self._conveyor_lines.append(
                ConveyorLine(spawn_time=self._next_conveyor_spawn_time)
            )
            self._next_conveyor_spawn_time += spawn_interval

        # Remove lines that have completed their journey
        self._conveyor_lines = [
            line
            for line in self._conveyor_lines
            if (current_time - line.spawn_time) < FLIGHT_DURATION
        ]

    def _draw_conveyor_lines(
        self, current_time: float, horizon_y: float, target_y: float
    ):
        """Draw the BPM-synced conveyor belt lines with perspective."""
        center_x = PREVIEW_WIDTH / 2
        bottom_width = PREVIEW_WIDTH * 0.9  # Width at target line

        for line in self._conveyor_lines:
            elapsed = current_time - line.spawn_time
            progress = elapsed / FLIGHT_DURATION

            if progress < 0 or progress >= 1.0:
                continue

            # Calculate depth (decreases as line moves toward camera)
            current_depth = SPAWN_DEPTH * (1.0 - progress)

            # Perspective scale (increases as line gets closer)
            scale = 1.0 / (1.0 + current_depth * PERSPECTIVE_FACTOR)

            # Calculate Y position using perspective
            # Line moves from horizon_y to target_y
            y = horizon_y + (target_y - horizon_y) * scale

            # Calculate width at this depth
            current_width = bottom_width * scale

            # Alpha based on scale (fades in as it gets closer)
            # Plus a pulse effect near beat times
            base_alpha = 0.1 + 0.4 * scale

            # Beat pulse effect
            spawn_interval = self._get_conveyor_spawn_interval()
            if spawn_interval > 0:
                time_in_beat = elapsed % spawn_interval
                normalized_beat_time = time_in_beat / spawn_interval
                beat_pulse = max(0, 1.0 - normalized_beat_time * 4.0) * 0.3
            else:
                beat_pulse = 0

            alpha = min(1.0, base_alpha + beat_pulse)
            color_value = int(255 * alpha)

            # Draw the line
            x1 = center_x - current_width / 2
            x2 = center_x + current_width / 2

            dpg.draw_line(
                p1=(x1, y),
                p2=(x2, y),
                color=(color_value, color_value, color_value, int(alpha * 200)),
                thickness=2,
                parent=self._drawlist_tag,
            )

    def update(self):
        """Update the preview display."""
        if not self._drawlist_tag:
            return

        # Check if drawlist still exists before trying to modify it
        if not dpg.does_item_exist(self._drawlist_tag):
            return

        # Clear previous drawings
        try:
            dpg.delete_item(self._drawlist_tag, children_only=True)
        except SystemError:
            # Drawlist may have been deleted, skip this update
            return

        # Draw background
        dpg.draw_rectangle(
            pmin=(0, 0),
            pmax=(PREVIEW_WIDTH, PREVIEW_HEIGHT),
            color=(26, 26, 38, 255),
            fill=(26, 26, 38, 255),
            parent=self._drawlist_tag,
        )

        # Calculate positions
        horizon_y = PREVIEW_HEIGHT * HORIZON_Y_RATIO  # Vanishing point near top
        target_y = PREVIEW_HEIGHT * TARGET_Y_RATIO  # Target line near bottom

        current_time = self.project.playhead

        # Update and draw conveyor belt lines (only when playing or audio loaded)
        if self.project.has_audio:
            self._update_conveyor_lines(current_time)
            self._draw_conveyor_lines(current_time, horizon_y, target_y)

        # Draw target line
        dpg.draw_line(
            p1=(20, target_y),
            p2=(PREVIEW_WIDTH - 20, target_y),
            color=(128, 128, 128, 128),
            thickness=2,
            parent=self._drawlist_tag,
        )

        # Draw flying strokes
        # Get notes that should be visible (within flight duration window)
        visible_start = current_time
        visible_end = current_time + FLIGHT_DURATION

        for note in self.project.beatmap.notes:
            if visible_start <= note.time <= visible_end:
                # Apply level and lane filters
                if self._should_show_note(note):
                    self._draw_flying_stroke(note, current_time, horizon_y, target_y)

    def _draw_flying_stroke(
        self, note, current_time: float, horizon_y: float, target_y: float
    ):
        """Draw a single flying stroke with perspective matching the conveyor belt."""
        time_until_arrival = note.time - current_time

        # Calculate progress (1.0 = just spawned, 0.0 = at target)
        progress = time_until_arrival / FLIGHT_DURATION
        progress = max(0.0, min(1.0, progress))

        # Calculate depth (same as conveyor lines)
        current_depth = SPAWN_DEPTH * progress

        # Perspective scale (same as conveyor lines)
        scale = 1.0 / (1.0 + current_depth * PERSPECTIVE_FACTOR)

        # Calculate Y position using perspective (same as conveyor lines)
        y = horizon_y + (target_y - horizon_y) * scale

        # X position based on note type (spread across width, also scaled)
        type_positions = {
            "base": 0.5,
            "drum": 0.3,
            "bass": 0.7,
            "vocal": 0.2,
            "lead": 0.8,
        }
        x_ratio = type_positions.get(note.type, 0.5)
        center_x = PREVIEW_WIDTH / 2
        # X offset from center, scaled by perspective
        x_offset = (x_ratio - 0.5) * (PREVIEW_WIDTH - 40)
        x = center_x + x_offset * scale

        # Size based on perspective scale
        base_size = 15
        size = base_size * scale

        # Alpha based on depth (fades in as it gets closer)
        alpha = int(max(0.0, min(1.0, 1.0 - (current_depth / SPAWN_DEPTH) * 0.7)) * 255)

        # Get color
        base_color = LEVEL_COLORS.get(note.level, LEVEL_COLORS[1])
        color = (base_color[0], base_color[1], base_color[2], alpha)
        fill_color = (base_color[0], base_color[1], base_color[2], alpha // 2)

        # Draw the stroke marker
        dpg.draw_circle(
            center=(x, y),
            radius=size,
            color=color,
            fill=fill_color,
            thickness=2,
            parent=self._drawlist_tag,
        )

        # Draw glow effect for close strokes
        if progress < 0.3:
            glow_alpha = int((0.3 - progress) / 0.3 * 0.3 * 255)
            dpg.draw_circle(
                center=(x, y),
                radius=size * 1.5,
                color=(base_color[0], base_color[1], base_color[2], glow_alpha),
                thickness=3,
                parent=self._drawlist_tag,
            )
