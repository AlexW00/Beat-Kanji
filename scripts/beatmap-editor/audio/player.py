"""
Audio playback system using pydub + simpleaudio.
Handles multi-stem playback with solo/mute controls and seeking.
"""

import os
import time
import threading
from typing import Optional, Callable

import numpy as np
from pydub import AudioSegment
import simpleaudio as sa


class AudioPlayer:
    """
    Audio player with stem mixing support.
    Uses pydub for audio processing and simpleaudio for playback.
    Supports seeking and real-time solo/mute.
    """

    def __init__(self):
        # Audio data storage (as pydub AudioSegments)
        self._main_audio: Optional[AudioSegment] = None
        self._stem_audio: dict[str, Optional[AudioSegment]] = {
            "vocals": None,
            "drums": None,
            "bass": None,
            "other": None,
        }

        # Pre-mixed audio for playback
        self._mixed_audio: Optional[AudioSegment] = None

        # State
        self._is_playing = False
        self._position: float = 0.0  # Current position in seconds
        self._duration: float = 0.0
        self._playback_start_time: float = 0.0
        self._playback_start_pos: float = 0.0

        # Track if we're using stems or main audio
        self._using_stems: bool = False

        # Playback object
        self._play_obj: Optional[sa.PlayObject] = None
        self._lock = threading.Lock()

        # Solo/mute state
        self._solo_states: dict[str, bool] = {name: False for name in self._stem_audio}
        self._mute_states: dict[str, bool] = {name: False for name in self._stem_audio}

        # Callbacks
        self._on_position_change: Optional[Callable[[float], None]] = None
        self._on_playback_end: Optional[Callable[[], None]] = None

    def set_position_callback(self, callback: Callable[[float], None]):
        """Set callback for position changes."""
        self._on_position_change = callback

    def set_end_callback(self, callback: Callable[[], None]):
        """Set callback for playback end."""
        self._on_playback_end = callback

    def load_main(self, audio_path: str):
        """Load the main audio file."""
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        # Load audio file with pydub (handles format detection)
        self._main_audio = AudioSegment.from_file(audio_path)
        self._duration = len(self._main_audio) / 1000.0  # Convert ms to seconds
        self._mixed_audio = self._main_audio

    def load_stem(self, stem_name: str, audio_path: str):
        """Load a stem audio file."""
        if stem_name not in self._stem_audio:
            raise ValueError(f"Unknown stem: {stem_name}")

        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Stem file not found: {audio_path}")

        # Load audio file
        self._stem_audio[stem_name] = AudioSegment.from_file(audio_path)

    def load_all_stems(self, stems_dict: dict[str, str]):
        """Load all stems from a dictionary of paths."""
        stems_loaded = False
        for name, path in stems_dict.items():
            if path and os.path.exists(path):
                self.load_stem(name, path)
                stems_loaded = True
        self._using_stems = stems_loaded

        # Pre-mix stems for playback
        if self._using_stems:
            self._rebuild_mix()

    @property
    def duration(self) -> float:
        """Get audio duration in seconds."""
        return self._duration

    @property
    def is_playing(self) -> bool:
        """Check if audio is currently playing."""
        return self._is_playing

    @property
    def position(self) -> float:
        """Get current playback position in seconds."""
        if self._is_playing:
            elapsed = time.time() - self._playback_start_time
            pos = self._playback_start_pos + elapsed
            return min(pos, self._duration)
        return self._position

    def _rebuild_mix(self):
        """Rebuild the mixed audio based on current solo/mute states."""
        if not self._using_stems:
            self._mixed_audio = self._main_audio
            return

        # Determine which stems to include
        any_solo = any(self._solo_states.values())

        # Collect stems to mix
        stems_to_mix = []
        for stem_name, audio in self._stem_audio.items():
            if audio is None:
                continue

            # Check if this stem should be included
            if any_solo:
                if not self._solo_states[stem_name]:
                    continue
            else:
                if self._mute_states[stem_name]:
                    continue

            stems_to_mix.append(audio)

        if not stems_to_mix:
            # No stems to mix - create silence
            if self._main_audio:
                self._mixed_audio = AudioSegment.silent(duration=len(self._main_audio))
            return

        # Start with first stem
        mixed = stems_to_mix[0]

        # Overlay remaining stems
        for stem in stems_to_mix[1:]:
            mixed = mixed.overlay(stem)

        with self._lock:
            self._mixed_audio = mixed

    def play(self, position: float = 0.0):
        """
        Start playback from a specific position.

        Args:
            position: Start position in seconds
        """
        self.stop()

        if self._mixed_audio is None:
            return

        position = max(0.0, min(position, self._duration))
        self._position = position
        self._playback_start_pos = position
        self._playback_start_time = time.time()

        # Slice audio from position
        start_ms = int(position * 1000)
        audio_slice = self._mixed_audio[start_ms:]

        if len(audio_slice) == 0:
            return

        # Convert to raw audio data for simpleaudio
        try:
            raw_data = audio_slice.raw_data
            sample_width = audio_slice.sample_width
            channels = audio_slice.channels
            frame_rate = audio_slice.frame_rate

            self._play_obj = sa.play_buffer(
                raw_data,
                num_channels=channels,
                bytes_per_sample=sample_width,
                sample_rate=frame_rate,
            )
            self._is_playing = True
        except Exception as e:
            print(f"Audio playback error: {e}")
            self._is_playing = False

    def pause(self):
        """Pause playback."""
        if self._is_playing:
            self._position = self.position
            self._is_playing = False
            if self._play_obj:
                self._play_obj.stop()
                self._play_obj = None

    def stop(self):
        """Stop playback and reset position."""
        self._is_playing = False
        self._position = 0.0
        if self._play_obj:
            self._play_obj.stop()
            self._play_obj = None

    def seek(self, position: float):
        """
        Seek to a specific position.

        Args:
            position: Position in seconds
        """
        was_playing = self._is_playing

        if was_playing:
            self.pause()

        self._position = max(0.0, min(position, self._duration))

        if was_playing:
            self.play(self._position)

    def toggle_play(self):
        """Toggle between play and pause."""
        if self._is_playing:
            self.pause()
        else:
            self.play(self._position)

    def set_solo(self, stem_name: str, solo: bool):
        """Set solo state for a stem."""
        if stem_name in self._solo_states:
            self._solo_states[stem_name] = solo
            self._on_mix_state_changed()

    def set_mute(self, stem_name: str, mute: bool):
        """Set mute state for a stem."""
        if stem_name in self._mute_states:
            self._mute_states[stem_name] = mute
            self._on_mix_state_changed()

    def toggle_solo(self, stem_name: str):
        """Toggle solo for a stem."""
        if stem_name in self._solo_states:
            self._solo_states[stem_name] = not self._solo_states[stem_name]
            self._on_mix_state_changed()

    def toggle_mute(self, stem_name: str):
        """Toggle mute for a stem."""
        if stem_name in self._mute_states:
            self._mute_states[stem_name] = not self._mute_states[stem_name]
            self._on_mix_state_changed()

    def _on_mix_state_changed(self):
        """Handle solo/mute state change - rebuild mix and restart if playing."""
        current_pos = self.position
        was_playing = self._is_playing

        if was_playing:
            self.pause()

        self._rebuild_mix()

        if was_playing:
            self.play(current_pos)

    def update(self) -> float:
        """
        Update playback state. Call this in the main loop.

        Returns:
            Current position in seconds
        """
        pos = self.position

        # Check for end of playback
        if self._is_playing and self._play_obj:
            if not self._play_obj.is_playing():
                self._is_playing = False
                self._position = 0.0
                self._play_obj = None
                if self._on_playback_end:
                    self._on_playback_end()

        # Notify position change
        if self._on_position_change:
            self._on_position_change(pos)

        return pos

    def cleanup(self):
        """Clean up resources."""
        self.stop()
