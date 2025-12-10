"""
Project state management.
Holds all editor state: audio, stems, beatmap, playhead position, etc.
"""

import os
import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional
import tempfile
import shutil

from .beatmap import Beatmap, BeatmapMeta, Note
from .history import History

# Persistent cache directory for stems
STEM_CACHE_DIR = os.path.join(tempfile.gettempdir(), "beatmap_editor_stem_cache")


@dataclass
class StemPaths:
    """Paths to separated audio stems."""

    vocals: Optional[str] = None
    drums: Optional[str] = None
    bass: Optional[str] = None
    other: Optional[str] = None

    def get(self, name: str) -> Optional[str]:
        """Get stem path by name."""
        return getattr(self, name, None)

    def all_exist(self) -> bool:
        """Check if all stem files exist."""
        for stem in [self.vocals, self.drums, self.bass, self.other]:
            if stem is None or not os.path.exists(stem):
                return False
        return True

    def as_dict(self) -> dict[str, Optional[str]]:
        """Convert to dictionary."""
        return {
            "vocals": self.vocals,
            "drums": self.drums,
            "bass": self.bass,
            "other": self.other,
        }


@dataclass
class StemState:
    """State for stem playback controls."""

    solo: bool = False
    mute: bool = False


class Project:
    """
    Central project state container.
    Manages audio files, stems, beatmap, and playback state.
    """

    # Lane definitions
    LANES = ["base", "drum", "bass", "vocal", "lead"]
    LANE_TO_STEM = {
        "base": None,  # Base beat uses original audio
        "drum": "drums",
        "bass": "bass",
        "vocal": "vocals",
        "lead": "other",
    }

    def __init__(self):
        # File paths
        self.audio_path: Optional[str] = None
        self.beatmap_path: Optional[str] = None
        self.stems: StemPaths = StemPaths()
        self._temp_dir: Optional[str] = None

        # Data
        self.beatmap: Beatmap = Beatmap()
        self.history: History = History()

        # Playback state
        self.playhead: float = 0.0  # Current time in seconds
        self.is_playing: bool = False

        # Stem control state
        self.stem_states: dict[str, StemState] = {
            "vocals": StemState(),
            "drums": StemState(),
            "bass": StemState(),
            "other": StemState(),
        }

        # Waveform data for visualization (downsampled min/max envelope)
        # Each entry is a dict with 'min', 'max', 'rms' arrays
        self.waveform_data: dict[str, Optional[dict]] = {
            "main": None,
            "vocals": None,
            "drums": None,
            "bass": None,
            "other": None,
        }

        # View state
        self.zoom: float = 100.0  # Pixels per second
        self.scroll_offset: float = 0.0  # Horizontal scroll in seconds

    @property
    def duration(self) -> float:
        """Get the total duration of the audio."""
        return self.beatmap.meta.total_duration

    @property
    def bpm(self) -> float:
        """Get the BPM of the beatmap."""
        return self.beatmap.meta.bpm

    @property
    def has_audio(self) -> bool:
        """Check if audio is loaded."""
        return self.audio_path is not None and os.path.exists(self.audio_path)

    @property
    def has_stems(self) -> bool:
        """Check if stems are available."""
        return self.stems.all_exist()

    @property
    def is_dirty(self) -> bool:
        """Check if there are unsaved changes."""
        return self.beatmap.dirty

    def new_project(self):
        """Create a new empty project."""
        self.audio_path = None
        self.beatmap_path = None
        self.stems = StemPaths()
        self.beatmap = Beatmap()
        self.history.clear()
        self.playhead = 0.0
        self.is_playing = False
        self.waveform_data = {k: None for k in self.waveform_data}
        self._cleanup_temp()

    def _generate_waveform_data(
        self, audio_data, sr: int, target_samples: int = 8000
    ) -> dict:
        """
        Generate downsampled waveform data for visualization with min/max envelope.

        Args:
            audio_data: Audio samples
            sr: Sample rate
            target_samples: Number of samples to generate for visualization

        Returns:
            Dict with 'min', 'max', and 'rms' arrays for detailed waveform rendering
        """
        import numpy as np

        # Convert to mono if stereo
        if len(audio_data.shape) > 1:
            audio_data = np.mean(audio_data, axis=0)

        # Normalize
        max_val = np.max(np.abs(audio_data))
        if max_val > 0:
            audio_data = audio_data / max_val

        # Downsample by taking min/max/rms in chunks for envelope display
        chunk_size = max(1, len(audio_data) // target_samples)
        waveform_min = []
        waveform_max = []
        waveform_rms = []

        for i in range(0, len(audio_data), chunk_size):
            chunk = audio_data[i : i + chunk_size]
            if len(chunk) > 0:
                waveform_min.append(float(np.min(chunk)))
                waveform_max.append(float(np.max(chunk)))
                waveform_rms.append(float(np.sqrt(np.mean(chunk**2))))

        return {"min": waveform_min, "max": waveform_max, "rms": waveform_rms}

    def load_audio(self, audio_path: str) -> tuple[float, float]:
        """
        Load an audio file and analyze it.

        Args:
            audio_path: Path to the audio file

        Returns:
            Tuple of (bpm, duration)
        """
        import librosa

        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        self.audio_path = audio_path

        # Analyze audio for BPM and duration
        y, sr = librosa.load(audio_path, sr=22050)
        duration = librosa.get_duration(y=y, sr=sr)
        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)

        # Handle tempo array
        if hasattr(tempo, "__len__"):
            bpm = float(tempo[0]) if len(tempo) > 0 else float(tempo)
        else:
            bpm = float(tempo)

        # Generate waveform data for main audio
        self.waveform_data["main"] = self._generate_waveform_data(y, sr)

        # Update beatmap metadata
        self.beatmap.meta.filename = os.path.basename(audio_path)
        self.beatmap.meta.bpm = bpm
        self.beatmap.meta.total_duration = duration

        return bpm, duration

    def _get_audio_cache_key(self) -> str:
        """
        Generate a cache key for the current audio file.
        Uses file path and modification time to detect changes.
        """
        if not self.audio_path:
            return ""

        # Get file stats for modification time
        stat = os.stat(self.audio_path)
        # Create a unique key from path + mtime + size
        key_data = f"{self.audio_path}:{stat.st_mtime}:{stat.st_size}"
        return hashlib.sha256(key_data.encode()).hexdigest()[:16]

    def _get_cached_stems(self) -> Optional[StemPaths]:
        """
        Check if cached stems exist for the current audio file.
        Returns StemPaths if cache hit, None otherwise.
        """
        cache_key = self._get_audio_cache_key()
        if not cache_key:
            return None

        cache_dir = os.path.join(STEM_CACHE_DIR, cache_key)

        stems = StemPaths(
            vocals=os.path.join(cache_dir, "vocals.wav"),
            drums=os.path.join(cache_dir, "drums.wav"),
            bass=os.path.join(cache_dir, "bass.wav"),
            other=os.path.join(cache_dir, "other.wav"),
        )

        if stems.all_exist():
            return stems
        return None

    def separate_stems(self, progress_callback=None) -> StemPaths:
        """
        Separate audio into stems using Demucs.
        Uses caching to avoid re-processing the same audio file.

        Args:
            progress_callback: Optional callback for progress updates

        Returns:
            StemPaths with paths to separated stems
        """
        import subprocess

        if not self.has_audio:
            raise ValueError("No audio loaded")

        # Check for cached stems first
        cached = self._get_cached_stems()
        if cached:
            if progress_callback:
                progress_callback("Using cached stems...")
            self.stems = cached
            # Generate waveforms for cached stems too
            self._generate_stem_waveforms(progress_callback)
            return self.stems

        # Create cache directory for this audio file
        cache_key = self._get_audio_cache_key()
        cache_dir = os.path.join(STEM_CACHE_DIR, cache_key)
        os.makedirs(cache_dir, exist_ok=True)

        # Create temp directory for Demucs output
        self._cleanup_temp()
        self._temp_dir = tempfile.mkdtemp(prefix="beatmap_editor_")

        if progress_callback:
            progress_callback(
                "Running stem separation (this may take a few minutes)..."
            )

        # Run Demucs
        cmd = [
            "python",
            "-m",
            "demucs",
            "-n",
            "htdemucs",
            "-o",
            self._temp_dir,
            self.audio_path,
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"Stem separation failed: {result.stderr}")

        # Get stem paths from Demucs output
        input_name = Path(self.audio_path).stem
        stem_dir = os.path.join(self._temp_dir, "htdemucs", input_name)

        # Copy stems to cache directory
        stem_files = ["vocals.wav", "drums.wav", "bass.wav", "other.wav"]
        for stem_file in stem_files:
            src = os.path.join(stem_dir, stem_file)
            dst = os.path.join(cache_dir, stem_file)
            if os.path.exists(src):
                shutil.copy2(src, dst)

        # Set stems to cached paths
        self.stems = StemPaths(
            vocals=os.path.join(cache_dir, "vocals.wav"),
            drums=os.path.join(cache_dir, "drums.wav"),
            bass=os.path.join(cache_dir, "bass.wav"),
            other=os.path.join(cache_dir, "other.wav"),
        )

        # Clean up temp directory
        self._cleanup_temp()

        if not self.stems.all_exist():
            raise RuntimeError("Stem separation completed but files not found")

        # Generate waveform data for stems
        self._generate_stem_waveforms(progress_callback)

        if progress_callback:
            progress_callback("Stem separation complete!")

        return self.stems

    def _generate_stem_waveforms(self, progress_callback=None):
        """Generate waveform data for all stems."""
        import librosa

        if progress_callback:
            progress_callback("Generating waveform data...")

        stem_paths = {
            "vocals": self.stems.vocals,
            "drums": self.stems.drums,
            "bass": self.stems.bass,
            "other": self.stems.other,
        }

        for name, path in stem_paths.items():
            if path and os.path.exists(path):
                try:
                    y, sr = librosa.load(path, sr=22050)
                    self.waveform_data[name] = self._generate_waveform_data(y, sr)
                except Exception:
                    self.waveform_data[name] = None

    def load_beatmap(self, beatmap_path: str):
        """Load a beatmap from file."""
        self.beatmap = Beatmap.load(beatmap_path)
        self.beatmap_path = beatmap_path
        self.history.clear()

    def save_beatmap(self, path: Optional[str] = None):
        """Save the beatmap to file."""
        save_path = path or self.beatmap_path
        if not save_path:
            raise ValueError("No save path specified")

        self.beatmap.save(save_path)
        self.beatmap_path = save_path

    def _cleanup_temp(self):
        """Clean up temporary files."""
        if self._temp_dir and os.path.exists(self._temp_dir):
            shutil.rmtree(self._temp_dir)
            self._temp_dir = None

    def cleanup(self):
        """Clean up resources."""
        self._cleanup_temp()

    def __del__(self):
        self.cleanup()
