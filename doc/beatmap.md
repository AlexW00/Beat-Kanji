# Beatmap System

This document describes the beatmap format and integration guidelines for rhythm-synced gameplay. Beatmaps are primarily created using the Beatmap Editor tool.

---

## Overview

A **beatmap** is a JSON file that maps musical events (beats, onsets) to timestamps. The game uses beatmaps to sync stroke prompts with the music, creating rhythm-based gameplay.

---

## Integration with Game

### Flow

1. **Start Screen** → Press Play
2. **Difficulty Selection** → Choose Easy, Medium, or Hard
3. **Game Initialization**:
   - Load selected beatmap (from `SongSelectScene`)
   - Filter notes based on difficulty level
   - Select random kanji sequence to match beat notes (with gaps between kanji)
   - Generate beat events mapping notes to kanji strokes
4. **Gameplay**:
   - Conveyor belt lines spawn synced to BPM (one line per beat)
   - Flying strokes arrive at exact beat times
   - Player draws strokes in rhythm with the music

### Key Files

| File                                   | Purpose                                |
| -------------------------------------- | -------------------------------------- |
| `Models/BeatmapLoader.swift`           | Loads and parses beatmap JSON          |
| `Scenes/DifficultySelectScene.swift`   | Difficulty selection UI                |
| `Game/GameEngine.swift`                | Beat event management, kanji selection |
| `Scenes/PlayScene+ConveyorBelt.swift`  | BPM-synced conveyor lines              |
| `Scenes/PlayScene+FlyingStrokes.swift` | Beat-synced stroke animations          |

---

## JSON Schema

```json
{
	"meta": {
		"version": "1.0",
		"filename": "MySong.mp3",
		"bpm": 128.5,
		"total_duration": 184.2
	},
	"notes": [
		{
			"time": 1.25,
			"level": 1,
			"type": "drum"
		},
		{
			"time": 1.75,
			"level": 2,
			"type": "bass"
		}
	]
}
```

### `meta` Object

| Field            | Type   | Description                        |
| ---------------- | ------ | ---------------------------------- |
| `version`        | String | Schema version (currently `"1.1"`) |
| `filename`       | String | Original audio filename            |
| `bpm`            | Float  | Detected beats per minute          |
| `total_duration` | Float  | Total audio duration in seconds    |

### `notes` Array

Each note object represents a beat/event where a stroke should be prompted:

| Field   | Type   | Description                                                       |
| ------- | ------ | ----------------------------------------------------------------- |
| `time`  | Float  | Timestamp in seconds (from audio start), always on beat           |
| `level` | Int    | Difficulty level: `1` = Easy, `2` = Medium, `3` = Hard            |
| `type`  | String | Note source: `"base"`, `"drum"`, `"bass"`, `"vocal"`, or `"lead"` |

---

## Difficulty Levels

The beatmap contains notes for all difficulty levels in a single file. Filter by `level` at runtime:

| Mode   | Filter Logic | Grid       | Description                     |
| ------ | ------------ | ---------- | ------------------------------- |
| Easy   | `level == 1` | 1/2 notes  | Base beat only, type "base"     |
| Medium | `level <= 2` | 1/8 notes  | Easy + drums (or bass fallback) |
| Hard   | `level <= 3` | 1/16 notes | Medium + vocals/lead            |

**All notes are guaranteed to be on-beat** (snapped to the appropriate grid subdivision).

---

## Creation Workflow

Use the Beatmap Editor for semi-automated authoring and precise control.

### Beatmap Editor (Recommended)

- Launch: `./scripts/run_editor.sh`
- Features: stem separation (Demucs), peak detection, beat grid insertion, manual marker editing, export to JSON.

![Beatmap Editor](./beatmap-editor.png)

Notes:

- Prefer authoring via the editor to ensure musicality and gameplay quality.

---

## File Locations

| File                               | Description                        |
| ---------------------------------- | ---------------------------------- |
| `scripts/beatmap-editor/`          | Beatmap Editor source (Python)     |
| `scripts/run_editor.sh`            | Launch script for Beatmap Editor   |
| `scripts/requirements.txt`         | Python dependencies for the editor |
| `scripts/setup_venv.sh`            | Virtual environment setup          |
| `Beat Kanji/Resources/Audio/*.mp3` | Audio files (bundled with app)     |
| `Beat Kanji/Resources/Data/*.json` | Beatmap JSON files (bundled)       |
|                                    |                                    |

---

## Configuration Constants

Editor-exported beatmaps follow these conventions:

| Constant                  | Default | Description                                      |
| ------------------------- | ------- | ------------------------------------------------ |
| `LEVEL_1_SUBDIVISION`     | 2       | 1/2 notes for Easy mode (base beat)              |
| `LEVEL_2_SUBDIVISION`     | 8       | 1/8 notes max for Medium mode                    |
| `LEVEL_3_SUBDIVISION`     | 16      | 1/16 notes max for Hard mode                     |
| `STEM_ACTIVITY_THRESHOLD` | 0.005   | Min avg RMS for a stem to be considered "active" |
| `DEDUP_THRESHOLD_SEC`     | 0.02    | Notes within 20ms are merged                     |

---

## Example Output

From `Beat Kanji/Resources/Audio/debug.mp3`:

```
BPM: 89.1
Duration: 260.1s
Notes breakdown:
  - Level 1 (Easy): Base beat at 1/2 note intervals
  - Level 2 (Medium): Easy + drums/bass at 1/8 grid
  - Level 3 (Hard): Medium + vocals/lead at 1/16 grid
```

Sample notes:

```json
{"time": 0.0, "level": 1, "type": "base"}
{"time": 0.337, "level": 1, "type": "base"}
{"time": 0.674, "level": 1, "type": "base"}
{"time": 1.011, "level": 1, "type": "base"}
```
