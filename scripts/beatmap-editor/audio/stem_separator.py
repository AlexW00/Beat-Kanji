"""
Stem separator wrapper for beatmap editor.
Wraps Demucs stem separation functionality.
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Callable


DEMUCS_MODEL = "htdemucs"


@dataclass
class StemFiles:
    """Container for stem file paths."""

    vocals: str
    drums: str
    bass: str
    other: str

    def as_dict(self) -> dict[str, str]:
        return {
            "vocals": self.vocals,
            "drums": self.drums,
            "bass": self.bass,
            "other": self.other,
        }


class StemSeparator:
    """
    Wraps Demucs for audio stem separation.
    """

    def __init__(self, output_dir: Optional[str] = None):
        """
        Initialize stem separator.

        Args:
            output_dir: Directory to store stems. If None, uses temp directory.
        """
        self._output_dir = output_dir
        self._temp_dir: Optional[str] = None

    @property
    def output_dir(self) -> str:
        """Get the output directory, creating temp dir if needed."""
        if self._output_dir:
            return self._output_dir

        if not self._temp_dir:
            self._temp_dir = tempfile.mkdtemp(prefix="beatmap_stems_")

        return self._temp_dir

    def separate(
        self, audio_path: str, progress_callback: Optional[Callable[[str], None]] = None
    ) -> StemFiles:
        """
        Separate audio into stems using Demucs.

        Args:
            audio_path: Path to input audio file
            progress_callback: Optional callback for progress messages

        Returns:
            StemFiles with paths to separated stems
        """
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        if progress_callback:
            progress_callback("Starting stem separation with Demucs...")

        # Build command
        cmd = [
            "python",
            "-m",
            "demucs",
            "-n",
            DEMUCS_MODEL,
            "-o",
            self.output_dir,
            audio_path,
        ]

        if progress_callback:
            progress_callback(f"Running: {' '.join(cmd)}")

        # Run Demucs
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            error_msg = result.stderr or "Unknown error"
            raise RuntimeError(f"Demucs separation failed: {error_msg}")

        # Find output stems
        input_name = Path(audio_path).stem
        stem_dir = os.path.join(self.output_dir, DEMUCS_MODEL, input_name)

        stems = StemFiles(
            vocals=os.path.join(stem_dir, "vocals.wav"),
            drums=os.path.join(stem_dir, "drums.wav"),
            bass=os.path.join(stem_dir, "bass.wav"),
            other=os.path.join(stem_dir, "other.wav"),
        )

        # Verify files exist
        for name, path in stems.as_dict().items():
            if not os.path.exists(path):
                raise RuntimeError(f"Expected stem file not found: {path}")

        if progress_callback:
            progress_callback("Stem separation complete!")

        return stems

    def cleanup(self):
        """Clean up temporary files."""
        if self._temp_dir and os.path.exists(self._temp_dir):
            shutil.rmtree(self._temp_dir)
            self._temp_dir = None

    def __del__(self):
        self.cleanup()
