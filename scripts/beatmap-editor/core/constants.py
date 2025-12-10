"""
Shared constants and configuration for the beatmap editor.
Consolidates lane mappings, colors, UI dimensions, and keyboard constants.
"""

import platform

# =============================================================================
# Platform Detection
# =============================================================================

IS_MACOS = platform.system() == "Darwin"

# =============================================================================
# Lane Configuration
# =============================================================================

# Lane names in display order
LANES = ["base", "drum", "bass", "vocal", "lead"]

# Waveform/stem names
WAVEFORMS = ["main", "drums", "bass", "vocals", "other"]

# Mapping between lane names and waveform data keys
LANE_TO_WAVEFORM = {
    "base": "main",
    "drum": "drums",
    "bass": "bass",
    "vocal": "vocals",
    "lead": "other",
}

WAVEFORM_TO_LANE = {
    "main": "base",
    "drums": "drum",
    "bass": "bass",
    "vocals": "vocal",
    "other": "lead",
}

# Track display names for UI (waveform_key -> display_name)
TRACK_DISPLAY_NAMES = {
    "main": "Main",
    "drums": "Drums",
    "bass": "Bass",
    "vocals": "Vocals",
    "other": "Other",
}

# =============================================================================
# UI Dimensions
# =============================================================================

LANE_HEIGHT = 80
LANE_SPACING = 5
HEADER_HEIGHT = 30
SCROLLBAR_HEIGHT = 18
LABEL_COLUMN_WIDTH = 60

MARKER_RADIUS = 8
MARKER_CLICK_TOLERANCE = 10  # pixels

# Grid subdivisions
SUBDIVISION_HALF = 2
SUBDIVISION_QUARTER = 4
SUBDIVISION_EIGHTH = 8
SUBDIVISION_SIXTEENTH = 16

# =============================================================================
# Colors (RGBA 0-255)
# =============================================================================

COLORS = {
    # Background colors
    "background": (26, 26, 31, 255),
    "lane_bg": (38, 38, 46, 255),
    "lane_border": (77, 77, 89, 255),
    # Grid colors
    "grid_beat": (64, 64, 77, 204),
    "grid_sub": (51, 51, 56, 128),
    # Playhead
    "playhead": (255, 77, 77, 255),
    # Waveform
    "waveform": (77, 179, 204, 179),
    # Markers by level (difficulty)
    "marker_1": (51, 204, 51, 255),  # Green - Easy
    "marker_2": (230, 204, 51, 255),  # Yellow - Medium
    "marker_3": (230, 51, 51, 255),  # Red - Hard
    "marker_selected": (255, 255, 255, 255),  # White outline
    # Peak detection
    "peak_highlight": (255, 128, 0, 200),  # Orange
    # Text
    "text": (204, 204, 204, 255),
    # Selection
    "selection_box": (100, 150, 255, 200),
    "selection_fill": (100, 150, 255, 50),
}

# Marker colors indexed by level
MARKER_COLORS = {
    1: COLORS["marker_1"],
    2: COLORS["marker_2"],
    3: COLORS["marker_3"],
}

# Level display names
LEVEL_NAMES = {
    1: "Easy",
    2: "Medium",
    3: "Hard",
}

# =============================================================================
# Keyboard Key Codes (DearPyGui raw codes for compatibility)
# =============================================================================

# These are raw key codes because mvKey_* constants may not be available
# in all DearPyGui versions
KEY_SPACE = 32
KEY_DELETE = 261
KEY_BACKSPACE = 259
KEY_1 = 49
KEY_2 = 50
KEY_3 = 51

# =============================================================================
# Default Values
# =============================================================================

DEFAULT_ZOOM = 100.0  # Pixels per second
MIN_ZOOM = 10.0
MAX_ZOOM = 500.0

DEFAULT_THRESHOLD_PERCENT = 50.0
DEFAULT_REARM_RATIO = 0.7  # Rearm threshold is 70% of main threshold
MIN_PEAK_GAP_SECONDS = 0.05

# History
MAX_HISTORY_SIZE = 100
