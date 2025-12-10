# Beatmap Editor

A DearPyGui-based dev tool for creating and editing beatmaps semi-automatically.

**Status:** ✅ Editor is the recommended way to create beatmaps. Some features still need polishing.

---

## Quick Start

```bash
# Run the editor
./scripts/run_editor.sh

# Or manually:
source scripts/.venv/bin/activate
pip install -r scripts/requirements.txt  # if not already done
cd scripts/beatmap-editor && python main.py
```

---

## Overview

The editor enables a semi-automated workflow:

1. Load an MP3 file
2. Auto-split stems via Demucs
3. Auto-detect beat markers using existing heuristics
4. Manually refine markers in a visual editor
5. Export the final beatmap JSON

### Screenshot

![Beatmap Editor](./beatmap-editor.png)

---

## Implementation Status

| Component      | File                      | Status | Notes                                        |
| -------------- | ------------------------- | ------ | -------------------------------------------- |
| Entry point    | `main.py`                 | ✅     | Adds script dir to path for absolute imports |
| Beatmap model  | `core/beatmap.py`         | ✅     | Note, BeatmapMeta, Beatmap classes           |
| Project state  | `core/project.py`         | ✅     | Holds audio, stems, beatmap, playhead        |
| Undo/redo      | `core/history.py`         | ✅     | Command pattern implementation               |
| Audio player   | `audio/player.py`         | ✅     | Pygame-based, needs seek testing             |
| Stem separator | `audio/stem_separator.py` | ✅     | Demucs wrapper                               |
| Main app       | `ui/app.py`               | ✅     | DearPyGui application shell                  |
| Menu bar       | `ui/menu.py`              | ✅     | File/Edit menus                              |
| Transport      | `ui/transport.py`         | ✅     | Play/pause/seek                              |
| Stem controls  | `ui/stem_controls.py`     | ✅     | Solo/mute buttons                            |
| Peak controls  | `ui/peak_controls.py`     | ✅     | Peak detection threshold & add markers       |
| Timeline       | `ui/timeline.py`          | ✅     | Lanes, grid, markers, peak highlights        |
| Preview        | `ui/preview.py`           | ✅     | Flying stroke simulation                     |
| Grid utils     | `utils/grid.py`           | ✅     | Beat grid & snapping                         |
| Waveform utils | `utils/waveform.py`       | ✅     | Texture generation                           |
| Peak utils     | `utils/peaks.py`          | ✅     | Peak detection algorithm                     |

### Known Issues / TODOs

- [ ] **Keyboard shortcuts**: Using raw key codes (32=Space, 261=Delete, 49-51=1-3) because `mvKey_*` constants not available in DearPyGui 1.10.0
- [ ] **Audio seek**: Pygame doesn't support precise seeking; workaround needed
- [ ] **Waveform display**: Currently placeholder lines, need to integrate texture generation
- [ ] **Marker dragging**: Not yet implemented
- [ ] **Box selection**: Not yet implemented
- [ ] **Unsaved changes warning**: Not yet implemented
- [ ] **Ctrl+Z/Ctrl+Shift+Z**: Menu shows shortcuts but handlers not connected

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Menu Bar: [File] [Edit]                                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────┐  ┌──────────────────┐               │
│  │   Preview Window  │  │  Peak Highlight  │               │
│  │ (Flying stroke)   │  │  [x] Main   50%  │  [Transport]  │
│  │                   │  │  [ ] Drums  50%  │  [▶ Play]     │
│  │                   │  │  [ ] Bass   50%  │               │
│  └───────────────────┘  │  [ ] Vocals 50%  │  [Stem Ctrls] │
│                         │  [ ] Other  50%  │               │
│                         └──────────────────┘               │
├─────────────────────────────────────────────────────────────┤
│  ▼ Playhead                                                 │
│  │                                                          │
│  ├── base   │▒▒░░▒▒░░▒▒░░▒▒░░│ (waveform + markers)        │
│  ├── drum   │▒▒░░▒▒░░▒▒░░▒▒░░│                              │
│  ├── bass   │▒▒░░▒▒░░▒▒░░▒▒░░│                              │
│  ├── vocal  │▒▒░░▒▒░░▒▒░░▒▒░░│                              │
│  ├── lead   │▒▒░░▒▒░░▒▒░░▒▒░░│                              │
│  │                                                          │
│  [Scroll/Zoom controls]                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Features

