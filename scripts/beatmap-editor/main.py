#!/usr/bin/env python3
"""
Beatmap Editor - Main Entry Point

A DearPyGui-based tool for creating and editing rhythm game beatmaps.

Usage:
    python -m beatmap-editor
    python main.py
    python main.py /path/to/audio.mp3  # Load audio file on startup
"""

import sys
import os
import argparse

# Add the beatmap-editor directory to path for absolute imports
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

from ui.app import BeatmapEditorApp


def main():
    """Run the beatmap editor application."""
    parser = argparse.ArgumentParser(
        description="Beatmap Editor - Create and edit rhythm game beatmaps"
    )
    parser.add_argument(
        "audio_file",
        nargs="?",
        default=None,
        help="Audio file (mp3, wav, etc.) to load on startup",
    )
    args = parser.parse_args()

    print("Starting Beatmap Editor...")

    app = BeatmapEditorApp(initial_audio_file=args.audio_file)
    app.run()


if __name__ == "__main__":
    main()
