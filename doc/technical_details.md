# Technical Details

## Getting Started

### Prerequisites

- macOS with Xcode 15+
- Python 3 (for data generation scripts)

### Setup

1. Clone the repository.
2. Run the configure script:
   ```bash
   ./configure.sh
   ```
   This will create a `.env` file. Edit it to add your Apple Development Team ID and Bundle Identifier.
3. Run `./configure.sh` again to apply the configuration and generate data files.
4. Open `Beat Kanji.xcodeproj` in Xcode OR run `./build.sh`.

_Note: The `kanji.sqlite` data file is generated locally by the `../scripts/generate_kanji.sh` script._

## Project Structure

The project is built using **Swift** and **SpriteKit**.

### Core Components

- **`Scenes/`**:
  - `StartScene`: Main menu.
  - `SongSelectScene`: Song and difficulty selection.
  - `PlayScene`: Core gameplay loop, drawing handling, and visualization.
  - `GameOverScene`: Score summary and replay options.
- **`Game/`**:
  - `GameEngine`: Manages game state (score, lives, current Kanji, stroke index) and evaluates strokes.
  - `GlobalBeatTimer`: Synchronizes game events with audio.
- **`Models/`**:
  - `KanjiModels`: Data structures for Kanji and Strokes.
  - `KanjiDataLoader`: Loads `kanji.sqlite` lazily from the app bundle.
  - `BeatmapLoader`: Loads and parses beatmap files.
- **`Audio/`**:
  - `AudioManager`: Handles background music playback.
- **`UI/`**:
  - Reusable UI components (`ButtonFactory`, `ConveyorBeltManager`, etc.).

### Assets

- **`Assets.xcassets/`**: Images organized by category.
- **`Resources/`**:
  - `Audio/`: Music and sound files.
  - `Data/`: Data files (`kanji.sqlite`, beatmaps).
  - `Fonts/`: Custom fonts (`NotoSansJP-*.ttf`).

### Documentation

- [beatmap.md](beatmap.md): Beatmap JSON format & integration.
- [beat-editor.md](beat-editor.md): Beatmap Editor usage and features.
- [game-engine.md](game-engine.md): Game logic details.
- [play.screen.md](play.screen.md): Play scene architecture.
- [adding-songs.md](adding-songs.md): Guide for adding new tracks.
- [ui-components.md](ui-components.md): Documentation for UI system.

### Scripts

Located in `../scripts/`:

- `setup_venv.sh`: Create Python venv with dependencies.
- `run_editor.sh`: Launch the Beatmap Editor.
- `beatmap-editor/`: Source for the Python-based Beatmap Editor.
- `generate_kanji.sh`: Regenerate kanji data from source.

### Tools

The Beatmap Editor is an important tool for authoring rhythm content.

![Beatmap Editor](beatmap-editor.png)

## Credits

**Data Sources**

- **Kanji Strokes**: [KanjiVG](https://kanjivg.tagaini.net) (CC BY-SA 3.0)
- **Kanji Levels**: [jlpt_kanji_json_msgpack](https://github.com/Renairisu/jlpt_kanji_json_msgpack) (MIT)
- **Kanji Keywords**: [kanji-keys](https://github.com/scriptin/kanji-keys/tree/master) (MIT)

**Assets**

- **Songs**: [Suno](https://suno.com)
- **Sound Effects**: [Splice](https://splice.com)
- **Images**: Adobe Firefly
- **Fonts**: [Noto Sans JP](https://fonts.google.com/noto/specimen/Noto+Sans+JP) (OFL)