### Peak Highlight (New!)

The peak highlight feature provides a semi-automated way to detect and add markers:

| Feature            | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| Track Checkboxes   | Enable/disable peak detection per track (Main, Drums, Bass, etc.)  |
| Threshold Slider   | Set threshold 0-100%. Higher = fewer peaks (only loudest detected) |
| Live Preview       | Orange markers appear on timeline showing detected peaks           |
| Add Markers Button | Click "+ Add" to create actual markers at detected peak positions  |
| Peak Count         | Shows number of peaks detected with current settings               |

**Peak Detection Algorithm:**

- Uses RMS (root-mean-square) energy to detect volume peaks
- Hysteresis prevents multiple detections in continuously loud sections
- Once a peak is detected, signal must drop below 70% of threshold before next detection
- Minimum gap of 50ms between peaks
- Markers are snapped to 1/16 note grid when added

### Beat Marker Insert

Insert markers at regular beat intervals for quick beatmap scaffolding:

| Feature        | Description                                                          |
| -------------- | -------------------------------------------------------------------- |
| Lane Selector  | Choose which track to insert markers into (base, drum, bass, etc.)   |
| Beat Interval  | Select subdivision: 1/2, 1/4, 1/8, or 1/16 beat                      |
| Level Selector | Set difficulty level for inserted markers (1=Easy, 2=Medium, 3=Hard) |
| Insert Button  | Click "+ Insert Beat Markers" to add markers at regular intervals    |

**Use Cases:**

- Create a base rhythm layer with 1/2 beat markers
- Add complexity with 1/4 or 1/8 subdivisions on specific tracks
- Quickly scaffold a beatmap before fine-tuning individual markers

### Core Functionality

| Feature        | Description                                                         |
| -------------- | ------------------------------------------------------------------- |
| Load MP3       | Opens file dialog, separates stems via Demucs, auto-detects markers |
| Load Beatmap   | Import existing `.json` beatmap file                                |
| Export Beatmap | Save beatmap to user-selected location                              |
| Play/Pause     | Spacebar or button; plays audio and moves playhead                  |
| Playhead       | Shows current position; jumps on grid (no smooth scrolling needed)  |

### Timeline & Lanes

| Feature          | Description                                                 |
| ---------------- | ----------------------------------------------------------- |
| 5 Lanes          | One per note type: `base`, `drum`, `bass`, `vocal`, `lead`  |
| Waveform Display | Each lane shows its corresponding stem waveform             |
| Grid Lines       | Visual beat grid at 1/16 note resolution                    |
| Snap to Grid     | Always enabled; snaps to 1/16 note grid (finest resolution) |
| Scroll           | Horizontal scroll through timeline                          |
| Zoom             | Zoom in/out on timeline                                     |
| BPM Display      | Shows detected BPM for reference                            |

### Marker Editing

| Action        | Trigger                          | Behavior                                                          |
| ------------- | -------------------------------- | ----------------------------------------------------------------- |
| Add Marker    | Double-click empty space in lane | Creates marker at grid-snapped position, default level 1          |
| Select Marker | Click                            | Single selection                                                  |
| Multi-Select  | Ctrl+Click or drag box           | Select multiple markers                                           |
| Move Marker   | Drag                             | Move in time (snaps to grid); move between lanes (updates `type`) |
| Change Level  | Double-click marker              | Cycles level: 1 → 2 → 3 → 1                                       |
| Change Level  | Press 1/2/3 with selection       | Sets level for all selected markers                               |
| Delete Marker | Press Delete with selection      | Removes selected markers                                          |

### Marker Appearance

| Level | Color  | Difficulty |
| ----- | ------ | ---------- |
| 1     | Green  | Easy       |
| 2     | Yellow | Medium     |
| 3     | Red    | Hard       |

