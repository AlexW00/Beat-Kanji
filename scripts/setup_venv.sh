#!/bin/bash
#
# Beatmap Generator Environment Setup Script
# Creates a Python virtual environment and installs dependencies
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

echo "========================================"
echo "Beatmap Generator - Environment Setup"
echo "========================================"

# Check for Python 3
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    echo "Error: Python 3 is not installed."
    echo "Please install Python 3.8+ first:"
    echo "  macOS: brew install python3"
    exit 1
fi

# Verify Python version
PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "Found Python $PYTHON_VERSION"

# Check for FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo ""
    echo "Warning: FFmpeg is not installed."
    echo "Spleeter requires FFmpeg for audio processing."
    echo "Install it with: brew install ffmpeg"
    echo ""
fi

# Create virtual environment
if [ -d "$VENV_DIR" ]; then
    echo ""
    echo "Virtual environment already exists at: $VENV_DIR"
    read -p "Do you want to recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
    else
        echo "Using existing virtual environment."
    fi
fi

if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo ""
echo "Installing dependencies..."
pip install -r "$REQUIREMENTS_FILE"

echo ""
echo "========================================"
echo "Setup complete!"
echo "========================================"
echo ""
echo "To activate the environment manually:"
echo "  source $VENV_DIR/bin/activate"
echo ""
echo "To run the Beatmap Editor:"
echo "  ./scripts/run_editor.sh"
echo ""
echo "To deactivate the environment:"
echo "  deactivate"
echo ""
