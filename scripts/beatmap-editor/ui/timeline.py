"""
Timeline widget for beatmap editor.
Displays waveforms, grid lines, and markers for each lane.
"""

import dearpygui.dearpygui as dpg
import numpy as np
from typing import Optional, Callable, TYPE_CHECKING

from core.constants import (
    LANES,
    LANE_TO_WAVEFORM,
    LANE_HEIGHT,
    LANE_SPACING,
    HEADER_HEIGHT,
    SCROLLBAR_HEIGHT,
    LABEL_COLUMN_WIDTH,
    COLORS,
    MARKER_COLORS,
    MARKER_RADIUS,
    MARKER_CLICK_TOLERANCE,
    DEFAULT_ZOOM,
    MIN_ZOOM,
    MAX_ZOOM,
)
from utils.input import is_ctrl_down, is_shift_down, is_alt_down, is_modifier_down
from core.history import MoveNotesCommand

if TYPE_CHECKING:
    from core.project import Project
    from core.beatmap import Note
    from ui.peak_controls import PeakControls


class Timeline:
    """
    Timeline widget showing lanes with waveforms and markers.
    """

    def __init__(self, project: "Project"):
        self.project = project

        # View state
        self.zoom = DEFAULT_ZOOM  # Pixels per second
        self.scroll_x = 0.0  # Scroll offset in seconds
        self.width = 800
        self.height = len(LANES) * (LANE_HEIGHT + LANE_SPACING) + HEADER_HEIGHT

        # Interaction state
        self.dragging_playhead: bool = False
        self.selecting = False
        self.selection_start: Optional[tuple[float, float]] = None  # (x, y) coordinates
        self._selection_end: Optional[tuple[float, float]] = None  # (x, y) coordinates

        # Peak controls reference (set by app.py)
        self.peak_controls: Optional["PeakControls"] = None

        # DearPyGui tags
        self._window_tag: Optional[int] = None
        self._drawlist_tag: Optional[int] = None
        self._labels_drawlist_tag: Optional[int] = None  # Sticky labels column

        # Callbacks
        self.on_marker_click: Optional[Callable[["Note"], None]] = None
        self.on_marker_double_click: Optional[Callable[["Note"], None]] = None
        self.on_add_marker: Optional[Callable[[float, str], None]] = None
        self.on_playhead_click: Optional[Callable[[float], None]] = None

        # Dirty tracking for performance
        self._needs_full_redraw: bool = True
        self._last_playhead: float = 0.0
        self._last_zoom: float = DEFAULT_ZOOM
        self._last_duration: float = 0.0
        self._last_note_count: int = 0
        self._last_bpm: float = 0.0

        # Waveform cache: {waveform_key: {zoom_level: (points_upper, points_lower)}}
        self._waveform_cache: dict[str, dict[int, tuple[list, list]]] = {}

    def create(self, parent: int):
        """Create the timeline widget."""
        # Window height: content + horizontal scrollbar
        # Add +1 to drawlist to force minimal vertical overflow (fixes DearPyGui scroll bug)
        window_height = self.height + SCROLLBAR_HEIGHT

        # Create a horizontal group to hold sticky labels and scrollable timeline
        with dpg.group(parent=parent, horizontal=True):
            # Sticky labels column (non-scrollable)
            with dpg.child_window(
                width=LABEL_COLUMN_WIDTH,
                height=window_height,
                no_scrollbar=True,
                border=False,
            ):
                self._labels_drawlist_tag = dpg.add_drawlist(
                    width=LABEL_COLUMN_WIDTH,
                    height=self.height + 1,
                    tag="timeline_labels_drawlist",
                )

            # Scrollable timeline content
            with dpg.child_window(
                tag="timeline_window",
                width=-1,
                height=window_height,
                horizontal_scrollbar=True,  # Show horizontal scrollbar
            ) as self._window_tag:
                # Calculate total width based on duration
                total_width = max(800, int(self.project.duration * self.zoom))

                # Drawlist slightly taller than window to force scroll activation
                # This is a workaround for DearPyGui's scroll behavior
                self._drawlist_tag = dpg.add_drawlist(
                    width=total_width,
                    height=self.height + 1,  # +1 forces scroll to work properly
                    tag="timeline_drawlist",
                )

            # Register mouse handlers
            with dpg.handler_registry():
                dpg.add_mouse_click_handler(callback=self._on_mouse_click)
                dpg.add_mouse_double_click_handler(callback=self._on_mouse_double_click)
                dpg.add_mouse_drag_handler(callback=self._on_mouse_drag)
                dpg.add_mouse_release_handler(callback=self._on_mouse_release)
                # Arrow key handlers for moving selected markers / playhead
                dpg.add_key_press_handler(dpg.mvKey_Left, callback=self._on_key_left)
                dpg.add_key_press_handler(dpg.mvKey_Right, callback=self._on_key_right)
                dpg.add_key_press_handler(dpg.mvKey_Up, callback=self._on_key_up)
                dpg.add_key_press_handler(dpg.mvKey_Down, callback=self._on_key_down)

    def update(self):
        """Redraw the timeline (only if needed)."""
        if not self._drawlist_tag:
            return

        # Check if drawlist still exists
        if not dpg.does_item_exist(self._drawlist_tag):
            return

        # Check if full redraw is needed
        needs_redraw = self._check_dirty_state()

        if not needs_redraw:
            return

        # Clear previous drawings
        try:
            dpg.delete_item(self._drawlist_tag, children_only=True)
        except SystemError:
            return

        # Calculate total width
        total_width = max(800, int(self.project.duration * self.zoom))
        dpg.configure_item(self._drawlist_tag, width=total_width)

        # Draw components
        self._draw_background(total_width)
        self._draw_grid(total_width)
        self._draw_lanes(total_width)
        self._draw_peak_highlights()
        self._draw_markers()
        self._draw_playhead()
        self._draw_selection_box()

        # Draw sticky labels column
        self._draw_sticky_labels()

        # Reset dirty flag
        self._needs_full_redraw = False

    def _check_dirty_state(self) -> bool:
        """
        Check if redraw is needed based on state changes.
        Returns True if redraw is required.
        """
        # Always redraw if explicitly marked dirty
        if self._needs_full_redraw:
            self._update_cached_state()
            return True

        # Check if playhead moved
        if self._last_playhead != self.project.playhead:
            self._update_cached_state()
            return True

        # Check if zoom changed
        if self._last_zoom != self.zoom:
            self._update_cached_state()
            return True

        # Check if duration changed
        if self._last_duration != self.project.duration:
            self._update_cached_state()
            return True

        # Check if note count changed (simplified dirty check)
        current_note_count = len(self.project.beatmap.notes)
        if self._last_note_count != current_note_count:
            self._update_cached_state()
            return True

        # Check if BPM changed (affects grid lines)
        if self._last_bpm != self.project.bpm:
            self._update_cached_state()
            return True

        # Check if selecting (need to update selection box)
        if self.selecting:
            return True

        return False

    def _update_cached_state(self):
        """Update cached state values."""
        self._last_playhead = self.project.playhead
        self._last_zoom = self.zoom
        self._last_duration = self.project.duration
        self._last_note_count = len(self.project.beatmap.notes)
        self._last_bpm = self.project.bpm

    def mark_dirty(self):
        """Mark the timeline as needing a full redraw."""
        self._needs_full_redraw = True

    def invalidate_waveform_cache(self, waveform_key: Optional[str] = None):
        """Invalidate waveform cache (call when audio/stems change)."""
        if waveform_key:
            self._waveform_cache.pop(waveform_key, None)
        else:
            self._waveform_cache.clear()
        self._needs_full_redraw = True

    def _draw_background(self, total_width: int):
        """Draw timeline background."""
        dpg.draw_rectangle(
            pmin=(0, 0),
            pmax=(total_width, self.height),
            color=COLORS["background"],
            fill=COLORS["background"],
            parent=self._drawlist_tag,
        )

    def _draw_grid(self, total_width: int):
        """Draw beat grid lines."""
        if self.project.bpm <= 0:
            return

        beat_duration = 60.0 / self.project.bpm
        subdivision = 16  # 1/16 note grid

        sub_duration = beat_duration / subdivision
        sub_width = sub_duration * self.zoom

        x = 0.0
        beat_index = 0

        while x < total_width:
            # Determine line style based on beat position
            if beat_index % subdivision == 0:
                # Full beat
                color = COLORS["grid_beat"]
                thickness = 1.5
            elif beat_index % 4 == 0:
                # Quarter subdivision
                color = COLORS["grid_sub"]
                thickness = 1.0
            else:
                # Fine subdivision (only draw if zoomed in enough)
                if self.zoom > 50:
                    color = (*COLORS["grid_sub"][:3], 51)  # Low alpha (51/255 ~ 0.2)
                    thickness = 0.5
                else:
                    beat_index += 1
                    x += sub_width
                    continue

            dpg.draw_line(
                p1=(x, HEADER_HEIGHT),
                p2=(x, self.height),
                color=color,
                thickness=thickness,
                parent=self._drawlist_tag,
            )

            # Draw beat number on major beats
            if beat_index % subdivision == 0:
                beat_num = beat_index // subdivision + 1
                dpg.draw_text(
                    pos=(x + 2, 5),
                    text=str(beat_num),
                    color=COLORS["text"],
                    size=12,
                    parent=self._drawlist_tag,
                )

            beat_index += 1
            x += sub_width

    def _draw_lanes(self, total_width: int):
        """Draw lane backgrounds (labels are in sticky column)."""
        for i, lane_name in enumerate(LANES):
            y_start = HEADER_HEIGHT + i * (LANE_HEIGHT + LANE_SPACING)
            y_end = y_start + LANE_HEIGHT

            # Lane background
            dpg.draw_rectangle(
                pmin=(0, y_start),
                pmax=(total_width, y_end),
                color=COLORS["lane_border"],
                fill=COLORS["lane_bg"],
                thickness=1,
                parent=self._drawlist_tag,
            )

            # Draw waveform for this lane (if stems available)
            self._draw_lane_waveform(lane_name, y_start, y_end, total_width)

    def _draw_sticky_labels(self):
        """Draw sticky lane labels in the fixed left column."""
        if not self._labels_drawlist_tag:
            return

        # Clear previous drawings
        dpg.delete_item(self._labels_drawlist_tag, children_only=True)

        # Draw background for labels column
        dpg.draw_rectangle(
            pmin=(0, 0),
            pmax=(LABEL_COLUMN_WIDTH, self.height),
            color=COLORS["background"],
            fill=COLORS["background"],
            parent=self._labels_drawlist_tag,
        )

        # Draw each lane label
        for i, lane_name in enumerate(LANES):
            y_start = HEADER_HEIGHT + i * (LANE_HEIGHT + LANE_SPACING)
            y_end = y_start + LANE_HEIGHT

            # Lane label background (matching lane style)
            dpg.draw_rectangle(
                pmin=(0, y_start),
                pmax=(LABEL_COLUMN_WIDTH, y_end),
                color=COLORS["lane_border"],
                fill=COLORS["lane_bg"],
                thickness=1,
                parent=self._labels_drawlist_tag,
            )

            # Lane label text (centered vertically in lane)
            text_y = y_start + (LANE_HEIGHT - 11) / 2  # 11 is font size
            dpg.draw_text(
                pos=(5, text_y),
                text=lane_name.upper(),
                color=COLORS["text"],
                size=11,
                parent=self._labels_drawlist_tag,
            )

    def _draw_lane_waveform(
        self, lane_name: str, y_start: float, y_end: float, total_width: int
    ):
        """Draw waveform for a specific lane as a connected line graph."""
        waveform_key = LANE_TO_WAVEFORM.get(lane_name)
        waveform_data = (
            self.project.waveform_data.get(waveform_key) if waveform_key else None
        )

        center_y = (y_start + y_end) / 2
        lane_height = y_end - y_start
        half_height = (lane_height * 0.85) / 2  # Use 85% of lane height

        # Check if waveform_data is the new dict format or old list format
        if waveform_data:
            if isinstance(waveform_data, dict):
                waveform_min = waveform_data.get("min", [])
                waveform_max = waveform_data.get("max", [])
                num_samples = len(waveform_min)
            else:
                # Legacy list format - treat as symmetric
                waveform_min = [-v for v in waveform_data]
                waveform_max = waveform_data
                num_samples = len(waveform_data)
        else:
            num_samples = 0

        if num_samples > 0:
            duration = self.project.duration

            if duration > 0:
                # Check cache for precomputed polylines
                zoom_key = int(self.zoom)
                cache_key = f"{waveform_key}_{zoom_key}_{total_width}"

                # Try to get from cache
                cached = self._get_cached_waveform(waveform_key, zoom_key, total_width)

                if cached:
                    points_upper, points_lower = cached
                else:
                    # Calculate and cache polylines
                    points_upper, points_lower = self._compute_waveform_polylines(
                        waveform_min,
                        waveform_max,
                        num_samples,
                        total_width,
                        center_y,
                        half_height,
                    )
                    self._cache_waveform(
                        waveform_key, zoom_key, total_width, points_upper, points_lower
                    )

                # Offset points to correct y position
                offset_upper = [
                    (x, center_y - (center_y - y) + (y_start + y_end) / 2 - center_y)
                    for x, y in points_upper
                ]
                offset_lower = [
                    (x, center_y - (center_y - y) + (y_start + y_end) / 2 - center_y)
                    for x, y in points_lower
                ]

                # Actually, let's just recompute with correct y values for simplicity
                # The caching benefit comes from not recomputing sample indices
                envelope_color = COLORS["waveform"]
                line_thickness = 1.0

                # Draw upper envelope (positive peaks)
                if len(points_upper) > 1:
                    dpg.draw_polyline(
                        points=points_upper,
                        color=envelope_color,
                        thickness=line_thickness,
                        parent=self._drawlist_tag,
                    )

                # Draw lower envelope (negative peaks)
                if len(points_lower) > 1:
                    dpg.draw_polyline(
                        points=points_lower,
                        color=envelope_color,
                        thickness=line_thickness,
                        parent=self._drawlist_tag,
                    )

                # Fill between envelopes for better visibility
                if len(points_upper) > 1 and len(points_lower) > 1:
                    fill_color = (*COLORS["waveform"][:3], 60)  # Semi-transparent fill
                    fill_points = points_upper + list(reversed(points_lower))
                    dpg.draw_polygon(
                        points=fill_points,
                        color=(0, 0, 0, 0),  # No outline
                        fill=fill_color,
                        parent=self._drawlist_tag,
                    )
        else:
            # Draw placeholder center line if no waveform data
            dpg.draw_line(
                p1=(0, center_y),
                p2=(total_width, center_y),
                color=(*COLORS["waveform"][:3], 50),
                thickness=1,
                parent=self._drawlist_tag,
            )

    def _compute_waveform_polylines(
        self,
        waveform_min: list,
        waveform_max: list,
        num_samples: int,
        total_width: int,
        center_y: float,
        half_height: float,
    ) -> tuple[list, list]:
        """Compute polyline points for waveform visualization."""
        # Calculate samples per pixel - higher detail rendering
        samples_per_pixel = num_samples / total_width

        # Determine step size based on zoom level for performance
        if self.zoom > 200:
            step = 1  # Maximum detail at high zoom
        elif self.zoom > 100:
            step = max(1, int(total_width / 3000))
        elif self.zoom > 50:
            step = max(1, int(total_width / 2000))
        else:
            step = max(1, int(total_width / 1500))

        # Build points for upper and lower envelope lines
        points_upper = []  # max values (upper envelope)
        points_lower = []  # min values (lower envelope)

        for px in range(0, int(total_width), step):
            # Get sample range for this pixel
            sample_start = int(px * samples_per_pixel)
            sample_end = int((px + step) * samples_per_pixel)
            sample_start = min(sample_start, num_samples - 1)
            sample_end = min(sample_end, num_samples)

            if sample_start >= sample_end:
                continue

            # Get min/max over the sample range for this pixel
            chunk_min = min(waveform_min[sample_start:sample_end])
            chunk_max = max(waveform_max[sample_start:sample_end])

            # Convert to y coordinates
            y_upper = center_y - chunk_max * half_height  # max goes up
            y_lower = center_y - chunk_min * half_height  # min goes down

            points_upper.append((px, y_upper))
            points_lower.append((px, y_lower))

        return points_upper, points_lower

    def _get_cached_waveform(
        self, waveform_key: str, zoom_key: int, total_width: int
    ) -> Optional[tuple[list, list]]:
        """Get cached waveform polylines if available."""
        cache_dict = self._waveform_cache.get(waveform_key)
        if cache_dict:
            return cache_dict.get((zoom_key, total_width))
        return None

    def _cache_waveform(
        self,
        waveform_key: str,
        zoom_key: int,
        total_width: int,
        points_upper: list,
        points_lower: list,
    ):
        """Cache waveform polylines."""
        if waveform_key not in self._waveform_cache:
            self._waveform_cache[waveform_key] = {}
        # Limit cache size per waveform (keep last 3 zoom levels)
        if len(self._waveform_cache[waveform_key]) > 3:
            # Remove oldest entry
            oldest_key = next(iter(self._waveform_cache[waveform_key]))
            del self._waveform_cache[waveform_key][oldest_key]
        self._waveform_cache[waveform_key][(zoom_key, total_width)] = (
            points_upper,
            points_lower,
        )

    def _draw_markers(self):
        """Draw all markers/notes."""
        for note in self.project.beatmap.notes:
            self._draw_marker(note)

    def _draw_peak_highlights(self):
        """Draw peak highlight markers for lanes with peak detection enabled."""
        if not self.peak_controls:
            return

        for i, lane_name in enumerate(LANES):
            if not self.peak_controls.is_enabled_for_lane(lane_name):
                continue

            peaks = self.peak_controls.get_peaks_for_lane(lane_name)
            if not peaks:
                continue

            y_start = HEADER_HEIGHT + i * (LANE_HEIGHT + LANE_SPACING)
            y_end = y_start + LANE_HEIGHT

            for peak_time in peaks:
                x = peak_time * self.zoom

                # Draw vertical line for peak
                dpg.draw_line(
                    p1=(x, y_start + 5),
                    p2=(x, y_end - 5),
                    color=COLORS["peak_highlight"],
                    thickness=2,
                    parent=self._drawlist_tag,
                )

                # Draw small triangle at top
                dpg.draw_triangle(
                    p1=(x, y_start + 5),
                    p2=(x - 4, y_start + 12),
                    p3=(x + 4, y_start + 12),
                    color=COLORS["peak_highlight"],
                    fill=COLORS["peak_highlight"],
                    parent=self._drawlist_tag,
                )

    def _draw_marker(self, note: "Note"):
        """Draw a single marker."""
        # Get lane index
        lane_index = LANES.index(note.type) if note.type in LANES else 0

        # Calculate position
        x = note.time * self.zoom
        y_start = HEADER_HEIGHT + lane_index * (LANE_HEIGHT + LANE_SPACING)
        y_center = y_start + LANE_HEIGHT / 2

        # Get color based on level
        color = MARKER_COLORS.get(note.level, COLORS["marker_1"])

        # Draw marker
        dpg.draw_circle(
            center=(x, y_center),
            radius=MARKER_RADIUS,
            color=color,
            fill=color,
            parent=self._drawlist_tag,
        )

        # Draw selection outline
        if note.selected:
            dpg.draw_circle(
                center=(x, y_center),
                radius=MARKER_RADIUS + 3,
                color=COLORS["marker_selected"],
                thickness=2,
                parent=self._drawlist_tag,
            )

    def _draw_playhead(self):
        """Draw the playhead indicator."""
        x = self.project.playhead * self.zoom

        # Vertical line
        dpg.draw_line(
            p1=(x, 0),
            p2=(x, self.height),
            color=COLORS["playhead"],
            thickness=2,
            parent=self._drawlist_tag,
        )

        # Triangle at top
        dpg.draw_triangle(
            p1=(x, 0),
            p2=(x - 8, 15),
            p3=(x + 8, 15),
            color=COLORS["playhead"],
            fill=COLORS["playhead"],
            parent=self._drawlist_tag,
        )

    def _draw_selection_box(self):
        """Draw selection box if selecting."""
        if not self.selecting or not self.selection_start or not self._selection_end:
            return

        x1, y1 = self.selection_start
        x2, y2 = self._selection_end

        # Draw selection rectangle
        dpg.draw_rectangle(
            pmin=(min(x1, x2), min(y1, y2)),
            pmax=(max(x1, x2), max(y1, y2)),
            color=(100, 150, 255, 200),
            fill=(100, 150, 255, 50),
            thickness=1,
            parent=self._drawlist_tag,
        )

    def _get_time_at_x(self, x: float) -> float:
        """Convert x coordinate to time."""
        return x / self.zoom

    def _get_lane_at_y(self, y: float) -> Optional[int]:
        """Get lane index at y coordinate."""
        if y < HEADER_HEIGHT:
            return None

        adjusted_y = y - HEADER_HEIGHT
        lane_index = int(adjusted_y / (LANE_HEIGHT + LANE_SPACING))

        if 0 <= lane_index < len(LANES):
            return lane_index
        return None

    def _get_marker_at(self, x: float, y: float) -> Optional["Note"]:
        """Find a marker at the given coordinates."""
        time = self._get_time_at_x(x)
        lane_index = self._get_lane_at_y(y)

        if lane_index is None:
            return None

        lane_name = LANES[lane_index]

        # Calculate marker center y position for this lane
        lane_y_start = HEADER_HEIGHT + lane_index * (LANE_HEIGHT + LANE_SPACING)
        marker_center_y = lane_y_start + LANE_HEIGHT / 2

        # Check vertical distance from marker center
        vertical_tolerance = MARKER_RADIUS + 5  # Marker radius + small padding
        if abs(y - marker_center_y) > vertical_tolerance:
            return None

        # Search for marker near this position (horizontal tolerance)
        tolerance = MARKER_CLICK_TOLERANCE / self.zoom

        for note in self.project.beatmap.notes:
            if note.type == lane_name and abs(note.time - time) <= tolerance:
                return note

        return None

    def _on_mouse_click(self, sender, app_data):
        """Handle mouse click."""
        # app_data is the mouse button (0=left, 1=right, 2=middle)
        # Only handle left clicks
        if app_data != 0:
            return

        if not self._is_mouse_over_timeline():
            return

        mouse_pos = dpg.get_mouse_pos(local=False)
        local_pos = self._screen_to_local(mouse_pos)

        if local_pos is None:
            return

        x, y = local_pos

        # Check for modifier key (Ctrl/Cmd)
        modifier_down = is_ctrl_down()

        # Check if clicking on a marker
        marker = self._get_marker_at(x, y)

        if marker:
            # Handle selection
            if modifier_down:
                # Toggle selection with modifier
                marker.selected = not marker.selected
            elif not marker.selected:
                # If clicking on an unselected marker without modifier, clear selection and select this one
                self.project.beatmap.clear_selection()
                marker.selected = True
            # If clicking on an already selected marker without modifier, keep the selection

            if self.on_marker_click:
                self.on_marker_click(marker)
        else:
            # Check if clicking on header (playhead area)
            if y < HEADER_HEIGHT:
                time = self._get_time_at_x(x)
                self.dragging_playhead = True
                if self.on_playhead_click:
                    self.on_playhead_click(time)
            else:
                # Clicking on empty lane space - start box selection
                if not modifier_down:
                    self.project.beatmap.clear_selection()
                self.selecting = True
                self.selection_start = (x, y)
                self._selection_end = (x, y)

        self.mark_dirty()

    def _on_mouse_double_click(self, sender, app_data):
        """Handle double click."""
        if not self._is_mouse_over_timeline():
            return

        mouse_pos = dpg.get_mouse_pos(local=False)
        local_pos = self._screen_to_local(mouse_pos)

        if local_pos is None:
            return

        x, y = local_pos

        # Check if double-clicking on a marker
        marker = self._get_marker_at(x, y)

        if marker:
            # Cycle level
            if self.on_marker_double_click:
                self.on_marker_double_click(marker)
        else:
            # Add new marker
            lane_index = self._get_lane_at_y(y)
            if lane_index is not None:
                time = self._get_time_at_x(x)
                lane_name = LANES[lane_index]

                if self.on_add_marker:
                    self.on_add_marker(time, lane_name)

        self.mark_dirty()

    def _on_mouse_drag(self, sender, app_data):
        """Handle mouse drag for playhead or box selection."""
        # Don't require hover check during active drag operations
        if not (self.selecting or self.dragging_playhead):
            if not self._is_mouse_over_timeline():
                return

        mouse_pos = dpg.get_mouse_pos(local=False)
        local_pos = self._screen_to_local(mouse_pos)

        if local_pos is None:
            return

        x, y = local_pos

        # Playhead dragging mode
        if self.dragging_playhead:
            time = self._get_time_at_x(x)
            time = max(0, min(time, self.project.duration))
            if self.on_playhead_click:
                self.on_playhead_click(time)
            self.mark_dirty()
            return

        # Box selection mode
        if self.selecting and self.selection_start:
            self._selection_end = (x, y)
            self._update_box_selection()
            self.mark_dirty()
            return

    def _update_box_selection(self):
        """Update selection based on current box."""
        if not self.selection_start or not self._selection_end:
            return

        x1, y1 = self.selection_start
        x2, y2 = self._selection_end

        # Normalize coordinates
        min_x, max_x = min(x1, x2), max(x1, x2)
        min_y, max_y = min(y1, y2), max(y1, y2)

        # Convert to time range
        min_time = self._get_time_at_x(min_x)
        max_time = self._get_time_at_x(max_x)

        # Get lane range
        min_lane = self._get_lane_at_y(min_y)
        max_lane = self._get_lane_at_y(max_y)

        # Check for modifier key (Ctrl/Cmd)
        modifier_down = is_ctrl_down()

        # If not holding modifier, clear existing selection first
        if not modifier_down:
            for note in self.project.beatmap.notes:
                note.selected = False

        # Select markers within the box
        for note in self.project.beatmap.notes:
            # Check time range
            if not (min_time <= note.time <= max_time):
                continue

            # Check lane (if we have valid lane bounds)
            if min_lane is not None and max_lane is not None:
                try:
                    note_lane = LANES.index(note.type)
                    if not (min_lane <= note_lane <= max_lane):
                        continue
                except ValueError:
                    continue

            note.selected = True

    def _on_mouse_release(self, sender, app_data):
        """Handle mouse release."""
        self.dragging_playhead = False
        self.selecting = False
        self.selection_start = None
        self._selection_end = None
        self.mark_dirty()

    def _on_key_left(self, sender, app_data):
        """Handle left arrow key - move selected markers left or move playhead."""
        if is_modifier_down():
            # Cmd/Ctrl+Left: Move playhead instead of selection
            self._move_playhead(-1)
        elif is_alt_down():
            # Option+Left: Snap selection to previous beat
            self._snap_selection_to_beat(-1)
        else:
            # Regular Left: Move selected markers
            self._move_selected_markers(-1)

    def _on_key_right(self, sender, app_data):
        """Handle right arrow key - move selected markers right or move playhead."""
        if is_modifier_down():
            # Cmd/Ctrl+Right: Move playhead instead of selection
            self._move_playhead(1)
        elif is_alt_down():
            # Option+Right: Snap selection to next beat
            self._snap_selection_to_beat(1)
        else:
            # Regular Right: Move selected markers
            self._move_selected_markers(1)

    def _on_key_up(self, sender, app_data):
        """Handle up arrow key - move selection to previous lane, or adjust spacing with Alt."""
        if is_alt_down():
            # Option+Up: Increase spacing between selected markers
            self._adjust_selection_spacing(1)
        else:
            # Regular Up: Move selected markers to previous lane
            self._move_selection_to_lane(-1)

    def _on_key_down(self, sender, app_data):
        """Handle down arrow key - move selection to next lane, or adjust spacing with Alt."""
        if is_alt_down():
            # Option+Down: Decrease spacing between selected markers
            self._adjust_selection_spacing(-1)
        else:
            # Regular Down: Move selected markers to next lane
            self._move_selection_to_lane(1)

    def _move_selection_to_lane(self, direction: int):
        """Move selected markers to the next/previous lane.

        Args:
            direction: -1 for previous lane (up), 1 for next lane (down)
        """
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            return

        # Calculate new lanes for each note
        new_types = []
        for note in selected:
            current_lane_index = LANES.index(note.type) if note.type in LANES else 0
            new_lane_index = current_lane_index + direction
            # Clamp to valid lane range
            new_lane_index = max(0, min(new_lane_index, len(LANES) - 1))
            new_types.append(LANES[new_lane_index])

        # Check if any notes actually changed
        if all(note.type == new_type for note, new_type in zip(selected, new_types)):
            return  # No change needed

        # Create and execute command
        cmd = MoveNotesCommand(
            self.project.beatmap,
            selected,
            new_types=new_types,
            description_text=f"Move {len(selected)} notes {'up' if direction < 0 else 'down'} lane",
        )
        self.project.history.execute(cmd)
        self.mark_dirty()

    def _move_playhead(self, direction: int):
        """Move the playhead by grid steps.

        Args:
            direction: -1 for left, 1 for right
        """
        # Check if shift is held for larger movement (4 steps instead of 1)
        shift_down = is_shift_down()
        steps = 4 if shift_down else 1

        # Calculate grid step size (1/16 note)
        if self.project.bpm > 0:
            beat_duration = 60.0 / self.project.bpm
            grid_step = beat_duration / 16  # 1/16 note

            # Snap current position to nearest grid point first, then move
            current_grid_index = round(self.project.playhead / grid_step)
            new_grid_index = current_grid_index + (direction * steps)
            new_time = new_grid_index * grid_step
        else:
            grid_step = 0.1  # Fallback: 100ms
            new_time = self.project.playhead + (direction * steps * grid_step)

        # Clamp to valid range
        new_time = max(0, min(new_time, self.project.duration))
        self.project.playhead = new_time

        # Notify via callback if available
        if self.on_playhead_click:
            self.on_playhead_click(self.project.playhead)

        self.mark_dirty()

    def _snap_selection_to_beat(self, direction: int):
        """Snap selection to 1/4 beat grid, then move by 1/4 beat.

        Args:
            direction: -1 for left, 1 for right
        """
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            return

        if self.project.bpm <= 0:
            return

        # Calculate 1/4 beat duration (quarter note = 1/4 of a full beat)
        beat_duration = 60.0 / self.project.bpm
        quarter_beat = beat_duration / 4  # 1/4 of a beat

        # Calculate new times: snap to 1/4 grid, then move by 1/4 beat
        new_times = []
        for note in selected:
            # Step 1: Snap current position to nearest 1/4 beat grid
            snapped_time = round(note.time / quarter_beat) * quarter_beat
            # Step 2: Move by 1/4 beat in the specified direction
            new_time = snapped_time + (direction * quarter_beat)
            # Clamp to valid range
            new_time = max(0, min(new_time, self.project.duration))
            new_times.append(round(new_time, 3))

        # Create and execute command
        cmd = MoveNotesCommand(
            self.project.beatmap,
            selected,
            new_times=new_times,
            description_text=f"Snap and move {len(selected)} notes {'left' if direction < 0 else 'right'}",
        )
        self.project.history.execute(cmd)
        self.mark_dirty()

    def _adjust_selection_spacing(self, direction: int):
        """Adjust the spacing between selected markers.

        Args:
            direction: 1 to increase spacing, -1 to decrease spacing
        """
        selected = self.project.beatmap.get_selected_notes()
        if len(selected) < 2:
            return

        # Calculate grid step size (1/16 note)
        if self.project.bpm > 0:
            beat_duration = 60.0 / self.project.bpm
            grid_step = beat_duration / 16  # 1/16 note
        else:
            grid_step = 0.1  # Fallback: 100ms

        # Sort notes by time
        selected_sorted = sorted(selected, key=lambda n: n.time)

        # Use the first note as anchor (it stays in place)
        anchor_time = selected_sorted[0].time

        # Calculate new times for each note
        new_times = []
        for i, note in enumerate(selected_sorted):
            if i == 0:
                new_times.append(note.time)  # First note stays in place
                continue

            # Calculate how much to move this note
            # Each subsequent note moves by i * grid_step in the direction
            time_delta = direction * i * grid_step
            new_time = note.time + time_delta

            # Clamp to valid range and ensure it doesn't go before the anchor
            if direction < 0:
                # When decreasing, don't let notes collapse past each other
                min_time = anchor_time + (
                    i * grid_step * 0.5
                )  # Keep at least half spacing
                new_time = max(min_time, new_time)
            new_time = max(0, min(new_time, self.project.duration))
            new_times.append(round(new_time, 3))

        # Create and execute command (use sorted notes to match new_times order)
        cmd = MoveNotesCommand(
            self.project.beatmap,
            selected_sorted,
            new_times=new_times,
            description_text=f"{'Increase' if direction > 0 else 'Decrease'} spacing of {len(selected)} notes",
        )
        self.project.history.execute(cmd)
        self.mark_dirty()

    def _move_selected_markers(self, direction: int):
        """Move all selected markers by grid steps.

        Args:
            direction: -1 for left, 1 for right
        """
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            return

        # Check if shift is held for larger movement (4 steps instead of 1)
        shift_down = is_shift_down()

        steps = 4 if shift_down else 1

        # Calculate grid step size (1/16 note)
        if self.project.bpm > 0:
            beat_duration = 60.0 / self.project.bpm
            grid_step = beat_duration / 16  # 1/16 note
        else:
            grid_step = 0.1  # Fallback: 100ms

        # Calculate total time delta
        time_delta = direction * steps * grid_step

        # Calculate new times for all selected markers
        new_times = []
        for note in selected:
            new_time = note.time + time_delta
            # Clamp to valid range
            new_time = max(0, min(new_time, self.project.duration))
            new_times.append(round(new_time, 3))

        # Create and execute command
        cmd = MoveNotesCommand(
            self.project.beatmap,
            selected,
            new_times=new_times,
            description_text=f"Move {len(selected)} notes {'left' if direction < 0 else 'right'}",
        )
        self.project.history.execute(cmd)
        self.mark_dirty()

    def _is_mouse_over_timeline(self) -> bool:
        """Check if mouse is over the timeline."""
        if not self._window_tag:
            return False
        # Check if hovering over the window OR the drawlist
        return dpg.is_item_hovered("timeline_window") or dpg.is_item_hovered(
            "timeline_drawlist"
        )

    def _screen_to_local(
        self, screen_pos: tuple[float, float]
    ) -> Optional[tuple[float, float]]:
        """Convert screen coordinates to timeline local coordinates."""
        if not self._window_tag:
            return None

        # Get window position
        window_pos = dpg.get_item_pos("timeline_window")

        # Get scroll offset
        scroll_x = dpg.get_x_scroll("timeline_window")

        local_x = screen_pos[0] - window_pos[0] + scroll_x
        local_y = screen_pos[1] - window_pos[1]

        return (local_x, local_y)

    def set_zoom(self, zoom: float, center_time: float = None):
        """Set zoom level (pixels per second), optionally keeping a time centered.

        Args:
            zoom: New zoom level (pixels per second)
            center_time: If provided, adjust scroll to keep this time at the same screen position
        """
        old_zoom = self.zoom
        self.zoom = max(MIN_ZOOM, min(MAX_ZOOM, zoom))

        # If center_time provided, adjust scroll to keep it centered
        if center_time is not None and self._window_tag and old_zoom != self.zoom:
            # Get current scroll and window width
            current_scroll = dpg.get_x_scroll("timeline_window")
            window_width = dpg.get_item_width("timeline_window")

            # Calculate where center_time was on screen (relative to window)
            old_x = center_time * old_zoom
            screen_offset = old_x - current_scroll

            # Calculate new position and scroll to keep same screen offset
            new_x = center_time * self.zoom
            new_scroll = new_x - screen_offset

            # Apply new scroll (clamp to valid range)
            new_scroll = max(0, new_scroll)
            dpg.set_x_scroll("timeline_window", new_scroll)

        self.mark_dirty()

    def zoom_in(self, center_time: float = None):
        """Zoom in, optionally centered on a specific time."""
        self.set_zoom(self.zoom * 1.2, center_time)

    def zoom_out(self, center_time: float = None):
        """Zoom out, optionally centered on a specific time."""
        self.set_zoom(self.zoom / 1.2, center_time)

    def get_visible_center_time(self) -> float:
        """Get the time at the center of the visible timeline area."""
        if not self._window_tag:
            return self.project.playhead

        scroll_x = dpg.get_x_scroll("timeline_window")
        window_width = dpg.get_item_width("timeline_window")
        center_x = scroll_x + window_width / 2
        return center_x / self.zoom

    def scroll_to_time(self, time: float):
        """Scroll to show a specific time."""
        if self._window_tag:
            x = time * self.zoom
            dpg.set_x_scroll("timeline_window", x - 100)
