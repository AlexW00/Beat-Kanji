"""
Stem control panel with solo/mute buttons.
"""

import dearpygui.dearpygui as dpg
from typing import TYPE_CHECKING, Optional, Callable

if TYPE_CHECKING:
    from core.project import Project
    from audio.player import AudioPlayer


STEMS = ["vocals", "drums", "bass", "other"]

# Colors (RGBA 0-255)
COLORS = {
    "solo_on": (230, 180, 50, 255),  # Yellow when solo active
    "solo_off": (100, 100, 100, 255),
    "mute_on": (230, 75, 75, 255),  # Red when muted
    "mute_off": (100, 100, 100, 255),
}


class StemControls:
    """
    Stem control panel with solo/mute buttons for each stem.
    """

    def __init__(self, project: "Project", audio_player: "AudioPlayer"):
        self.project = project
        self.audio_player = audio_player

        # Button tags
        self._solo_buttons: dict[str, int] = {}
        self._mute_buttons: dict[str, int] = {}

        # Button themes
        self._solo_on_theme: Optional[int] = None
        self._solo_off_theme: Optional[int] = None
        self._mute_on_theme: Optional[int] = None
        self._mute_off_theme: Optional[int] = None

        self._create_themes()

    def _create_themes(self):
        """Create button themes for different states."""
        with dpg.theme() as self._solo_on_theme:
            with dpg.theme_component(dpg.mvButton):
                dpg.add_theme_color(dpg.mvThemeCol_Button, COLORS["solo_on"])
                dpg.add_theme_color(dpg.mvThemeCol_ButtonHovered, (255, 200, 70, 255))
                dpg.add_theme_color(dpg.mvThemeCol_ButtonActive, (200, 150, 40, 255))

        with dpg.theme() as self._solo_off_theme:
            with dpg.theme_component(dpg.mvButton):
                dpg.add_theme_color(dpg.mvThemeCol_Button, COLORS["solo_off"])
                dpg.add_theme_color(dpg.mvThemeCol_ButtonHovered, (120, 120, 120, 255))
                dpg.add_theme_color(dpg.mvThemeCol_ButtonActive, (80, 80, 80, 255))

        with dpg.theme() as self._mute_on_theme:
            with dpg.theme_component(dpg.mvButton):
                dpg.add_theme_color(dpg.mvThemeCol_Button, COLORS["mute_on"])
                dpg.add_theme_color(dpg.mvThemeCol_ButtonHovered, (255, 100, 100, 255))
                dpg.add_theme_color(dpg.mvThemeCol_ButtonActive, (200, 50, 50, 255))

        with dpg.theme() as self._mute_off_theme:
            with dpg.theme_component(dpg.mvButton):
                dpg.add_theme_color(dpg.mvThemeCol_Button, COLORS["mute_off"])
                dpg.add_theme_color(dpg.mvThemeCol_ButtonHovered, (120, 120, 120, 255))
                dpg.add_theme_color(dpg.mvThemeCol_ButtonActive, (80, 80, 80, 255))

    def create(self, parent: int):
        """Create the stem controls panel."""
        with dpg.group(horizontal=True, parent=parent):
            dpg.add_text("Stems:")

            for stem in STEMS:
                with dpg.group(horizontal=True):
                    dpg.add_text(f"  {stem.capitalize()}:")

                    # Solo button - use user_data to pass stem name
                    self._solo_buttons[stem] = dpg.add_button(
                        label="S",
                        width=25,
                        callback=self._on_solo_callback,
                        user_data=stem,
                    )

                    # Mute button - use user_data to pass stem name
                    self._mute_buttons[stem] = dpg.add_button(
                        label="M",
                        width=25,
                        callback=self._on_mute_callback,
                        user_data=stem,
                    )

        self.update()

    def _on_solo_callback(self, sender, app_data, user_data):
        """DearPyGui callback wrapper for solo button."""
        self._on_solo(user_data)

    def _on_mute_callback(self, sender, app_data, user_data):
        """DearPyGui callback wrapper for mute button."""
        self._on_mute(user_data)

    def update(self):
        """Update button colors based on state."""
        for stem in STEMS:
            stem_state = self.project.stem_states.get(stem)
            if not stem_state:
                continue

            # Update solo button theme
            if stem in self._solo_buttons:
                theme = self._solo_on_theme if stem_state.solo else self._solo_off_theme
                dpg.bind_item_theme(self._solo_buttons[stem], theme)

            # Update mute button theme
            if stem in self._mute_buttons:
                theme = self._mute_on_theme if stem_state.mute else self._mute_off_theme
                dpg.bind_item_theme(self._mute_buttons[stem], theme)

    def _on_solo(self, stem: str):
        """Handle solo button click."""
        stem_state = self.project.stem_states.get(stem)
        if stem_state:
            stem_state.solo = not stem_state.solo
            self.audio_player.set_solo(stem, stem_state.solo)
        self.update()

    def _on_mute(self, stem: str):
        """Handle mute button click."""
        stem_state = self.project.stem_states.get(stem)
        if stem_state:
            stem_state.mute = not stem_state.mute
            self.audio_player.set_mute(stem, stem_state.mute)
        self.update()
