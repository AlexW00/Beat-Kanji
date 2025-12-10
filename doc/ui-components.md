# UI Components

Reusable UI components live in `Beat Kanji/UI/`. These extract common patterns from scene files to reduce duplication and ensure visual consistency.

## SharedBackground

**File**: `UI/SharedBackground.swift`

Provides background image and perspective grid setup used across scenes.

### Constants

- `backgroundOffsetY: 28.0` — Y offset for background positioning
- `conveyorHorizonY: 0.15` — Horizon line as fraction of screen height

### Methods

- `addBackground(to: SKScene, alpha: CGFloat) -> SKSpriteNode` — Adds bg1.jpeg with aspect fill
- `addPerspectiveGrid(to: SKScene, lineAlpha: CGFloat) -> SKNode` — Adds converging vertical lines + closing line
- `addBackgroundParticles(to: SKScene)` — Adds BackgroundParticles.sks if available
- `setupComplete(for: SKScene, backgroundAlpha: CGFloat, gridAlpha: CGFloat)` — Convenience for full setup

## ConveyorBeltManager

**File**: `UI/ConveyorBeltManager.swift`

Manages BPM-synced horizontal conveyor belt lines with perspective animation.

### Initialization

```swift
init(scene: SKScene, gridNode: SKNode, horizonY: CGFloat = SharedBackground.conveyorHorizonY)
```

- `gridNode`: Node returned by `SharedBackground.addPerspectiveGrid()`, lines are added here

### Methods

- `start()` — Aligns to GlobalBeatTimer and pre-populates visible lines
- `update()` — Called each frame to spawn new lines and animate existing ones

### Behavior

- Lines spawn at the beat (BPM from GlobalBeatTimer, default 100)
- Perspective projection moves lines from center toward horizon
- Beat pulse effect brightens lines on spawn

## ButtonFactory

**File**: `UI/ButtonFactory.swift`

Factory for creating consistent button components.

### Button Creation

- `createButton(text: String, name: String, width: CGFloat) -> SKNode` — Standard button with button.png
- `createSquareButton(iconName: String, name: String, size: CGFloat) -> SKNode` — Square button with icon
- `createBackButton(name: String) -> SKNode` — Back button with arrow icon

### Animations

- `addPulseAnimation(to: SKNode)` — Subtle idle pulse (1.0 ↔ 1.03 scale)
- `animatePress(_ node: SKNode)` — Scale to 0.95 on touch
- `animateRelease(_ node: SKNode)` — Scale back to 1.0

### Icon Paths

- `backArrowPath() -> CGPath` — Left-pointing arrow
- `caretPath(pointingDown: Bool) -> CGPath` — Dropdown caret

## ShaderFactory

**File**: `UI/ShaderFactory.swift`

Creates hue-shift shaders for difficulty-colored buttons.

### Methods

- `createHueShiftShader(hueShift: Float) -> SKShader` — Raw hue shift in radians
- `createHueShiftShader(for: DifficultyLevel) -> SKShader` — Preset shifts for difficulty colors

### DifficultyLevel Extension

```swift
extension DifficultyLevel {
    var color: SKColor { ... }  // Green (easy), Yellow (medium), Red (hard)
}
```

## ParticleFactory

**File**: `UI/ParticleFactory.swift`

Creates particle effects for buttons and UI elements.

### Methods

- `addButtonSparkles(to: SKNode, buttonSize: CGSize)` — Full sparkle effect (4 emitters: stars, flares, twinkles)
- `addLogoSparkles(to: SKNode, size: CGSize)` — Effect for logo nodes
- `addSmallButtonSparkles(to: SKNode, buttonSize: CGSize)` — Lighter effect for secondary buttons

## LayoutConstants and iPad Compatibility

Beat Kanji uses a centralized `LayoutConstants` to keep UI consistent across devices.

- On iPad, menu panels use a fixed width (currently `380pt`) via `LayoutConstants.menuWidth` and are centered; this avoids overly wide menus.
- Fonts, button sizes, and list item heights are fixed and not percentage-scaled on iPad.
- For list/background assets (e.g., `menu-collapsed`, `menu-expanded-*`), prefer non-uniform scaling:
  - `xScale = targetWidth / sprite.size.width`
  - `yScale = contentHeight / sprite.size.height`
- The `CheckboxListComponent` and scene menus should compute their content height explicitly (headers + visible items) and scale backgrounds accordingly.

See `doc/ipad-layout.md` for detailed patterns and a checklist.

## Usage Examples

### Scene with Background + Conveyor Belt

```swift
override func didMove(to view: SKView) {
    SharedBackground.addBackground(to: self)
    let gridNode = SharedBackground.addPerspectiveGrid(to: self)

    conveyorBeltManager = ConveyorBeltManager(scene: self, gridNode: gridNode)
    conveyorBeltManager?.start()
}

override func update(_ currentTime: TimeInterval) {
    GlobalBeatTimer.shared.update(systemTime: currentTime)
    conveyorBeltManager?.update()
}
```

### Creating Buttons

```swift
let playButton = ButtonFactory.createButton(text: "Play", name: "playButton")
playButton.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
ButtonFactory.addPulseAnimation(to: playButton)
ParticleFactory.addButtonSparkles(to: playButton, buttonSize: CGSize(width: 200, height: 60))
addChild(playButton)
```

### Difficulty-Colored Button

```swift
let buttonBg = SKSpriteNode(imageNamed: "button")
buttonBg.shader = ShaderFactory.createHueShiftShader(for: .easy)
label.fontColor = DifficultyLevel.easy.color
```
