"""
Main application window for the beatmap editor.
Orchestrates all UI components and handles application logic.
"""

import dearpygui.dearpygui as dpg
import os
from typing import Optional

# Environment variables for default directories
ENV_AUDIO_DIR = "BEATMAP_EDITOR_AUDIO_DIR"
ENV_BEATMAP_DIR = "BEATMAP_EDITOR_BEATMAP_DIR"


def _get_default_directory(env_var: str) -> Optional[str]:
    """Get default directory from environment variable if set and valid."""
    path = os.environ.get(env_var)
    if path and os.path.isdir(path):
        return os.path.abspath(path)
    return None


from core.project import Project
from core.beatmap import Note
from core.constants import (
    LANES,
    LEVEL_NAMES,
    KEY_SPACE,
    KEY_DELETE,
    KEY_BACKSPACE,
    KEY_1,
    KEY_2,
    KEY_3,
    SUBDIVISION_SIXTEENTH,
)
from core.history import (
    AddNoteCommand,
    AddNotesCommand,
    RemoveNotesCommand,
    ChangeLevelCommand,
    ChangeLevelsCommand,
    SnapNotesCommand,
    CleanupDuplicatesCommand,
    MoveNoteCommand,
)
from audio.player import AudioPlayer
from utils.grid import generate_beat_grid, snap_to_grid
from utils.input import (
    is_modifier_down,
    is_shift_down,
    is_alt_down,
    is_text_input_focused,
)

from ui.menu import Menu
from ui.transport import Transport
from ui.stem_controls import StemControls
from ui.timeline import Timeline
from ui.preview import Preview
from ui.peak_controls import PeakControls
from ui.beat_insert_controls import BeatInsertControls


