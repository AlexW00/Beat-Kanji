"""
Menu bar for the beatmap editor.
File operations, edit commands, etc.
"""

import dearpygui.dearpygui as dpg
import platform
from typing import TYPE_CHECKING, Optional, Callable

if TYPE_CHECKING:
    from core.project import Project

# Use Cmd on macOS, Ctrl elsewhere
MOD_KEY = "Cmd" if platform.system() == "Darwin" else "Ctrl"

# Note types for selection menu
NOTE_TYPES = ["base", "drum", "bass", "vocal", "lead"]


class Menu:
    """
    Menu bar with File, Edit, and Select menus.
    """

    def __init__(self, project: "Project"):
        self.project = project

        # Callbacks
        self.on_new: Optional[Callable[[], None]] = None
        self.on_open_audio: Optional[Callable[[], None]] = None
        self.on_open_beatmap: Optional[Callable[[], None]] = None
        self.on_save: Optional[Callable[[], None]] = None
        self.on_save_as: Optional[Callable[[], None]] = None
        self.on_undo: Optional[Callable[[], None]] = None
        self.on_redo: Optional[Callable[[], None]] = None
        self.on_copy: Optional[Callable[[], None]] = None
        self.on_paste: Optional[Callable[[], None]] = None
        self.on_duplicate: Optional[Callable[[], None]] = None
        self.on_delete: Optional[Callable[[], None]] = None
        self.on_snap_selection: Optional[Callable[[int], None]] = None
        self.on_cleanup_duplicates: Optional[Callable[[], None]] = None
        self.on_select_all: Optional[Callable[[], None]] = None
        self.on_deselect_all: Optional[Callable[[], None]] = None
        self.on_select_by_track: Optional[Callable[[str], None]] = None
        self.on_select_by_level: Optional[Callable[[int], None]] = None
        self.on_select_by_track_and_level: Optional[Callable[[str, int], None]] = None
        self.on_select_every_nth: Optional[Callable[[int, str], None]] = None
        self.on_set_level: Optional[Callable[[int], None]] = None
        self.on_move_to_playhead: Optional[Callable[[], None]] = None

    def create(self, parent: int):
        """Create the menu bar."""
        with dpg.menu_bar(parent=parent):
            # File menu
            with dpg.menu(label="File"):
                dpg.add_menu_item(
                    label="New",
                    shortcut=f"{MOD_KEY}+N",
                    callback=lambda: self._call(self.on_new),
                )
                dpg.add_separator()
                dpg.add_menu_item(
                    label="Open Audio...",
                    shortcut=f"{MOD_KEY}+O",
                    callback=lambda: self._call(self.on_open_audio),
                )
                dpg.add_menu_item(
                    label="Open Beatmap...",
                    callback=lambda: self._call(self.on_open_beatmap),
                )
                dpg.add_separator()
                dpg.add_menu_item(
                    label="Save",
                    shortcut=f"{MOD_KEY}+S",
                    callback=lambda: self._call(self.on_save),
                )
                dpg.add_menu_item(
                    label="Save As...",
                    shortcut=f"{MOD_KEY}+Shift+S",
                    callback=lambda: self._call(self.on_save_as),
                )

            # Edit menu
            with dpg.menu(label="Edit"):
                dpg.add_menu_item(
                    label="Undo",
                    shortcut=f"{MOD_KEY}+Z",
                    callback=lambda: self._call(self.on_undo),
                )
                dpg.add_menu_item(
                    label="Redo",
                    shortcut=f"{MOD_KEY}+Shift+Z",
                    callback=lambda: self._call(self.on_redo),
                )
                dpg.add_separator()
                dpg.add_menu_item(
                    label="Copy",
                    shortcut=f"{MOD_KEY}+C",
                    callback=lambda: self._call(self.on_copy),
                )
                dpg.add_menu_item(
                    label="Paste",
                    shortcut=f"{MOD_KEY}+V",
                    callback=lambda: self._call(self.on_paste),
                )
                dpg.add_menu_item(
                    label="Duplicate",
                    shortcut=f"{MOD_KEY}+D",
                    callback=lambda: self._call(self.on_duplicate),
                )
                dpg.add_menu_item(
                    label="Move to Playhead",
                    shortcut="Opt+C",
                    callback=lambda: self._call(self.on_move_to_playhead),
                )
                dpg.add_separator()
                dpg.add_menu_item(
                    label="Delete Selected",
                    shortcut="Delete",
                    callback=lambda: self._call(self.on_delete),
                )
                dpg.add_separator()

                # Set Level submenu
                with dpg.menu(label="Set Level"):
                    dpg.add_menu_item(
                        label="Level 1 (Easy)",
                        shortcut="1",
                        callback=lambda: self._call_with_arg(self.on_set_level, 1),
                    )
                    dpg.add_menu_item(
                        label="Level 2 (Medium)",
                        shortcut="2",
                        callback=lambda: self._call_with_arg(self.on_set_level, 2),
                    )
                    dpg.add_menu_item(
                        label="Level 3 (Hard)",
                        shortcut="3",
                        callback=lambda: self._call_with_arg(self.on_set_level, 3),
                    )

                dpg.add_separator()

                # Snap Selection to Beat submenu
                with dpg.menu(label="Snap Selection to Beat"):
                    dpg.add_menu_item(
                        label="1/16 (Sixteenth)",
                        callback=self._make_snap_callback(16),
                    )
                    dpg.add_menu_item(
                        label="1/8 (Eighth)",
                        callback=self._make_snap_callback(8),
                    )
                    dpg.add_menu_item(
                        label="1/4 (Quarter)",
                        callback=self._make_snap_callback(4),
                    )
                    dpg.add_menu_item(
                        label="1/2 (Half)",
                        callback=self._make_snap_callback(2),
                    )
                    dpg.add_menu_item(
                        label="1 (Whole Beat)",
                        callback=self._make_snap_callback(1),
                    )

                dpg.add_menu_item(
                    label="Clean Up Beat Markers",
                    callback=lambda: self._call(self.on_cleanup_duplicates),
                )

            # Select menu
            with dpg.menu(label="Select"):
                dpg.add_menu_item(
                    label="Select All",
                    shortcut=f"{MOD_KEY}+A",
                    callback=lambda s, a: self._call(self.on_select_all),
                )
                dpg.add_menu_item(
                    label="Deselect All",
                    callback=lambda s, a: self._call(self.on_deselect_all),
                )
                dpg.add_separator()

                # Select by Track submenu
                with dpg.menu(label="Select by Track"):
                    for track in NOTE_TYPES:
                        dpg.add_menu_item(
                            label=track.capitalize(),
                            callback=self._make_track_callback(track),
                        )

                # Select by Level submenu
                with dpg.menu(label="Select by Level"):
                    dpg.add_menu_item(
                        label="Level 1 (Easy)",
                        callback=self._make_level_callback(1),
                    )
                    dpg.add_menu_item(
                        label="Level 2 (Medium)",
                        callback=self._make_level_callback(2),
                    )
                    dpg.add_menu_item(
                        label="Level 3 (Hard)",
                        callback=self._make_level_callback(3),
                    )

                dpg.add_separator()

                # Select by Track and Level submenu
                with dpg.menu(label="Select by Track & Level"):
                    for track in NOTE_TYPES:
                        with dpg.menu(label=track.capitalize()):
                            for level in [1, 2, 3]:
                                level_name = {1: "Easy", 2: "Medium", 3: "Hard"}[level]
                                dpg.add_menu_item(
                                    label=f"Level {level} ({level_name})",
                                    callback=self._make_track_level_callback(
                                        track, level
                                    ),
                                )

                dpg.add_separator()

                # Select Every Nth After Cursor
                dpg.add_menu_item(
                    label="Select Every Nth After Cursor...",
                    callback=lambda s, a: self._show_select_every_nth_dialog(),
                )

            # Help menu
            with dpg.menu(label="Help"):
                dpg.add_menu_item(
                    label="Keyboard Shortcuts",
                    callback=self._show_shortcuts,
                )
                dpg.add_menu_item(
                    label="About",
                    callback=self._show_about,
                )

    def _call(self, callback: Optional[Callable]):
        """Safely call a callback."""
        if callback:
            callback()

    def _call_with_arg(self, callback: Optional[Callable], arg):
        """Safely call a callback with one argument."""
        if callback:
            callback(arg)

    def _call_with_two_args(self, callback: Optional[Callable], arg1, arg2):
        """Safely call a callback with two arguments."""
        if callback:
            callback(arg1, arg2)

    def _make_track_callback(self, track: str):
        """Create a callback for selecting by track (captures track value)."""

        def callback(sender, app_data):
            self._call_with_arg(self.on_select_by_track, track)

        return callback

    def _make_level_callback(self, level: int):
        """Create a callback for selecting by level (captures level value)."""

        def callback(sender, app_data):
            self._call_with_arg(self.on_select_by_level, level)

        return callback

    def _make_track_level_callback(self, track: str, level: int):
        """Create a callback for selecting by track and level (captures both values)."""

        def callback(sender, app_data):
            self._call_with_two_args(self.on_select_by_track_and_level, track, level)

        return callback

    def _make_snap_callback(self, subdivision: int):
        """Create a callback for snapping selection to a beat subdivision."""

        def callback(sender, app_data):
            self._call_with_arg(self.on_snap_selection, subdivision)

        return callback

    def _show_shortcuts(self):
        """Show keyboard shortcuts dialog."""
        with dpg.window(
            label="Keyboard Shortcuts",
            modal=True,
            width=400,
            height=450,
            pos=(200, 100),
        ):
            dpg.add_text("Playback")
            dpg.add_text("  Space         - Play/Pause")
            dpg.add_separator()
            dpg.add_text("File")
            dpg.add_text(f"  {MOD_KEY}+N        - New Project")
            dpg.add_text(f"  {MOD_KEY}+O        - Open Audio")
            dpg.add_text(f"  {MOD_KEY}+S        - Save Beatmap")
            dpg.add_text(f"  {MOD_KEY}+Shift+S  - Save As")
            dpg.add_separator()
            dpg.add_text("Edit")
            dpg.add_text(f"  {MOD_KEY}+Z        - Undo")
            dpg.add_text(f"  {MOD_KEY}+Shift+Z  - Redo")
            dpg.add_text(f"  {MOD_KEY}+C        - Copy Selected")
            dpg.add_text(f"  {MOD_KEY}+V        - Paste at Playhead")
            dpg.add_text(f"  {MOD_KEY}+D        - Duplicate Selected")
            dpg.add_text("  Delete        - Delete Selected")
            dpg.add_text("  1/2/3         - Set Level for Selected")
            dpg.add_separator()
            dpg.add_text("Select")
            dpg.add_text(f"  {MOD_KEY}+A        - Select All")
            dpg.add_text("  (Use Select menu for track/level/Nth selection)")
            dpg.add_separator()
            dpg.add_text("Markers")
            dpg.add_text("  Double-Click  - Add Marker / Cycle Level")
            dpg.add_text("  Click         - Select Marker")
            dpg.add_text(f"  {MOD_KEY}+Click    - Multi-Select")
            dpg.add_separator()
            dpg.add_button(
                label="Close",
                callback=lambda: dpg.delete_item(dpg.get_item_parent(dpg.last_item())),
            )

    def _show_select_every_nth_dialog(self):
        """Show dialog for selecting every Nth marker after cursor in a lane."""
        dialog_tag = dpg.generate_uuid()

        def on_apply():
            n_value = int(dpg.get_value(n_input_tag))
            lane = dpg.get_value(lane_combo_tag)
            if n_value >= 1 and self.on_select_every_nth:
                self.on_select_every_nth(n_value, lane)
            dpg.delete_item(dialog_tag)

        def on_cancel():
            dpg.delete_item(dialog_tag)

        with dpg.window(
            label="Select Every Nth After Cursor",
            modal=True,
            width=320,
            height=180,
            pos=(250, 150),
            tag=dialog_tag,
        ):
            dpg.add_text("Select every Nth beat marker after the cursor")
            dpg.add_text("position in the specified lane.")
            dpg.add_spacer(height=10)

            with dpg.group(horizontal=True):
                dpg.add_text("Every")
                n_input_tag = dpg.add_input_int(
                    default_value=2,
                    min_value=1,
                    max_value=100,
                    min_clamped=True,
                    max_clamped=True,
                    width=80,
                )
                dpg.add_text("marker(s)")

            with dpg.group(horizontal=True):
                dpg.add_text("Lane:")
                lane_combo_tag = dpg.add_combo(
                    items=["All Lanes"] + [t.capitalize() for t in NOTE_TYPES],
                    default_value="All Lanes",
                    width=150,
                )

            dpg.add_spacer(height=10)

            with dpg.group(horizontal=True):
                dpg.add_button(label="Select", callback=on_apply, width=100)
                dpg.add_button(label="Cancel", callback=on_cancel, width=100)

    def _show_about(self):
        """Show about dialog."""
        with dpg.window(
            label="About",
            modal=True,
            width=300,
            height=150,
            pos=(250, 150),
        ):
            dpg.add_text("Beatmap Editor")
            dpg.add_text("Version 1.0")
            dpg.add_spacer(height=10)
            dpg.add_text("A semi-automated beatmap creation tool")
            dpg.add_text("for Beat Kanji rhythm game.")
            dpg.add_spacer(height=10)
            dpg.add_button(
                label="Close",
                callback=lambda: dpg.delete_item(dpg.get_item_parent(dpg.last_item())),
            )