### Audio Controls

| Feature         | Description                                |
| --------------- | ------------------------------------------ |
| Solo Stem       | Click solo button to hear only that stem   |
| Mute Stem       | Click mute button to silence that stem     |
| Master Playback | Plays mixed audio (with solo/mute applied) |

### Edit History

| Feature         | Description                                          |
| --------------- | ---------------------------------------------------- |
| Undo            | Ctrl+Z - reverts last action                         |
| Redo            | Ctrl+Shift+Z - re-applies undone action              |
| Copy            | Cmd/Ctrl+C - copies selected markers to clipboard    |
| Paste           | Cmd/Ctrl+V - pastes markers at playhead position     |
| Duplicate       | Cmd/Ctrl+D - duplicates selected markers at playhead |
| Unsaved Warning | Prompt before closing/loading with unsaved changes   |

### Selection Operations

| Feature                 | Description                                              |
| ----------------------- | -------------------------------------------------------- |
| Select All              | Cmd/Ctrl+A - selects all markers                         |
| Deselect All            | Menu only - deselects all markers                        |
| Select by Track         | Menu only - select all markers in a specific track       |
| Select by Level         | Menu only - select all markers at a specific level       |
| Select by Track & Level | Menu only - select markers matching both track and level |

**Use Cases:**

- Quickly select all "drum" markers to change their level
- Select all Level 1 markers to delete and refine
- Combine track and level to precisely target specific markers

### Preview Window

| Feature            | Description                                                    |
| ------------------ | -------------------------------------------------------------- |
| Flying Strokes     | Debug visualization simulating game's flying stroke timing     |
| Sync with Playhead | Shows strokes arriving based on current playback position      |
| Simple Graphics    | Circles/shapes sufficient; doesn't need actual kanji rendering |

---

## Technical Details

### Grid Resolution

- Snap grid: **1/16 notes** (finest subdivision from `LEVEL_3_SUBDIVISION`)
- Grid calculation: `beat_duration = 60.0 / bpm`, `grid_step = beat_duration / 16`

### Lane-Type Mapping

Moving a marker between lanes automatically updates its `type` field:

| Lane  | Type Value |
| ----- | ---------- |
| base  | `"base"`   |
| drum  | `"drum"`   |
| bass  | `"bass"`   |
| vocal | `"vocal"`  |
| lead  | `"lead"`   |

Note: `type: "base"` has no gameplay effect; type and level are independent.

### Keyboard Shortcuts

| Shortcut     | Action                          |
| ------------ | ------------------------------- |
| Space        | Play/Pause                      |
| Delete       | Delete selected markers         |
| 1            | Set selected markers to level 1 |
| 2            | Set selected markers to level 2 |
| 3            | Set selected markers to level 3 |
| Ctrl+Z       | Undo                            |
| Ctrl+Shift+Z | Redo                            |
| Ctrl+C       | Copy selected markers           |
| Ctrl+V       | Paste markers at playhead       |
| Ctrl+D       | Duplicate selected markers      |
| Ctrl+A       | Select All                      |
| Ctrl+S       | Save/Export beatmap             |
| Ctrl+O       | Open MP3 or beatmap             |

**Note:** Selection by track/level operations are available in the Select menu without keyboard shortcuts.

---

## File Structure

```
scripts/beatmap-editor/
├── __init__.py             # Package init
├── __main__.py             # Package runner (python -m beatmap-editor)
├── main.py                 # Entry point - adds script dir to sys.path
├── requirements.txt        # Editor-specific deps (dearpygui, pygame)
├── audio/
│   ├── __init__.py
│   ├── player.py           # Audio playback (pygame.mixer)
│   └── stem_separator.py   # Demucs wrapper
├── core/
│   ├── __init__.py
│   ├── beatmap.py          # Beatmap data model + load/save
│   ├── project.py          # Project state (audio, stems, markers)
│   └── history.py          # Undo/redo command stack
├── ui/
│   ├── __init__.py
│   ├── app.py              # Main DearPyGui window + orchestration
│   ├── menu.py             # Menu bar (File, Edit, Help)
│   ├── timeline.py         # Timeline widget with lanes & markers
│   ├── preview.py          # Flying stroke simulation
│   ├── transport.py        # Play/pause/seek controls
│   ├── stem_controls.py    # Solo/mute buttons
│   └── peak_controls.py    # Peak detection controls & add markers
└── utils/
    ├── __init__.py
    ├── grid.py             # Grid snapping utilities
    ├── waveform.py         # Waveform texture generation
    └── peaks.py            # Peak detection algorithm
```

