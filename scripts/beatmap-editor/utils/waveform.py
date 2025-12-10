"""
Waveform texture generation for timeline visualization.
Converts audio data to drawable waveform representations.
"""

import numpy as np
from typing import Optional
import librosa

# Audio analysis constants
SAMPLE_RATE = 22050
HOP_LENGTH = 512


def load_audio_for_waveform(audio_path: str) -> tuple[np.ndarray, int]:
    """
    Load audio file for waveform generation.

    Args:
        audio_path: Path to audio file

    Returns:
        Tuple of (audio_samples, sample_rate)
    """
    y, sr = librosa.load(audio_path, sr=SAMPLE_RATE)
    return y, sr


def generate_waveform_data(
    audio_samples: np.ndarray,
    width: int,
    height: int = 100,
    sample_rate: int = SAMPLE_RATE,
) -> np.ndarray:
    """
    Generate waveform visualization data from audio samples.

    Args:
        audio_samples: Audio sample array
        width: Width in pixels (number of columns)
        height: Height in pixels
        sample_rate: Sample rate of the audio

    Returns:
        2D numpy array of shape (height, width) with values 0-255 for grayscale intensity
    """
    if len(audio_samples) == 0:
        return np.zeros((height, width), dtype=np.uint8)

    # Number of samples per pixel column
    samples_per_pixel = len(audio_samples) / width

    waveform = np.zeros((height, width), dtype=np.uint8)
    center = height // 2

    for x in range(width):
        start_sample = int(x * samples_per_pixel)
        end_sample = int((x + 1) * samples_per_pixel)
        end_sample = min(end_sample, len(audio_samples))

        if start_sample >= end_sample:
            continue

        chunk = audio_samples[start_sample:end_sample]

        # Get min/max for this chunk (for envelope display)
        min_val = np.min(chunk)
        max_val = np.max(chunk)

        # Convert to pixel coordinates
        min_y = center - int(min_val * center * 0.9)
        max_y = center - int(max_val * center * 0.9)

        # Clamp to bounds
        min_y = np.clip(min_y, 0, height - 1)
        max_y = np.clip(max_y, 0, height - 1)

        # Draw vertical line from min to max
        if min_y > max_y:
            min_y, max_y = max_y, min_y

        waveform[min_y : max_y + 1, x] = 200  # Light gray for waveform

    return waveform


def generate_waveform_texture(
    audio_path: str, width: int, height: int = 100
) -> np.ndarray:
    """
    Generate a waveform texture from an audio file.

    Args:
        audio_path: Path to the audio file
        width: Width of the texture in pixels
        height: Height of the texture in pixels

    Returns:
        RGBA numpy array of shape (height, width, 4) suitable for DearPyGui texture
    """
    # Load audio
    audio_samples, sr = load_audio_for_waveform(audio_path)

    # Generate grayscale waveform
    waveform_gray = generate_waveform_data(audio_samples, width, height, sr)

    # Convert to RGBA (cyan-ish color for waveform)
    rgba = np.zeros((height, width, 4), dtype=np.float32)

    # Normalize to 0-1 for DearPyGui
    intensity = waveform_gray.astype(np.float32) / 255.0

    # Set color (cyan: R=0.3, G=0.8, B=0.9)
    rgba[:, :, 0] = intensity * 0.3  # R
    rgba[:, :, 1] = intensity * 0.8  # G
    rgba[:, :, 2] = intensity * 0.9  # B
    rgba[:, :, 3] = intensity * 0.8  # A

    return rgba


def get_audio_duration(audio_path: str) -> float:
    """
    Get the duration of an audio file in seconds.

    Args:
        audio_path: Path to audio file

    Returns:
        Duration in seconds
    """
    y, sr = librosa.load(audio_path, sr=SAMPLE_RATE)
    return librosa.get_duration(y=y, sr=sr)


def extract_rms_envelope(
    audio_path: str, hop_length: int = HOP_LENGTH
) -> tuple[np.ndarray, np.ndarray]:
    """
    Extract RMS energy envelope from audio file.

    Args:
        audio_path: Path to audio file
        hop_length: Hop length for RMS calculation

    Returns:
        Tuple of (times, rms_values)
    """
    y, sr = librosa.load(audio_path, sr=SAMPLE_RATE)
    rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]
    times = librosa.frames_to_time(np.arange(len(rms)), sr=sr, hop_length=hop_length)
    return times, rms
