# Adding New Songs

This guide explains how to add new songs to Beat Kanji.

---

## Overview

Each song requires two files:

1. **Audio file** (`.mp3`) - The music track
2. **Beatmap file** (`.json`) - Defines beat timing and metadata

Both files must share the same base name (e.g., `moonlight-sonate.mp3` and `moonlight-sonate.json`).

---

## File Locations

| File Type       | Location                      |
| --------------- | ----------------------------- |
| Audio (.mp3)    | `Beat Kanji/Resources/Audio/` |
| Beatmap (.json) | `Beat Kanji/Resources/Data/`  |

---

## Step-by-Step Guide

### 1. Prepare the Audio File

- Format: **MP3** (recommended for compatibility)
- Place the file in `Beat Kanji/Resources/Audio/`
- Use a descriptive, kebab-case filename (e.g., `tokyo-nights.mp3`)

### 2. Create the Beatmap JSON

Create a JSON file with the same base name as the audio file in `Beat Kanji/Resources/Data/`.

#### Beatmap Schema

```json
{
	"meta": {
		"version": "1.1",
		"filename": "your-song.mp3",
		"title": "Your Song Title",
		"category": "Category Name",
		"bpm": 120.0,
		"total_duration": 180.0
	},
	"notes": [
		{
			"time": 3.0,
			"level": 1,
			"type": "drum"
		}
	]
}
```

#### Meta Fields

| Field            | Type   | Required | Description                                      |
| ---------------- | ------ | -------- | ------------------------------------------------ |
| `version`        | String | Yes      | Schema version (currently `"1.1"`)               |
| `filename`       | String | Yes      | Audio filename with extension                    |
| `title`          | String | No\*     | Display title (defaults to filename)             |
| `category`       | String | No\*     | Category/pack name (defaults to "Uncategorized") |
| `bpm`            | Float  | Yes      | Beats per minute of the track                    |
| `total_duration` | Float  | Yes      | Total length in seconds                          |

\*While optional, `title` and `category` should always be provided for proper song organization.

#### Note Fields

| Field   | Type   | Description                                          |
| ------- | ------ | ---------------------------------------------------- |
| `time`  | Float  | Timestamp in seconds (from audio start)              |
| `level` | Int    | Difficulty: `1` = Easy, `2` = Medium, `3` = Hard     |
| `type`  | String | Note source: `"drum"`, `"bass"`, `"lead"`, `"vocal"` |

### 3. Add Files to Xcode Project

After adding the files to the filesystem:

1. Open the Xcode project
2. Right-click on `Resources/Audio` group → **Add Files to "Beat Kanji"**
3. Select your `.mp3` file
4. Right-click on `Resources/Data` group → **Add Files to "Beat Kanji"**
5. Select your `.json` file
6. Ensure both files have **"Copy items if needed"** checked
7. Ensure **Target Membership** includes "Beat Kanji"

### 4. Build and Run

The song will automatically appear in the song selection screen under its category.

---

## Categories

Songs are automatically grouped by their `category` field. To create a new category, simply use a new category name in your beatmap's metadata.

### Example Categories

```json
"category": "Classical Remix #1"
"category": "J-Pop Hits"
"category": "EDM Essentials"
"category": "Anime OST"
```

Songs within each category are sorted alphabetically by title.

---

## Beatmap Creation

Use the Beatmap Editor (recommended):

```bash
./scripts/run_editor.sh
```

This provides stem separation, peak detection, beat grid insertion, and manual editing.

See [beatmap.md](beatmap.md) for the format and integration details.

---

## Difficulty Levels

The beatmap contains notes for all difficulty levels. At runtime, notes are filtered:

| Difficulty | Filter       | Description                 |
| ---------- | ------------ | --------------------------- |
| Easy       | `level == 1` | Quarter notes, relaxed pace |
| Medium     | `level <= 2` | Eighth notes, moderate pace |
| Hard       | `level <= 3` | All notes, intense pace     |

**Note**: The first 3 seconds of notes are automatically skipped to give players time to prepare.

---

## Checklist

Before adding a new song, ensure:

- [ ] Audio file is in MP3 format
- [ ] Beatmap JSON has valid `title` and `category` fields
- [ ] `filename` in beatmap matches the actual audio filename
- [ ] `bpm` and `total_duration` are accurate
- [ ] Notes are properly timed and leveled
- [ ] Both files are added to Xcode project
- [ ] Target membership is set correctly

---

## Troubleshooting

### Song doesn't appear in menu

- Check that the beatmap JSON is in `Resources/Data/`
- Verify the JSON is valid (no syntax errors)
- Ensure the file is included in the Xcode target
- Check console for loading errors

### Audio doesn't play

- Verify the audio file is in `Resources/Audio/`
- Check that `meta.filename` matches the actual file name
- Ensure the audio file is included in the Xcode target

### Notes are off-beat

- Verify `bpm` is accurate for the track
- Check that note `time` values are correctly calculated
- Use the beatmap editor for precise timing
