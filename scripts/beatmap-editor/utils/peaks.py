"""
Peak detection utilities for waveform analysis.
Detects peaks above a threshold percentage, with hysteresis to avoid
marking continuous loud sections as multiple peaks.
"""

import numpy as np
from typing import Optional
from dataclasses import dataclass, field

from core.constants import (
    WAVEFORMS,
    LANE_TO_WAVEFORM,
    WAVEFORM_TO_LANE,
    DEFAULT_THRESHOLD_PERCENT,
    DEFAULT_REARM_RATIO,
    MIN_PEAK_GAP_SECONDS,
)


@dataclass
class PeakSettings:
    """Settings for peak detection on a single track."""

    enabled: bool = False
    threshold_percent: float = DEFAULT_THRESHOLD_PERCENT
    rearm_threshold_percent: float = DEFAULT_THRESHOLD_PERCENT * DEFAULT_REARM_RATIO
    linked: bool = True  # If True, rearm threshold follows main threshold


@dataclass
class PeakState:
    """Holds peak detection settings and results for all tracks."""

    # Settings per track (key is waveform name: "main", "drums", "bass", "vocals", "other")
    settings: dict[str, PeakSettings] = field(
        default_factory=lambda: {
            "main": PeakSettings(),
            "drums": PeakSettings(),
            "bass": PeakSettings(),
            "vocals": PeakSettings(),
            "other": PeakSettings(),
        }
    )

    # Detected peak times per track
    peaks: dict[str, list[float]] = field(
        default_factory=lambda: {
            "main": [],
            "drums": [],
            "bass": [],
            "vocals": [],
            "other": [],
        }
    )


def detect_peaks(
    waveform_data: dict,
    duration: float,
    threshold_percent: float,
    min_gap_seconds: float = MIN_PEAK_GAP_SECONDS,
    rearm_threshold_percent: Optional[float] = None,
) -> list[float]:
    """
    Detect peaks in waveform data that exceed the threshold.

    Uses hysteresis: once a peak is detected, the signal must drop below
    a re-arm threshold before another peak can be detected. This prevents
    continuous loud sections from generating many false peaks.

    Args:
        waveform_data: Dict with 'min', 'max', 'rms' arrays from waveform generation
        duration: Total duration in seconds
        threshold_percent: Threshold percentage (0-100). Higher = fewer peaks.
        min_gap_seconds: Minimum gap between peaks in seconds
        rearm_threshold_percent: Re-arm threshold percentage (0-100). If None, uses 70% of threshold_percent.

    Returns:
        List of peak times in seconds
    """
    if not waveform_data:
        return []

    # Get RMS values (better for energy detection than raw min/max)
    rms_values = waveform_data.get("rms", [])
    if not rms_values:
        return []

    rms = np.array(rms_values)
    num_samples = len(rms)

    if num_samples == 0:
        return []

    # Calculate the actual threshold value from percentage
    # threshold_percent of 100 means only the absolute max, 0 means everything
    max_rms = np.max(rms)
    min_rms = np.min(rms)
    rms_range = max_rms - min_rms

    if rms_range <= 0:
        return []

    # Convert percentage to actual threshold
    threshold = min_rms + (rms_range * threshold_percent / 100.0)

    # Re-arm threshold (hysteresis) - must drop to this level before detecting another peak
    # Use provided rearm threshold or default to DEFAULT_REARM_RATIO of the detection threshold
    if rearm_threshold_percent is None:
        rearm_threshold_percent = threshold_percent * DEFAULT_REARM_RATIO
    rearm_threshold = min_rms + (rms_range * rearm_threshold_percent / 100.0)

    # Calculate minimum gap in samples
    samples_per_second = num_samples / duration if duration > 0 else 1
    min_gap_samples = int(min_gap_seconds * samples_per_second)

    peaks = []
    armed = True  # Whether we're looking for a new peak
    last_peak_sample = -min_gap_samples  # Ensure first peak can be detected

    i = 0
    while i < num_samples:
        val = rms[i]

        if armed:
            # Looking for a peak that exceeds threshold
            if val >= threshold:
                # Found a peak! Find the local maximum in this region
                peak_val = val
                peak_idx = i

                # Search forward for the actual peak
                j = i + 1
                while j < num_samples and rms[j] >= threshold:
                    if rms[j] > peak_val:
                        peak_val = rms[j]
                        peak_idx = j
                    j += 1

                # Check minimum gap
                if peak_idx - last_peak_sample >= min_gap_samples:
                    # Convert sample index to time
                    peak_time = (peak_idx / num_samples) * duration
                    peaks.append(peak_time)
                    last_peak_sample = peak_idx

                # Disarm until signal drops below rearm threshold
                armed = False
                i = j  # Skip to end of this peak region
                continue
        else:
            # Waiting for signal to drop below rearm threshold
            if val < rearm_threshold:
                armed = True

        i += 1

    return peaks


def lane_to_waveform_key(lane_name: str) -> str:
    """Map lane name to waveform data key."""
    return LANE_TO_WAVEFORM.get(lane_name, "main")


def waveform_to_lane_key(waveform_name: str) -> str:
    """Map waveform data key to lane name."""
    return WAVEFORM_TO_LANE.get(waveform_name, "base")
