"""
Input utilities for keyboard and mouse handling.
Provides unified helpers for modifier key detection across platforms.
"""

import dearpygui.dearpygui as dpg
from core.constants import IS_MACOS


def is_modifier_down() -> bool:
    """
    Check if the primary modifier key is pressed.
    Returns True if Cmd is held on macOS, or Ctrl on other platforms.
    """
    if IS_MACOS:
        # macOS uses Command key (LWin/RWin in DearPyGui)
        return dpg.is_key_down(dpg.mvKey_LWin) or dpg.is_key_down(dpg.mvKey_RWin)
    return dpg.is_key_down(dpg.mvKey_LControl) or dpg.is_key_down(dpg.mvKey_RControl)


def is_ctrl_down() -> bool:
    """
    Check if the Ctrl key is pressed (regardless of platform).
    Use is_modifier_down() for platform-aware shortcut handling.
    """
    return (
        dpg.is_key_down(dpg.mvKey_Control)
        or dpg.is_key_down(dpg.mvKey_LControl)
        or dpg.is_key_down(dpg.mvKey_RControl)
    )


def is_shift_down() -> bool:
    """Check if Shift key is pressed."""
    return dpg.is_key_down(dpg.mvKey_LShift) or dpg.is_key_down(dpg.mvKey_RShift)


def is_alt_down() -> bool:
    """Check if Alt/Option key is pressed."""
    return dpg.is_key_down(dpg.mvKey_Alt)


def is_cmd_down() -> bool:
    """
    Check if the Command key is pressed (macOS only, maps to Win key).
    On non-macOS, always returns False.
    """
    if IS_MACOS:
        return dpg.is_key_down(dpg.mvKey_LWin) or dpg.is_key_down(dpg.mvKey_RWin)
    return False


# Module-level registry of text input items to check for focus
_registered_input_items: list[int] = []


def register_text_input(item_tag: int) -> None:
    """
    Register a text input widget for focus tracking.
    Call this after creating any input_text, input_int, input_float, etc.
    """
    if item_tag not in _registered_input_items:
        _registered_input_items.append(item_tag)


def unregister_text_input(item_tag: int) -> None:
    """
    Unregister a text input widget from focus tracking.
    Call this before deleting the item.
    """
    if item_tag in _registered_input_items:
        _registered_input_items.remove(item_tag)


def is_text_input_focused() -> bool:
    """
    Check if a text input widget is currently focused/active.
    Returns True if any registered input widget has keyboard focus.
    This is used to prevent keyboard shortcuts from triggering while typing.
    """
    for item_tag in _registered_input_items:
        try:
            if dpg.does_item_exist(item_tag) and dpg.is_item_active(item_tag):
                return True
        except Exception:
            continue
    return False
