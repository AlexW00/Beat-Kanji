#!/bin/bash
#
# Beatmap Editor Launch Script
# Runs the beatmap editor with the correct Python environment
#
# Environment Variables:
#   BEATMAP_EDITOR_AUDIO_DIR    - Default directory for opening audio files (mp3, wav, etc.)
#   BEATMAP_EDITOR_BEATMAP_DIR  - Default directory for opening/saving beatmap JSON files
#
# Example:
#   export BEATMAP_EDITOR_AUDIO_DIR="/path/to/audio"
#   export BEATMAP_EDITOR_BEATMAP_DIR="/path/to/beatmaps"
#   ./run_editor.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDITOR_DIR="$SCRIPT_DIR/beatmap-editor"
VENV_DIR="$SCRIPT_DIR/.venv"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Set default directories if not already set
# Audio files are typically stored in Beat Kanji/Resources/Audio
export BEATMAP_EDITOR_AUDIO_DIR="${BEATMAP_EDITOR_AUDIO_DIR:-$PROJECT_ROOT/Beat Kanji/Resources/Audio}"
# Beatmap JSON files are typically stored in Beat Kanji/Resources/Data
export BEATMAP_EDITOR_BEATMAP_DIR="${BEATMAP_EDITOR_BEATMAP_DIR:-$PROJECT_ROOT/Beat Kanji/Resources/Data}"

echo "========================================"
echo "Beatmap Editor"
echo "========================================
Default Audio Directory: $BEATMAP_EDITOR_AUDIO_DIR
Default Beatmap Directory: $BEATMAP_EDITOR_BEATMAP_DIR
========================================"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found at $VENV_DIR"
    echo "Please run: ./setup_venv.sh first"
    exit 1
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Check for dearpygui
if ! python -c "import dearpygui" 2>/dev/null; then
    echo "Installing beatmap editor dependencies..."
    pip install -r "$EDITOR_DIR/requirements.txt"
fi

# Run the editor
cd "$EDITOR_DIR"
python main.py "$@"
