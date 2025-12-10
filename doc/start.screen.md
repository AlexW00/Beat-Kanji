- Screen: StartScene (`Beat Kanji/Scenes/StartScene.swift`)
- Purpose: Animated entry point matching the gameplay visual style.
- Flow: tap "Play" button (SpriteKit button) -> presents `SongSelectScene`.

## Visuals

- **Background**: Same as PlayScene (bg1.jpeg, aspect fill, offset by 28pt).
- **Conveyor Belt**: Animated perspective grid synced to 100 BPM.
  - Vertical converging lines from center to horizon.
  - Horizontal lines spawning at the beat and traveling forward.
  - Beat pulse effect on lines for rhythmic visual feedback.
- **Particles**: BackgroundParticles.sks if available.

## UI Layout (SpriteKit)

The screen is divided into thirds:

### Top Third: Logo

- "Beat Kanji" title text (placeholder for future PNG logo).
- AvenirNext-Bold, 56pt, white with shadow.

### Middle Third: Play Button

- Single Play button using `button.png`, centered near the lower third.
- Subtle pulsing animation for attraction.

### Bottom Third: Empty

Reserved for future content or visual balance.

## Localization

All UI strings are localized via `Localizable.strings`:

- English (`en.lproj/`)
- Japanese (`ja.lproj/`)
- German (`de.lproj/`)

Keys:

- `start.title` - App title
- `start.play` - Play button
- `start.gallery` - Kanji Gallery button
- `start.gallery.comingSoon` - Coming soon subtitle
- `start.settings` - Settings button

## Architecture

- UI is rendered directly in `StartScene` with SpriteKit (no SwiftUI overlay).
- Uses shared UI components from `UI/` folder:
  - `SharedBackground` for background image and perspective grid
  - `ConveyorBeltManager` for beat-synced conveyor animation (100 BPM)
  - `ButtonFactory` for button creation and animations
  - `ParticleFactory` for button sparkle effects
- See `doc/ui-components.md` for component API details.
- Navigation flows through `StartScene.transitionToPlayScene()`.