---

## Dependencies

**Version constraints** (as of Nov 2025):

- `dearpygui>=1.10.0` (1.11.0 not available yet)
- `pygame>=2.5.0`

Uses existing venv from `scripts/setup_venv.sh`:

| Package     | Purpose                               |
| ----------- | ------------------------------------- |
| `dearpygui` | UI framework                          |
| `pygame`    | Audio playback                        |
| `librosa`   | Waveform visualization, BPM detection |
| `numpy`     | Array operations                      |
| `demucs`    | Stem separation (already in venv)     |

---

## Architecture Notes

### Import Structure

All imports are **absolute** (not relative) because `main.py` adds its directory to `sys.path`:

```python
# In main.py:
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

# Then imports like:
from ui.app import BeatmapEditorApp  # NOT: from .ui.app
from core.project import Project      # NOT: from ..core.project
```

### Key Code Locations

| What                     | Where                                                            |
| ------------------------ | ---------------------------------------------------------------- |
| Main app orchestration   | `ui/app.py` - `BeatmapEditorApp` class                           |
| Keyboard shortcuts       | `ui/app.py` - `_setup_keyboard_shortcuts()` (uses raw key codes) |
| File dialogs             | `ui/app.py` - `_create_file_dialogs()`                           |
| Marker rendering         | `ui/timeline.py` - `_draw_markers()`                             |
| Peak highlight rendering | `ui/timeline.py` - `_draw_peak_highlights()`                     |
| Peak detection           | `utils/peaks.py` - `detect_peaks()`                              |
| Peak controls UI         | `ui/peak_controls.py` - `PeakControls` class                     |
| Grid snapping            | `utils/grid.py` - `snap_to_grid()`                               |
| Beatmap save/load        | `core/beatmap.py` - `Beatmap.save()` / `Beatmap.load()`          |

### DearPyGui 1.10.0 Quirks

- Key constants like `mvKey_Space` don't exist - use raw codes (32, 261, 49-51)
- Theme colors use 0-255 range in some places, 0-1 in others
- Handler registry must be created before `setup_dearpygui()`

---

## Implementation Notes

1. **Reuse existing code**: `generate_beatmap.py` has stem separation and beat detection logic to reuse
2. **UI simplicity**: Functional dev tool; aesthetics are secondary
3. **Waveform caching**: Pre-compute waveform images for each stem to avoid lag
4. **Playback sync**: Use pygame.mixer with position tracking; update playhead on timer
5. **State management**: Single `Project` object holds all state; commands modify via history stack

---

## Workflow

1. **New Project**: File → Open MP3

   - Select MP3 file
   - Demucs separates stems (shows progress)
   - Librosa detects BPM
   - Displays in editor

2. **Edit Existing**: File → Open Beatmap

   - Select JSON file
   - Loads markers
   - User must manually load corresponding audio if needed

3. **Adding Markers with Peak Highlight**:

   - Enable checkbox for desired track (Main, Drums, etc.)
   - Adjust threshold slider (higher = fewer peaks)
   - Orange highlight markers appear on timeline as preview
   - Click "+ Add" to add actual markers at peak positions
   - Markers are automatically snapped to 1/16 note grid

4. **Manual Editing**:

   - Play audio to hear timing
   - Solo stems to isolate sounds
   - Double-click to add markers manually
   - Move/delete markers as needed
   - Change difficulty levels (1, 2, 3 keys)
   - Undo/redo as needed

5. **Export**: File → Export Beatmap
   - Select save location
   - Writes JSON in game-compatible format
