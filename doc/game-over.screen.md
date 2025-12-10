- Screen: GameOverScene (`Beat Kanji/Scenes/GameOverScene.swift`)
- Two modes: Victory ("You Win") and Game Over
- Inputs: tap "Play Again" -> SongSelectScene; tap "Back" -> StartScene

## Visuals

### Victory Mode

- "You Win" logo with floating animation
- Animated conveyor belt (120 BPM)
- Beat-synced fireworks
- Full brightness background

### Game Over Mode

- "Game Over" logo with floating animation
- Broken glass frame overlay (shatter-left/right/top/bottom.png)
- Device motion parallax on glass shards
- Darkened background (alpha 0.4)
- No conveyor animation (stopped)

## Architecture

- Uses shared UI components from `UI/` folder:
  - `SharedBackground` for background image and perspective grid
  - `ConveyorBeltManager` for victory conveyor animation
  - `ButtonFactory` for button creation and animations
  - `ParticleFactory` for Play Again button sparkles
- See `doc/ui-components.md` for component API details.
