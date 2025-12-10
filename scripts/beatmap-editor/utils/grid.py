"""
Grid utilities for beatmap editor.
Provides beat grid generation and snap-to-grid functionality.
"""

import numpy as np
from typing import Union

from core.constants import (
    SUBDIVISION_HALF,
    SUBDIVISION_QUARTER,
    SUBDIVISION_EIGHTH,
    SUBDIVISION_SIXTEENTH,
)


def generate_beat_grid(
    bpm: float, duration: float, subdivision: int = SUBDIVISION_SIXTEENTH
) -> np.ndarray:
    """
    Generate a precise beat grid at the specified subdivision.

    Args:
        bpm: Beats per minute
        duration: Total duration in seconds
        subdivision: Subdivisions per beat (2=half, 4=quarter, 8=eighth, 16=sixteenth)

    Returns:
        NumPy array of grid timestamps
    """
    beat_duration = 60.0 / bpm
    subdivision_duration = beat_duration / subdivision

    num_subdivisions = int(np.ceil(duration / subdivision_duration))
    grid = np.arange(num_subdivisions) * subdivision_duration

    # Filter to only include times within duration
    grid = grid[grid < duration]
    return grid


def snap_to_grid(time: float, grid: np.ndarray) -> float:
    """
    Snap a time to the nearest grid position.

    Args:
        time: Original time in seconds
        grid: Array of valid grid timestamps

    Returns:
        Snapped time (nearest grid point)
    """
    if len(grid) == 0:
        return time
    idx = np.argmin(np.abs(grid - time))
    return float(grid[idx])


def time_to_grid_index(
    time: float, bpm: float, subdivision: int = SUBDIVISION_SIXTEENTH
) -> int:
    """
    Convert a time to the nearest grid index.

    Args:
        time: Time in seconds
        bpm: Beats per minute
        subdivision: Grid subdivision

    Returns:
        Grid index (0-based)
    """
    beat_duration = 60.0 / bpm
    subdivision_duration = beat_duration / subdivision
    return int(round(time / subdivision_duration))


def grid_index_to_time(
    index: int, bpm: float, subdivision: int = SUBDIVISION_SIXTEENTH
) -> float:
    """
    Convert a grid index to time in seconds.

    Args:
        index: Grid index (0-based)
        bpm: Beats per minute
        subdivision: Grid subdivision

    Returns:
        Time in seconds
    """
    beat_duration = 60.0 / bpm
    subdivision_duration = beat_duration / subdivision
    return index * subdivision_duration


def get_beat_number(time: float, bpm: float) -> tuple[int, int]:
    """
    Get the beat number and subdivision for a given time.

    Args:
        time: Time in seconds
        bpm: Beats per minute

    Returns:
        Tuple of (beat_number, subdivision_within_beat) where subdivision is 0-15 for 1/16 grid
    """
    beat_duration = 60.0 / bpm
    subdivision_duration = beat_duration / SUBDIVISION_SIXTEENTH

    total_subdivisions = int(round(time / subdivision_duration))
    beat_number = total_subdivisions // SUBDIVISION_SIXTEENTH
    subdivision = total_subdivisions % SUBDIVISION_SIXTEENTH

    return beat_number, subdivision
