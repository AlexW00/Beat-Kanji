"""
Transport controls for audio playback.
Play/pause, seek, and time display.
"""

import dearpygui.dearpygui as dpg
from typing import TYPE_CHECKING, Optional, Callable
from utils.input import register_text_input

if TYPE_CHECKING:
    from core.project import Project
    from audio.player import AudioPlayer


def format_time(seconds: float) -> str:
    """Format seconds as MM:SS.ms"""
    minutes = int(seconds // 60)
    secs = seconds % 60
    return f"{minutes:02d}:{secs:05.2f}"


class Transport:
    """
    Transport controls widget.
    Provides play/pause, seek, and time display.
    """

    def __init__(self, project: "Project", audio_player: "AudioPlayer"):
        self.project = project
        self.audio_player = audio_player

        # Callbacks
        self.on_play: Optional[Callable[[], None]] = None
        self.on_pause: Optional[Callable[[], None]] = None
        self.on_seek: Optional[Callable[[float], None]] = None
        self.on_zoom: Optional[Callable[[int], None]] = None  # direction: -1 or +1
        self.on_bpm_change: Optional[Callable[[float], None]] = None  # New BPM value
        self.on_meta_change: Optional[Callable[[], None]] = None  # Meta fields changed

        # Tags for UI elements
        self._time_text_tag: Optional[int] = None
        self._play_button_tag: Optional[int] = None
        self._bpm_input_tag: Optional[int] = None
        self._title_input_tag: Optional[int] = None
        self._category_input_tag: Optional[int] = None
        self._priority_input_tag: Optional[int] = None

    def create(self, parent: int):
        """Create the transport controls."""
        with dpg.group(horizontal=True, parent=parent):
            # Rewind button
            dpg.add_button(
                label="|<",
                width=40,
                callback=self._on_rewind,
            )

            # Play/Pause button
            self._play_button_tag = dpg.add_button(
                label=">",
                width=40,
                callback=self._on_play_pause,
            )

            # Forward button
            dpg.add_button(
                label=">|",
                width=40,
                callback=self._on_forward,
            )

            dpg.add_spacer(width=20)

            # Time display
            self._time_text_tag = dpg.add_text(
                default_value="00:00.00 / 00:00.00",
            )

            dpg.add_spacer(width=20)

            # BPM input (editable)
            dpg.add_text(default_value="BPM:")
            self._bpm_input_tag = dpg.add_input_float(
                default_value=self.project.bpm,
                min_value=20.0,
                max_value=300.0,
                min_clamped=True,
                max_clamped=True,
                step=0.1,
                step_fast=1.0,
                width=80,
                format="%.1f",
                callback=self._on_bpm_change,
            )
            register_text_input(self._bpm_input_tag)

            dpg.add_spacer(width=20)

            # Title input
            dpg.add_text(default_value="Title:")
            self._title_input_tag = dpg.add_input_text(
                default_value=self.project.beatmap.meta.title,
                width=150,
                callback=self._on_title_change,
                on_enter=True,
            )
            register_text_input(self._title_input_tag)

            dpg.add_spacer(width=10)

            # Category input
            dpg.add_text(default_value="Category:")
            self._category_input_tag = dpg.add_input_text(
                default_value=self.project.beatmap.meta.category,
                width=150,
                callback=self._on_category_change,
                on_enter=True,
            )
            register_text_input(self._category_input_tag)

            dpg.add_spacer(width=10)

            # Priority input
            dpg.add_text(default_value="Priority:")
            self._priority_input_tag = dpg.add_input_int(
                default_value=int(self.project.beatmap.meta.priority),
                width=80,
                callback=self._on_priority_change,
                on_enter=True,
            )
            register_text_input(self._priority_input_tag)

            dpg.add_spacer(width=20)

            # Zoom controls
            dpg.add_text(default_value="Zoom:")
            dpg.add_button(label="-", width=30, callback=lambda: self._on_zoom(-1))
            dpg.add_button(label="+", width=30, callback=lambda: self._on_zoom(1))

    def update(self):
        """Update display."""
        # Update time display
        if self._time_text_tag:
            current = format_time(self.project.playhead)
            total = format_time(self.project.duration)
            dpg.set_value(self._time_text_tag, f"{current} / {total}")

        # Update play button
        if self._play_button_tag:
            label = "||" if self.project.is_playing else ">"
            dpg.configure_item(self._play_button_tag, label=label)

        # Update BPM input (only if value differs to avoid interrupting user input)
        if self._bpm_input_tag:
            current_value = dpg.get_value(self._bpm_input_tag)
            if abs(current_value - self.project.bpm) > 0.05:
                dpg.set_value(self._bpm_input_tag, self.project.bpm)

        # Update title input (only if value differs)
        if self._title_input_tag:
            current_value = dpg.get_value(self._title_input_tag)
            if current_value != self.project.beatmap.meta.title:
                dpg.set_value(self._title_input_tag, self.project.beatmap.meta.title)

        # Update category input (only if value differs)
        if self._category_input_tag:
            current_value = dpg.get_value(self._category_input_tag)
            if current_value != self.project.beatmap.meta.category:
                dpg.set_value(
                    self._category_input_tag, self.project.beatmap.meta.category
                )

        # Update priority input (only if value differs)
        if self._priority_input_tag:
            current_value = dpg.get_value(self._priority_input_tag)
            if current_value != int(self.project.beatmap.meta.priority):
                dpg.set_value(self._priority_input_tag, int(self.project.beatmap.meta.priority))

    def _on_play_pause(self):
        """Handle play/pause button."""
        if self.project.is_playing:
            self.audio_player.pause()
            self.project.is_playing = False
            if self.on_pause:
                self.on_pause()
        else:
            self.audio_player.play(self.project.playhead)
            self.project.is_playing = True
            if self.on_play:
                self.on_play()
        self.update()

    def _on_rewind(self):
        """Handle rewind button."""
        self.audio_player.seek(0.0)
        self.project.playhead = 0.0
        if self.on_seek:
            self.on_seek(0.0)
        self.update()

    def _on_forward(self):
        """Handle forward button - skip to end."""
        self.audio_player.seek(self.project.duration)
        self.project.playhead = self.project.duration
        if self.on_seek:
            self.on_seek(self.project.duration)
        self.update()

    def _on_zoom(self, direction: int):
        """Handle zoom button."""
        if self.on_zoom:
            self.on_zoom(direction)

    def _on_bpm_change(self, sender, app_data):
        """Handle BPM input change."""
        new_bpm = app_data
        if new_bpm != self.project.bpm:
            self.project.beatmap.meta.bpm = new_bpm
            self.project.beatmap.dirty = True
            if self.on_bpm_change:
                self.on_bpm_change(new_bpm)

    def _on_title_change(self, sender, app_data):
        """Handle title input change."""
        new_title = app_data
        if new_title != self.project.beatmap.meta.title:
            self.project.beatmap.meta.title = new_title
            self.project.beatmap.dirty = True
            if self.on_meta_change:
                self.on_meta_change()

    def _on_category_change(self, sender, app_data):
        """Handle category input change."""
        new_category = app_data
        if new_category != self.project.beatmap.meta.category:
            self.project.beatmap.meta.category = new_category
            self.project.beatmap.dirty = True
            if self.on_meta_change:
                self.on_meta_change()

    def _on_priority_change(self, sender, app_data):
        """Handle priority input change."""
        new_priority = int(app_data)
        if new_priority != self.project.beatmap.meta.priority:
            self.project.beatmap.meta.priority = new_priority
            self.project.beatmap.dirty = True
            if self.on_meta_change:
                self.on_meta_change()
