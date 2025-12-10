"""
Peak highlight controls UI.
Allows users to configure peak detection thresholds per track and add markers from peaks.
"""

import dearpygui.dearpygui as dpg
from typing import TYPE_CHECKING, Optional, Callable

if TYPE_CHECKING:
    from core.project import Project

from core.constants import (
    WAVEFORMS,
    LANE_TO_WAVEFORM,
    WAVEFORM_TO_LANE,
    TRACK_DISPLAY_NAMES,
    DEFAULT_THRESHOLD_PERCENT,
    DEFAULT_REARM_RATIO,
    MIN_PEAK_GAP_SECONDS,
)
from utils.peaks import PeakState, PeakSettings, detect_peaks
from utils.input import is_shift_down


# Track display names and waveform keys (ordered for UI)
TRACKS = [
    (TRACK_DISPLAY_NAMES["main"], "main"),
    (TRACK_DISPLAY_NAMES["drums"], "drums"),
    (TRACK_DISPLAY_NAMES["bass"], "bass"),
    (TRACK_DISPLAY_NAMES["vocals"], "vocals"),
    (TRACK_DISPLAY_NAMES["other"], "other"),
]


class PeakControls:
    """
    Peak highlight controls panel.
    Displays checkboxes and sliders for each track to configure peak detection,
    plus buttons to add markers from detected peaks.
    """

    def __init__(self, project: "Project"):
        self.project = project
        self.peak_state = PeakState()

        # Callbacks - on_add_markers now takes (waveform_key, peaks, after_playhead_only)
        self.on_peaks_changed: Optional[Callable[[], None]] = None
        self.on_add_markers: Optional[Callable[[str, list[float], bool], None]] = None

        # DearPyGui tags for sliders (to update peak detection on change)
        self._slider_tags: dict[str, int] = {}
        self._rearm_slider_tags: dict[str, int] = {}
        self._checkbox_tags: dict[str, int] = {}
        self._link_checkbox_tags: dict[str, int] = {}
        self._add_button_tags: dict[str, int] = {}

        # Cache tracking to avoid unnecessary peak recalculations
        self._last_settings_hash: dict[str, int] = {}
        self._last_shift_state: bool = False

    def create(self, parent: int):
        """Create the peak controls panel."""
        with dpg.child_window(
            parent=parent,
            width=320,
            height=280,  # Compact layout with both thresholds on same line
            label="Peak Highlight",
            border=True,
        ):
            self._create_controls_inline()

    def _create_controls_inline(self):
        """Create the controls without a wrapper (for use in custom layouts)."""
        dpg.add_text("Peak Highlight", color=(180, 180, 180))
        dpg.add_separator()
        dpg.add_spacer(height=5)

        # Create 2-column layout using a table
        with dpg.table(
            header_row=False,
            borders_innerV=False,
            borders_outerV=False,
            borders_innerH=False,
            borders_outerH=False,
        ):
            dpg.add_table_column(width_fixed=True, init_width_or_weight=155)
            dpg.add_table_column(width_fixed=True, init_width_or_weight=155)

            # Row 1: Main, Drums
            with dpg.table_row():
                with dpg.table_cell():
                    self._create_track_controls("Main", "main")
                with dpg.table_cell():
                    self._create_track_controls("Drums", "drums")

            # Row 2: Bass, Vocals
            with dpg.table_row():
                with dpg.table_cell():
                    self._create_track_controls("Bass", "bass")
                with dpg.table_cell():
                    self._create_track_controls("Vocals", "vocals")

            # Row 3: Other (single)
            with dpg.table_row():
                with dpg.table_cell():
                    self._create_track_controls("Other", "other")
                with dpg.table_cell():
                    pass  # Empty cell

        # Add All button at the bottom
        dpg.add_spacer(height=5)
        dpg.add_separator()
        dpg.add_spacer(height=5)

        # Shift hint text
        dpg.add_text(
            "Hold Shift to insert only after playhead",
            color=(100, 100, 100),
            tag="peak_shift_hint",
        )
        dpg.add_spacer(height=3)

        self._add_all_button_tag = dpg.add_button(
            label="+ Add All Peaks",
            callback=lambda: self._on_add_all_markers(),
            width=-1,  # Full width
            tag="peak_add_all_button",
        )

    def _create_track_controls(self, display_name: str, waveform_key: str):
        """Create controls for a single track (compact layout)."""
        with dpg.group():
            # Row 1: Checkbox + Name + Add button
            with dpg.group(horizontal=True):
                checkbox_tag = dpg.add_checkbox(
                    label="",
                    default_value=False,
                    callback=lambda s, a, u: self._on_checkbox_changed(u, a),
                    user_data=waveform_key,
                    tag=f"peak_checkbox_{waveform_key}",
                )
                self._checkbox_tags[waveform_key] = checkbox_tag

                dpg.add_text(f"{display_name}", color=(150, 150, 150))

                add_btn_tag = dpg.add_button(
                    label="+",
                    callback=lambda s, a, u: self._on_add_markers(u),
                    user_data=waveform_key,
                    width=20,
                    tag=f"peak_add_btn_{waveform_key}",
                )
                self._add_button_tags[waveform_key] = add_btn_tag

                dpg.add_text(
                    "(0)",
                    tag=f"peak_count_{waveform_key}",
                    color=(100, 100, 100),
                )

            # Row 2: Main threshold slider + link checkbox + Re-arm threshold slider (all in one line)
            with dpg.group(horizontal=True):
                slider_tag = dpg.add_slider_int(
                    label="",
                    default_value=50,
                    min_value=0,
                    max_value=100,
                    width=50,
                    callback=lambda s, a, u: self._on_slider_changed(u, a),
                    user_data=waveform_key,
                    tag=f"peak_slider_{waveform_key}",
                )
                self._slider_tags[waveform_key] = slider_tag

                # Link checkbox between the two sliders
                link_checkbox_tag = dpg.add_checkbox(
                    label="",
                    default_value=True,  # Linked by default
                    callback=lambda s, a, u: self._on_link_changed(u, a),
                    user_data=waveform_key,
                    tag=f"peak_link_{waveform_key}",
                )
                self._link_checkbox_tags[waveform_key] = link_checkbox_tag

                # Re-arm threshold slider (default is 70% of 50 = 35)
                rearm_slider_tag = dpg.add_slider_int(
                    label="",
                    default_value=35,
                    min_value=0,
                    max_value=100,
                    width=50,
                    callback=lambda s, a, u: self._on_rearm_slider_changed(u, a),
                    user_data=waveform_key,
                    tag=f"peak_rearm_slider_{waveform_key}",
                    enabled=False,  # Disabled by default (linked)
                )
                self._rearm_slider_tags[waveform_key] = rearm_slider_tag

    def _on_checkbox_changed(self, waveform_key: str, value: bool):
        """Handle checkbox state change."""
        self.peak_state.settings[waveform_key].enabled = value
        self._update_peaks(waveform_key)

        if self.on_peaks_changed:
            self.on_peaks_changed()

    def _on_slider_changed(self, waveform_key: str, value: int):
        """Handle slider value change."""
        settings = self.peak_state.settings[waveform_key]
        old_value = settings.threshold_percent
        settings.threshold_percent = float(value)

        # If linked, move re-arm slider by the same delta (maintain offset)
        if settings.linked:
            delta = value - old_value
            rearm_value = int(settings.rearm_threshold_percent + delta)
            # Clamp to valid range
            rearm_value = max(0, min(100, rearm_value))
            settings.rearm_threshold_percent = float(rearm_value)
            rearm_slider_tag = f"peak_rearm_slider_{waveform_key}"
            if dpg.does_item_exist(rearm_slider_tag):
                dpg.set_value(rearm_slider_tag, rearm_value)

        # Only update if enabled
        if settings.enabled:
            self._update_peaks(waveform_key)

            if self.on_peaks_changed:
                self.on_peaks_changed()

    def _on_rearm_slider_changed(self, waveform_key: str, value: int):
        """Handle re-arm threshold slider value change."""
        settings = self.peak_state.settings[waveform_key]
        settings.rearm_threshold_percent = float(value)

        # Only update if enabled
        if settings.enabled:
            self._update_peaks(waveform_key)

            if self.on_peaks_changed:
                self.on_peaks_changed()

    def _on_link_changed(self, waveform_key: str, value: bool):
        """Handle link checkbox change."""
        settings = self.peak_state.settings[waveform_key]
        settings.linked = value

        # Enable/disable re-arm slider based on link state
        rearm_slider_tag = f"peak_rearm_slider_{waveform_key}"
        if dpg.does_item_exist(rearm_slider_tag):
            dpg.configure_item(rearm_slider_tag, enabled=not value)

        # When re-linking, keep current values (don't reset to ratio)
        # The linked behavior maintains offset, not ratio

    def _on_add_markers(self, waveform_key: str):
        """Handle add markers button click."""
        peaks = self.peak_state.peaks.get(waveform_key, [])
        after_playhead_only = is_shift_down()

        if peaks and self.on_add_markers:
            self.on_add_markers(waveform_key, peaks, after_playhead_only)

    def _on_add_all_markers(self):
        """Handle add all markers button click - adds peaks from all enabled tracks."""
        if not self.on_add_markers:
            return

        after_playhead_only = is_shift_down()

        for waveform_key, settings in self.peak_state.settings.items():
            if settings.enabled:
                peaks = self.peak_state.peaks.get(waveform_key, [])
                if peaks:
                    self.on_add_markers(waveform_key, peaks, after_playhead_only)

    def _update_peaks(self, waveform_key: str):
        """Recalculate peaks for a track."""
        settings = self.peak_state.settings[waveform_key]

        if not settings.enabled:
            self.peak_state.peaks[waveform_key] = []
            self._update_peak_count(waveform_key, 0)
            return

        # Get waveform data
        waveform_data = self.project.waveform_data.get(waveform_key)

        if not waveform_data or self.project.duration <= 0:
            self.peak_state.peaks[waveform_key] = []
            self._update_peak_count(waveform_key, 0)
            return

        # Detect peaks with custom re-arm threshold if not linked
        rearm_threshold = None if settings.linked else settings.rearm_threshold_percent

        peaks = detect_peaks(
            waveform_data=waveform_data,
            duration=self.project.duration,
            threshold_percent=settings.threshold_percent,
            min_gap_seconds=MIN_PEAK_GAP_SECONDS,
            rearm_threshold_percent=rearm_threshold,
        )

        self.peak_state.peaks[waveform_key] = peaks
        self._update_peak_count(waveform_key, len(peaks))

    def _update_peak_count(self, waveform_key: str, count: int):
        """Update the peak count display."""
        tag = f"peak_count_{waveform_key}"
        if dpg.does_item_exist(tag):
            dpg.set_value(tag, f"({count})")

    def update(self):
        """Update peak detection for all enabled tracks and UI state."""
        # Only recalculate peaks if settings changed (not every frame)
        for _, waveform_key in TRACKS:
            settings = self.peak_state.settings[waveform_key]
            if settings.enabled:
                # Check if settings changed since last update
                settings_hash = hash(
                    (
                        settings.enabled,
                        settings.threshold_percent,
                        settings.rearm_threshold_percent,
                        settings.linked,
                    )
                )
                if self._last_settings_hash.get(waveform_key) != settings_hash:
                    self._update_peaks(waveform_key)
                    self._last_settings_hash[waveform_key] = settings_hash

        # Update button labels based on shift key state (only if changed)
        shift_down = is_shift_down()
        if shift_down != self._last_shift_state:
            self._last_shift_state = shift_down
            for waveform_key, btn_tag in self._add_button_tags.items():
                if dpg.does_item_exist(btn_tag):
                    dpg.configure_item(btn_tag, label="▶" if shift_down else "+")

            # Update "Add All" button label
            if dpg.does_item_exist("peak_add_all_button"):
                dpg.configure_item(
                    "peak_add_all_button",
                    label="▶ Add After Playhead" if shift_down else "+ Add All Peaks",
                )

    def get_peaks_for_lane(self, lane_name: str) -> list[float]:
        """Get detected peaks for a lane (mapped from waveform key)."""
        waveform_key = LANE_TO_WAVEFORM.get(lane_name, "main")

        settings = self.peak_state.settings.get(waveform_key)
        if settings and settings.enabled:
            return self.peak_state.peaks.get(waveform_key, [])
        return []

    def is_enabled_for_lane(self, lane_name: str) -> bool:
        """Check if peak highlighting is enabled for a lane."""
        waveform_key = LANE_TO_WAVEFORM.get(lane_name, "main")
        settings = self.peak_state.settings.get(waveform_key)
        return settings.enabled if settings else False