class BeatmapEditorApp:
    """
    Main beatmap editor application.
    """

    WINDOW_WIDTH = 1200
    WINDOW_HEIGHT = 800

    def __init__(self, initial_audio_file: Optional[str] = None):
        self.project = Project()
        self.audio_player = AudioPlayer()

        # UI Components
        self.menu: Optional[Menu] = None
        self.transport: Optional[Transport] = None
        self.stem_controls: Optional[StemControls] = None
        self.timeline: Optional[Timeline] = None
        self.preview: Optional[Preview] = None
        self.peak_controls: Optional[PeakControls] = None
        self.beat_insert_controls: Optional[BeatInsertControls] = None

        # File dialog state
        self._pending_file_action: Optional[str] = None

        # Clipboard for copy/paste operations
        self._clipboard: list[Note] = []

        # Initial audio file to load on startup
        self._initial_audio_file = initial_audio_file

    def run(self):
        """Run the application."""
        dpg.create_context()
        dpg.create_viewport(
            title="Beatmap Editor",
            width=self.WINDOW_WIDTH,
            height=self.WINDOW_HEIGHT,
        )

        self._setup_theme()
        self._create_ui()
        self._setup_keyboard_shortcuts()

        dpg.setup_dearpygui()
        dpg.show_viewport()

        # Load initial audio file if provided
        if self._initial_audio_file:
            self._load_audio(os.path.abspath(self._initial_audio_file))

        # Main loop
        while dpg.is_dearpygui_running():
            self._update()
            dpg.render_dearpygui_frame()

        self._cleanup()
        dpg.destroy_context()

    def _setup_theme(self):
        """Setup global theme."""
        with dpg.theme() as global_theme:
            with dpg.theme_component(dpg.mvAll):
                dpg.add_theme_style(dpg.mvStyleVar_WindowRounding, 5)
                dpg.add_theme_style(dpg.mvStyleVar_FrameRounding, 3)
                dpg.add_theme_style(dpg.mvStyleVar_WindowPadding, 8, 8)
                dpg.add_theme_color(dpg.mvThemeCol_WindowBg, (30, 30, 35, 255))
                dpg.add_theme_color(dpg.mvThemeCol_FrameBg, (45, 45, 50, 255))

        dpg.bind_theme(global_theme)

    def _create_ui(self):
        """Create the main UI layout."""
        with dpg.window(tag="main_window"):
            # Menu bar
            self.menu = Menu(self.project)
            self.menu.create("main_window")
            self._connect_menu_callbacks()

            # Top section: Preview + Peak Controls + Beat Insert + Transport (all horizontal)
            with dpg.group(horizontal=True):
                # Preview window - create inline without child_window parent override
                with dpg.child_window(
                    width=320,
                    height=280,
                    border=True,
                ):
                    dpg.add_text("Flying Strokes Preview")
                    self.preview = Preview(self.project)
                    self.preview._drawlist_tag = dpg.add_drawlist(
                        width=300,
                        height=155,
                    )

                    dpg.add_separator()

                    # Level filter (radio buttons)
                    with dpg.group(horizontal=True):
                        dpg.add_text("Level:")
                        self.preview._level_radio_tag = dpg.add_radio_button(
                            items=["Easy", "Medium", "Hard"],
                            default_value="Hard",
                            horizontal=True,
                            callback=self.preview._on_level_change,
                        )

                    # Lane filters (checkboxes)
                    with dpg.group(horizontal=True):
                        dpg.add_text("Lanes:")
                        for lane in LANES:
                            tag = dpg.add_checkbox(
                                label=lane.capitalize()[:3],
                                default_value=True,
                                callback=self.preview._on_lane_toggle,
                                user_data=lane,
                            )
                            self.preview._lane_checkbox_tags[lane] = tag

                # Peak controls - create inline without child_window parent override
                with dpg.child_window(
                    width=320,
                    height=280,
                    border=True,
                ):
                    self.peak_controls = PeakControls(self.project)
                    self.peak_controls._create_controls_inline()
                    self._connect_peak_controls_callbacks()

                # Beat Insert controls - create inline without child_window parent override
                with dpg.child_window(
                    width=200,
                    height=280,
                    border=True,
                ):
                    self.beat_insert_controls = BeatInsertControls(self.project)
                    self.beat_insert_controls._create_controls_inline()
                    self._connect_beat_insert_callbacks()

                # Transport and stem controls
                with dpg.group():
                    dpg.add_spacer(height=10)

                    # Transport controls
                    self.transport = Transport(self.project, self.audio_player)
                    self.transport.create("main_window")
                    self._connect_transport_callbacks()

                    dpg.add_spacer(height=10)
                    dpg.add_separator()
                    dpg.add_spacer(height=10)

                    # Stem controls
                    self.stem_controls = StemControls(self.project, self.audio_player)
                    self.stem_controls.create("main_window")

            dpg.add_spacer(height=5)

            # Timeline
            self.timeline = Timeline(self.project)
            self.timeline.create("main_window")
            self.timeline.peak_controls = self.peak_controls  # Link peak controls
            self._connect_timeline_callbacks()

        dpg.set_primary_window("main_window", True)

        # Create file dialogs
        self._create_file_dialogs()

    def _create_file_dialogs(self):
        """Create file dialog components."""
        # Get default directories from environment variables
        audio_default_dir = _get_default_directory(ENV_AUDIO_DIR)
        beatmap_default_dir = _get_default_directory(ENV_BEATMAP_DIR)

        # Audio file dialog
        audio_dialog_kwargs = {
            "tag": "audio_file_dialog",
            "directory_selector": False,
            "show": False,
            "callback": self._on_file_selected,
            "width": 700,
            "height": 400,
        }
        if audio_default_dir:
            audio_dialog_kwargs["default_path"] = audio_default_dir

        with dpg.file_dialog(**audio_dialog_kwargs):
            dpg.add_file_extension(".mp3", color=(0, 255, 0, 255))
            dpg.add_file_extension(".wav", color=(0, 255, 255, 255))
            dpg.add_file_extension(".ogg", color=(255, 255, 0, 255))
            dpg.add_file_extension(".flac", color=(255, 128, 0, 255))

        # Beatmap file dialog (open)
        beatmap_open_kwargs = {
            "tag": "beatmap_open_dialog",
            "directory_selector": False,
            "show": False,
            "callback": self._on_file_selected,
            "width": 700,
            "height": 400,
        }
        if beatmap_default_dir:
            beatmap_open_kwargs["default_path"] = beatmap_default_dir

        with dpg.file_dialog(**beatmap_open_kwargs):
            dpg.add_file_extension(".json", color=(0, 255, 0, 255))

        # Beatmap file dialog (save)
        beatmap_save_kwargs = {
            "tag": "beatmap_save_dialog",
            "directory_selector": False,
            "show": False,
            "callback": self._on_file_selected,
            "default_filename": "beatmap",
            "width": 700,
            "height": 400,
        }
        if beatmap_default_dir:
            beatmap_save_kwargs["default_path"] = beatmap_default_dir

        with dpg.file_dialog(**beatmap_save_kwargs):
            dpg.add_file_extension(".json", color=(0, 255, 0, 255))

    def _connect_menu_callbacks(self):
        """Connect menu callbacks."""
        self.menu.on_new = self._on_new
        self.menu.on_open_audio = self._on_open_audio
        self.menu.on_open_beatmap = self._on_open_beatmap
        self.menu.on_save = self._on_save
        self.menu.on_save_as = self._on_save_as
        self.menu.on_undo = self._on_undo
        self.menu.on_redo = self._on_redo
        self.menu.on_copy = self._on_copy
        self.menu.on_paste = self._on_paste
        self.menu.on_duplicate = self._on_duplicate
        self.menu.on_delete = self._on_delete_selected
        self.menu.on_snap_selection = self._on_snap_selection
        self.menu.on_cleanup_duplicates = self._on_cleanup_duplicates
        self.menu.on_select_all = self._on_select_all
        self.menu.on_deselect_all = self._on_deselect_all
        self.menu.on_select_by_track = self._on_select_by_track
        self.menu.on_select_by_level = self._on_select_by_level
        self.menu.on_select_by_track_and_level = self._on_select_by_track_and_level
        self.menu.on_select_every_nth = self._on_select_every_nth
        self.menu.on_set_level = self._set_selected_level
        self.menu.on_move_to_playhead = self._on_move_to_playhead

    def _connect_transport_callbacks(self):
        """Connect transport callbacks."""
        self.transport.on_play = lambda: self._set_status("Playing...")
        self.transport.on_pause = lambda: self._set_status("Paused")
        self.transport.on_seek = lambda t: self._set_status(f"Seeked to {t:.2f}s")
        self.transport.on_zoom = self._on_zoom
        self.transport.on_bpm_change = self._on_bpm_change

    def _connect_timeline_callbacks(self):
        """Connect timeline callbacks."""
        self.timeline.on_marker_click = self._on_marker_click
        self.timeline.on_marker_double_click = self._on_marker_double_click
        self.timeline.on_add_marker = self._on_add_marker
        self.timeline.on_playhead_click = self._on_playhead_click

    def _connect_peak_controls_callbacks(self):
        """Connect peak controls callbacks."""
        self.peak_controls.on_peaks_changed = self._on_peaks_changed
        self.peak_controls.on_add_markers = self._on_add_markers_from_peaks

    def _connect_beat_insert_callbacks(self):
        """Connect beat insert controls callbacks."""
        self.beat_insert_controls.on_insert_beat_markers = self._on_insert_beat_markers

    def _setup_keyboard_shortcuts(self):
        """Setup keyboard shortcut handlers."""
        with dpg.handler_registry():
            dpg.add_key_press_handler(key=KEY_SPACE, callback=self._on_space)
            dpg.add_key_press_handler(key=KEY_DELETE, callback=self._on_delete_selected)
            dpg.add_key_press_handler(
                key=KEY_BACKSPACE, callback=self._on_delete_selected
            )
            dpg.add_key_press_handler(
                key=KEY_1, callback=lambda s, a: self._set_selected_level(1)
            )
            dpg.add_key_press_handler(
                key=KEY_2, callback=lambda s, a: self._set_selected_level(2)
            )
            dpg.add_key_press_handler(
                key=KEY_3, callback=lambda s, a: self._set_selected_level(3)
            )
            # Cmd/Ctrl+Z for undo, Cmd/Ctrl+Shift+Z for redo
            # Note: On QWERTZ keyboards (German, etc.), Y and Z are physically swapped,
            # so we register both keys to handle both keyboard layouts
            dpg.add_key_press_handler(key=dpg.mvKey_Z, callback=self._on_key_z)
            dpg.add_key_press_handler(
                key=dpg.mvKey_Y,
                callback=self._on_key_z,  # Also triggers undo/redo for QWERTZ
            )
            # Cmd/Ctrl+A for select all
            dpg.add_key_press_handler(key=dpg.mvKey_A, callback=self._on_key_a)
            # Cmd/Ctrl+N for new
            dpg.add_key_press_handler(key=dpg.mvKey_N, callback=self._on_key_n)
            # Cmd/Ctrl+O for open audio
            dpg.add_key_press_handler(key=dpg.mvKey_O, callback=self._on_key_o)
            # Cmd/Ctrl+S for save, Cmd/Ctrl+Shift+S for save as
            dpg.add_key_press_handler(key=dpg.mvKey_S, callback=self._on_key_s)
            # Cmd/Ctrl+C for copy
            dpg.add_key_press_handler(key=dpg.mvKey_C, callback=self._on_key_c)
            # Cmd/Ctrl+V for paste
            dpg.add_key_press_handler(key=dpg.mvKey_V, callback=self._on_key_v)
            # Cmd/Ctrl+D for duplicate
            dpg.add_key_press_handler(key=dpg.mvKey_D, callback=self._on_key_d)
            # Option+C for move to playhead
            dpg.add_key_press_handler(key=dpg.mvKey_C, callback=self._on_key_c_alt)
            # I for insert marker at playhead
            dpg.add_key_press_handler(key=dpg.mvKey_I, callback=self._on_key_i)
            # Mouse wheel for zoom
            dpg.add_mouse_wheel_handler(callback=self._on_mouse_wheel)

    def _on_key_z(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+Z for undo, Cmd/Ctrl+Shift+Z for redo."""
        if is_modifier_down():
            if is_shift_down():
                self._on_redo()
            else:
                self._on_undo()

    def _on_key_a(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+A for select all."""
        if is_modifier_down():
            self._on_select_all()

    def _on_key_n(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+N for new project."""
        if is_modifier_down():
            self._on_new()

    def _on_key_o(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+O for open audio."""
        if is_modifier_down():
            self._on_open_audio()

    def _on_key_s(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+S for save, Cmd/Ctrl+Shift+S for save as."""
        if is_modifier_down():
            if is_shift_down():
                self._on_save_as()
            else:
                self._on_save()

    def _on_key_c(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+C for copy."""
        if is_modifier_down():
            self._on_copy()

    def _on_key_c_alt(self, sender=None, app_data=None):
        """Handle Option+C for move to playhead."""
        if is_alt_down() and not is_modifier_down():
            self._on_move_to_playhead()

    def _on_key_v(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+V for paste."""
        if is_modifier_down():
            self._on_paste()

    def _on_key_d(self, sender=None, app_data=None):
        """Handle Cmd/Ctrl+D for duplicate."""
        if is_modifier_down():
            self._on_duplicate()

    def _on_key_i(self, sender=None, app_data=None):
        """Handle I key for inserting a marker at the playhead position."""
        # Skip if user is typing in a text input or if modifier keys are pressed
        if is_text_input_focused() or is_modifier_down():
            return
        self._on_insert_marker_at_playhead()

    def _update(self):
        """Main update loop."""
        # Update audio playback position
        if self.project.is_playing:
            self.project.playhead = self.audio_player.update()

        # Update UI components
        if self.transport:
            self.transport.update()
        if self.timeline:
            self.timeline.update()
        if self.preview:
            self.preview.update()

    def _cleanup(self):
        """Cleanup resources."""
        self.audio_player.cleanup()
        self.project.cleanup()

    # =========================================================================
    # Menu Handlers
    # =========================================================================

    def _on_new(self):
        """Handle new project."""
        if self.project.is_dirty:
            # TODO: Show confirmation dialog
            pass
        self.project.new_project()
        self._set_status("New project created")
        self._update_all()

    def _on_open_audio(self):
        """Handle open audio file."""
        self._pending_file_action = "open_audio"
        dpg.show_item("audio_file_dialog")

    def _on_open_beatmap(self):
        """Handle open beatmap file."""
        self._pending_file_action = "open_beatmap"
        dpg.show_item("beatmap_open_dialog")

    def _on_save(self):
        """Handle save."""
        if self.project.beatmap_path:
            self.project.save_beatmap()
            self._set_status(f"Saved to {os.path.basename(self.project.beatmap_path)}")
        else:
            self._on_save_as()

    def _on_save_as(self):
        """Handle save as."""
        self._pending_file_action = "save_beatmap"
        dpg.show_item("beatmap_save_dialog")

    def _on_file_selected(self, sender, app_data):
        """Handle file dialog selection."""
        if not app_data or "file_path_name" not in app_data:
            return

        file_path = app_data["file_path_name"]
        action = self._pending_file_action
        self._pending_file_action = None

        if action == "open_audio":
            self._load_audio(file_path)
        elif action == "open_beatmap":
            self._load_beatmap(file_path)
        elif action == "save_beatmap":
            self._save_beatmap(file_path)

    def _load_audio(self, file_path: str):
        """Load an audio file."""
        self._set_status(f"Loading {os.path.basename(file_path)}...")

        try:
            # Load audio
            bpm, duration = self.project.load_audio(file_path)
            self.audio_player.load_main(file_path)

            self._set_status(
                f"Loaded audio: {bpm:.1f} BPM, {duration:.1f}s. Separating stems..."
            )

            # Separate stems
            stems = self.project.separate_stems(progress_callback=self._set_status)

            # Load stems into audio player
            self.audio_player.load_all_stems(stems.as_dict())

            self._set_status(
                f"Ready. {bpm:.1f} BPM, {duration:.1f}s. Use Peak Highlight to detect and add markers."
            )

        except Exception as e:
            self._set_status(f"Error: {e}")

        self._update_all()

    def _load_beatmap(self, file_path: str):
        """Load a beatmap file."""
        try:
            self.project.load_beatmap(file_path)
            self._set_status(f"Loaded beatmap: {len(self.project.beatmap)} notes")
        except Exception as e:
            self._set_status(f"Error loading beatmap: {e}")

        self._update_all()

    def _save_beatmap(self, file_path: str):
        """Save beatmap to file."""
        try:
            self.project.save_beatmap(file_path)
            self._set_status(f"Saved to {os.path.basename(file_path)}")
        except Exception as e:
            self._set_status(f"Error saving: {e}")

    def _on_undo(self):
        """Handle undo."""
        desc = self.project.history.undo()
        if desc:
            self._set_status(f"Undo: {desc}")
            # Force timeline redraw for level changes etc.
            if self.timeline:
                self.timeline.mark_dirty()
            self._update_all()

    def _on_redo(self):
        """Handle redo."""
        desc = self.project.history.redo()
        if desc:
            self._set_status(f"Redo: {desc}")
            # Force timeline redraw for level changes etc.
            if self.timeline:
                self.timeline.mark_dirty()
            self._update_all()

    def _on_delete_selected(self, sender=None, app_data=None):
        """Delete selected markers."""
        # Skip if user is typing in a text input (let them use backspace/delete normally)
        if is_text_input_focused():
            return
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            return

        cmd = RemoveNotesCommand(self.project.beatmap, selected)
        self.project.history.execute(cmd)
        self._set_status(f"Deleted {len(selected)} marker(s)")
        self._update_all()

    def _on_snap_selection(self, subdivision: int):
        """Snap selected markers to the nearest beat position at the given subdivision.

        Args:
            subdivision: Number of subdivisions per beat (1=whole, 2=half, 4=quarter, etc.)
        """
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            self._set_status("No markers selected to snap")
            return

        if self.project.bpm <= 0:
            self._set_status("No BPM set - cannot snap to beat")
            return

        # Generate grid at the requested subdivision
        grid = generate_beat_grid(self.project.bpm, self.project.duration, subdivision)

        if len(grid) == 0:
            self._set_status("No grid positions available")
            return

        # Calculate new times for each selected note
        new_times = []
        moved_count = 0
        for note in selected:
            new_time = snap_to_grid(note.time, grid)
            new_times.append(new_time)
            if abs(new_time - note.time) > 0.001:  # Threshold for "moved"
                moved_count += 1

        if moved_count == 0:
            self._set_status("All selected markers already on grid")
            return

        # Create and execute the command
        cmd = SnapNotesCommand(self.project.beatmap, selected, new_times)
        self.project.history.execute(cmd)

        # Create subdivision label
        if subdivision == 1:
            sub_label = "whole beat"
        elif subdivision == 2:
            sub_label = "1/2 beat"
        else:
            sub_label = f"1/{subdivision} beat"

        self._set_status(f"Snapped {moved_count} marker(s) to {sub_label}")
        self._update_all()

    def _on_cleanup_duplicates(self):
        """Remove beat markers that occur at the same time (duplicates).

        When multiple markers have the same time:
        - Keep the one with the lower level (easier difficulty)
        - If levels are the same, keep the first one
        """
        notes = self.project.beatmap.notes
        if not notes:
            self._set_status("No markers to clean up")
            return

        # Group notes by time (rounded to avoid floating point issues)
        from collections import defaultdict

        time_groups: dict[float, list] = defaultdict(list)

        for note in notes:
            rounded_time = round(note.time, 3)
            time_groups[rounded_time].append(note)

        # Find duplicates to remove
        notes_to_remove = []
        for time, group in time_groups.items():
            if len(group) > 1:
                # Sort by level (ascending), then by original order
                # Keep the first one (lowest level), mark rest for removal
                group_sorted = sorted(group, key=lambda n: n.level)
                notes_to_remove.extend(group_sorted[1:])  # Remove all but the first

        if not notes_to_remove:
            self._set_status("No duplicate markers found")
            return

        # Create and execute the command
        cmd = CleanupDuplicatesCommand(self.project.beatmap, notes_to_remove)
        self.project.history.execute(cmd)

        self._set_status(f"Cleaned up {len(notes_to_remove)} duplicate marker(s)")
        self._update_all()

    def _on_select_all(self):
        """Select all markers."""
        for note in self.project.beatmap.notes:
            note.selected = True
        self._set_status(f"Selected {len(self.project.beatmap)} marker(s)")
        self._update_all()

    def _on_deselect_all(self):
        """Deselect all markers."""
        self.project.beatmap.clear_selection()
        self._set_status("Deselected all markers")
        self._update_all()

    def _on_select_by_track(self, track: str):
        """Select all markers in a specific track."""
        count = 0
        for note in self.project.beatmap.notes:
            if note.type == track:
                note.selected = True
                count += 1
        self._set_status(f"Selected {count} marker(s) in {track} track")
        self._update_all()

    def _on_select_by_level(self, level: int):
        """Select all markers at a specific level."""
        count = 0
        for note in self.project.beatmap.notes:
            if note.level == level:
                note.selected = True
                count += 1
        self._set_status(
            f"Selected {count} marker(s) at level {level} ({LEVEL_NAMES[level]})"
        )
        self._update_all()

    def _on_select_by_track_and_level(self, track: str, level: int):
        """Select all markers matching both track and level."""
        count = 0
        for note in self.project.beatmap.notes:
            if note.type == track and note.level == level:
                note.selected = True
                count += 1
        self._set_status(
            f"Selected {count} marker(s) in {track} at level {level} ({LEVEL_NAMES[level]})"
        )
        self._update_all()

    def _on_select_every_nth(self, n: int, lane: str):
        """Select every Nth marker after the cursor position in a lane.

        Args:
            n: Select every Nth marker (1 = every marker, 2 = every other, etc.)
            lane: Lane name (capitalized) or "All Lanes"
        """
        playhead_time = self.project.playhead

        # Get markers after cursor, optionally filtered by lane
        if lane == "All Lanes":
            markers_after_cursor = [
                note
                for note in self.project.beatmap.notes
                if note.time >= playhead_time
            ]
            lane_desc = "all lanes"
        else:
            # Convert capitalized lane name back to lowercase
            lane_lower = lane.lower()
            markers_after_cursor = [
                note
                for note in self.project.beatmap.notes
                if note.time >= playhead_time and note.type == lane_lower
            ]
            lane_desc = f"{lane} lane"

        # Sort by time to ensure proper ordering
        markers_after_cursor.sort(key=lambda note: note.time)

        # Select every Nth marker
        count = 0
        for i, note in enumerate(markers_after_cursor):
            if i % n == 0:  # Select 1st, (n+1)th, (2n+1)th, etc.
                note.selected = True
                count += 1

        if n == 1:
            self._set_status(f"Selected {count} marker(s) in {lane_desc}")
        else:
            self._set_status(
                f"Selected every {n}th marker ({count} total) in {lane_desc}"
            )
        self._update_all()

    def _on_copy(self):
        """Copy selected markers to clipboard."""
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            self._set_status("No markers selected to copy")
            return

        # Store copies of selected notes, sorted by time
        # We store the time relative to the earliest selected note
        selected_sorted = sorted(selected, key=lambda n: n.time)
        base_time = selected_sorted[0].time

        self._clipboard = []
        for note in selected_sorted:
            copy = note.copy()
            # Store relative time offset from the first note
            copy.time = note.time - base_time
            self._clipboard.append(copy)

        self._set_status(f"Copied {len(self._clipboard)} marker(s)")

    def _on_paste(self, move_playhead_after: bool = False):
        """Paste markers from clipboard at playhead position.

        Args:
            move_playhead_after: If True, move playhead to after the pasted selection
                                 (useful for repeated duplication)
        """
        if not self._clipboard:
            self._set_status("Clipboard is empty")
            return

        playhead = self.project.playhead

        # Create new notes at playhead position + relative offsets
        notes_to_add = []
        for clipboard_note in self._clipboard:
            new_note = clipboard_note.copy()
            new_note.time = round(playhead + clipboard_note.time, 3)
            # Clamp to valid range
            new_note.time = max(0, min(new_note.time, self.project.duration))
            notes_to_add.append(new_note)

        if notes_to_add:
            cmd = AddNotesCommand(self.project.beatmap, notes_to_add)
            self.project.history.execute(cmd)

            # Clear selection and select pasted notes
            self.project.beatmap.clear_selection()
            for note in notes_to_add:
                note.selected = True

            # Move playhead to end of pasted selection if requested
            if move_playhead_after and self._clipboard:
                # Calculate the duration of the clipboard selection
                # (time from first to last note in clipboard)
                clipboard_duration = self._clipboard[
                    -1
                ].time  # Already relative to first note
                # Move playhead to just after the last pasted note
                new_playhead = playhead + clipboard_duration
                # Clamp to valid range
                self.project.playhead = max(0, min(new_playhead, self.project.duration))

            self._set_status(f"Pasted {len(notes_to_add)} marker(s) at playhead")
            self._update_all()

    def _on_duplicate(self):
        """Duplicate selected markers (copy + paste at playhead, then move playhead after with offset)."""
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            self._set_status("No markers selected to duplicate")
            return

        # Calculate positions before any changes
        selected_sorted = sorted(selected, key=lambda n: n.time)
        first_note_time = selected_sorted[0].time
        last_note_time = selected_sorted[-1].time
        playhead_before = self.project.playhead

        # The offset from the last note to the playhead - this is what we want to preserve
        offset_from_last = playhead_before - last_note_time

        # Copy then paste
        self._on_copy()
        self._on_paste(
            move_playhead_after=False
        )  # Don't auto-move, we'll do it manually

        # The new notes are pasted starting at playhead_before
        # So the new last note is at: playhead_before + (last_note_time - first_note_time)
        new_last_note_time = playhead_before + (last_note_time - first_note_time)

        # Move playhead to maintain the same offset from the new last note
        new_playhead = new_last_note_time + offset_from_last
        # Clamp to valid range
        self.project.playhead = max(0, min(new_playhead, self.project.duration))

    def _on_move_to_playhead(self):
        """Move a single selected marker to the current playhead position."""
        selected = self.project.beatmap.get_selected_notes()
        if len(selected) != 1:
            if len(selected) == 0:
                self._set_status("No marker selected")
            else:
                self._set_status("Can only move one marker at a time")
            return

        note = selected[0]
        new_time = round(self.project.playhead, 3)

        if abs(note.time - new_time) < 0.001:
            self._set_status("Marker already at playhead position")
            return

        cmd = MoveNoteCommand(self.project.beatmap, note, new_time)
        self.project.history.execute(cmd)
        self._set_status(f"Moved marker to {new_time:.3f}s")
        # Mark timeline dirty since note position changed (count stays the same)
        if self.timeline:
            self.timeline.mark_dirty()
        self._update_all()

    def _on_peaks_changed(self):
        """Handle peak detection settings change."""
        self._update_all()

    def _on_add_markers_from_peaks(
        self,
        waveform_key: str,
        peak_times: list[float],
        after_playhead_only: bool = False,
    ):
        """Add markers at detected peak positions."""
        from utils.peaks import waveform_to_lane_key

        if not peak_times:
            self._set_status("No peaks to add")
            return

        # Map waveform key to lane type
        lane_type = waveform_to_lane_key(waveform_key)

        # Filter peaks to only those after playhead if requested
        if after_playhead_only:
            playhead = self.project.playhead
            peak_times = [t for t in peak_times if t > playhead]
            if not peak_times:
                self._set_status("No peaks after playhead")
                return

        # Snap peaks to grid and create markers
        grid = generate_beat_grid(
            self.project.bpm, self.project.duration, SUBDIVISION_SIXTEENTH
        )

        # Clear selection first
        self.project.beatmap.clear_selection()

        existing_times = {
            n.time for n in self.project.beatmap.notes if n.type == lane_type
        }
        notes_to_add = []

        for peak_time in peak_times:
            # Snap to grid
            snapped_time = snap_to_grid(peak_time, grid)
            snapped_time = round(snapped_time, 3)

            # Skip if marker already exists at this time for this lane
            if snapped_time in existing_times:
                continue

            # Create note with default level 1
            note = Note(time=snapped_time, level=1, type=lane_type)
            notes_to_add.append(note)
            existing_times.add(snapped_time)

        # Add all notes in a single command (for single undo)
        if notes_to_add:
            cmd = AddNotesCommand(self.project.beatmap, notes_to_add)
            self.project.history.execute(cmd)

            # Auto-select all newly added notes
            for note in notes_to_add:
                note.selected = True

        mode_str = " after playhead" if after_playhead_only else ""
        self._set_status(
            f"Added {len(notes_to_add)} markers from {len(peak_times)} peaks in {lane_type}{mode_str} (selected)"
        )
        self._update_all()

    def _on_insert_beat_markers(
        self,
        lane_type: str,
        beats_interval: float,
        level: int,
        start_from_playhead: bool = False,
    ):
        """Insert markers at regular beat intervals.

        Args:
            lane_type: Lane to insert markers into
            beats_interval: Interval in beats (e.g., 0.25 for 1/4 beat, 2.0 for every 2 beats)
            level: Marker difficulty level (1-3)
            start_from_playhead: If True, only insert markers from playhead position onwards
        """
        if self.project.bpm <= 0 or self.project.duration <= 0:
            self._set_status("No audio loaded - cannot insert beat markers")
            return

        # Generate beat grid at the specified interval
        beat_duration = 60.0 / self.project.bpm
        interval_duration = beat_duration * beats_interval

        # Determine start time
        if start_from_playhead:
            # Snap playhead to nearest grid position
            start_time = self.project.playhead
            # Align to grid
            grid_index = int(start_time / interval_duration)
            start_time = grid_index * interval_duration
            if start_time < self.project.playhead:
                start_time += interval_duration
        else:
            start_time = 0.0

        # Generate grid times
        import numpy as np

        num_markers = int(
            np.ceil((self.project.duration - start_time) / interval_duration)
        )
        grid = start_time + np.arange(num_markers) * interval_duration
        grid = grid[grid < self.project.duration]

        # Get existing marker times for this lane to avoid duplicates
        existing_times = {
            round(n.time, 3) for n in self.project.beatmap.notes if n.type == lane_type
        }

        # Clear selection first
        self.project.beatmap.clear_selection()

        notes_to_add = []

        for time in grid:
            snapped_time = round(time, 3)

            # Skip if marker already exists at this time for this lane
            if snapped_time in existing_times:
                continue

            # Create note with specified level
            note = Note(time=snapped_time, level=level, type=lane_type)
            notes_to_add.append(note)
            existing_times.add(snapped_time)

        # Add all notes in a single command (for single undo)
        if notes_to_add:
            cmd = AddNotesCommand(self.project.beatmap, notes_to_add)
            self.project.history.execute(cmd)

            # Auto-select all newly added notes
            for note in notes_to_add:
                note.selected = True

        # Format interval name for display
        if beats_interval >= 1:
            if beats_interval == int(beats_interval):
                interval_name = f"{int(beats_interval)}/1"
            else:
                interval_name = f"{beats_interval}/1"
        else:
            # Convert to fraction (0.25 -> 1/4, 0.5 -> 1/2, etc.)
            denominator = int(1 / beats_interval)
            interval_name = f"1/{denominator}"

        from_str = f" from {start_time:.2f}s" if start_from_playhead else ""
        self._set_status(
            f"Added {len(notes_to_add)} markers at {interval_name} beat intervals in {lane_type}{from_str} (level {level}, selected)"
        )
        self._update_all()

    # =========================================================================
    # Timeline Handlers
    # =========================================================================

    def _on_marker_click(self, note: Note):
        """Handle marker click."""
        self._set_status(
            f"Selected {note.type} marker at {note.time:.3f}s (Level {note.level})"
        )

    def _on_marker_double_click(self, note: Note):
        """Handle marker double click - cycle level."""
        new_level = (note.level % 3) + 1  # 1 -> 2 -> 3 -> 1
        cmd = ChangeLevelCommand(self.project.beatmap, note, new_level)
        self.project.history.execute(cmd)
        self._set_status(f"Changed level to {new_level}")
        self._update_all()

    def _on_add_marker(self, time: float, lane_type: str):
        """Handle adding a new marker."""
        # Snap to grid
        if self.project.bpm > 0:
            grid = generate_beat_grid(
                self.project.bpm, self.project.duration, SUBDIVISION_SIXTEENTH
            )
            time = snap_to_grid(time, grid)

        # Create note with default level 1
        note = Note(time=round(time, 3), level=1, type=lane_type)
        cmd = AddNoteCommand(self.project.beatmap, note)
        self.project.history.execute(cmd)

        self._set_status(f"Added {lane_type} marker at {time:.3f}s")
        self._update_all()

    def _on_insert_marker_at_playhead(self):
        """Insert a marker at the current playhead position in the base lane."""
        # Use the base lane as default
        lane_type = "base"
        self._on_add_marker(self.project.playhead, lane_type)

    def _on_playhead_click(self, time: float):
        """Handle playhead click - seek to time."""
        self.project.playhead = time
        self.audio_player.seek(time)
        self._update_all()

    # =========================================================================
    # Keyboard Handlers
    # =========================================================================

    def _on_space(self, sender=None, app_data=None):
        """Handle spacebar - toggle play/pause."""
        # Skip if user is typing in a text input
        if is_text_input_focused():
            return
        if self.transport:
            self.transport._on_play_pause()

    def _set_selected_level(self, level: int):
        """Set level for selected markers."""
        # Skip if user is typing in a text input
        if is_text_input_focused():
            return
        selected = self.project.beatmap.get_selected_notes()
        if not selected:
            return

        cmd = ChangeLevelsCommand(self.project.beatmap, selected, level)
        self.project.history.execute(cmd)
        self._set_status(f"Set {len(selected)} marker(s) to level {level}")
        # Only update timeline for level changes (not preview/transport)
        if self.timeline:
            self.timeline.mark_dirty()
            self.timeline.update()

    def _on_zoom(self, direction: int):
        """Handle zoom from transport buttons - zoom centered on visible area."""
        if self.timeline:
            center_time = self.timeline.get_visible_center_time()
            if direction > 0:
                self.timeline.zoom_in(center_time)
            else:
                self.timeline.zoom_out(center_time)

    def _on_bpm_change(self, new_bpm: float):
        """Handle BPM change from transport controls."""
        self._set_status(f"BPM changed to {new_bpm:.1f}")
        # Force timeline to redraw with new grid
        if self.timeline:
            self.timeline.mark_dirty()
        self._update_all()

    def _on_mouse_wheel(self, sender, app_data):
        """Handle mouse wheel for zooming timeline (with Option/Alt key)."""
        # app_data is the scroll delta (positive = scroll up, negative = scroll down)
        if not self.timeline or not self.timeline._is_mouse_over_timeline():
            return

        # Only handle zoom when Option/Alt key is held
        # Native scrolling handles horizontal scroll from trackpad
        option_down = dpg.is_key_down(dpg.mvKey_Alt)

        if option_down:
            # Zoom centered on mouse cursor position
            mouse_pos = dpg.get_mouse_pos(local=False)
            local_pos = self.timeline._screen_to_local(mouse_pos)
            if local_pos:
                center_time = local_pos[0] / self.timeline.zoom
            else:
                center_time = self.timeline.get_visible_center_time()

            if app_data > 0:
                self.timeline.zoom_in(center_time)
            elif app_data < 0:
                self.timeline.zoom_out(center_time)

    # =========================================================================
    # Helpers
    # =========================================================================

    def _set_status(self, message: str):
        """Update status text (no-op, status text removed)."""
        pass  # Status text UI element removed

    def _update_all(self):
        """Force update all UI components."""
        if self.transport:
            self.transport.update()
        if self.timeline:
            self.timeline.update()
        if self.preview:
            self.preview.update()
        if self.stem_controls:
            self.stem_controls.update()
        if self.peak_controls:
            self.peak_controls.update()
        if self.beat_insert_controls:
            self.beat_insert_controls.update()
