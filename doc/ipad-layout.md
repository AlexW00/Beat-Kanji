# iPad Layout Guide

This guide captures the lessons learned while making Beat Kanji’s menus look good on iPad. The core principle: treat iPad like a wider canvas but keep menu UI sized like iPhone. Use fixed widths and non-uniform background scaling so assets remain visually correct while content fits.

## Principles

- **Fixed Menu Width on iPad:** Use a capped width (currently `380pt`) for menu panels; center them on screen. Do not stretch to the iPad’s full width.
- **Non-Uniform Background Scaling:** Many menu background assets (e.g., `menu-collapsed`, `menu-expanded-mid`) are designed to stretch differently in X and Y. Compute `xScale` from target width and `yScale` from desired content height.
- **iPhone-Like Sizing:** Keep font sizes, button sizes, and item heights roughly identical across iPhone and iPad. This preserves composition and reduces distortion.
- **Content-Determined Height:** Derive vertical size from content (headers + visible items) rather than proportional scaling of the asset.

## Implementation Pattern

Use `LayoutConstants` as the single source of truth for dimensions.

```swift
// Width: capped on iPad, percentage on iPhone
let layout = LayoutConstants.shared
let width = layout.menuWidth

// Background scaling (non-uniform)
let bg = SKSpriteNode(imageNamed: "menu-expanded-mid")
let contentHeight = headerHeight + CGFloat(visibleItems) * itemHeight
let bgScaleX = width / bg.size.width
let bgScaleY = contentHeight / bg.size.height
bg.xScale = bgScaleX
bg.yScale = bgScaleY
bg.position = CGPoint(x: centerX, y: -contentHeight / 2)
```

## LayoutConstants

- `maxMenuWidth`: 380 on iPad
- `menuWidth`: returns fixed `maxMenuWidth` on iPad, `size.width * 0.85` on iPhone
- Fixed sizes for fonts and controls: title/header/body font sizes, `squareButtonSize`, `standardButtonWidth`, `listHeaderHeight`, `listItemHeight`, `checkboxSize`, `paginationBottomOffset`

## Scene-Specific Guidance

- **SettingsScene:** For category panels (Sound/Display/About), compute `bgScaleX` from `menuWidth` and `bgScaleY` from fixed content heights (`tallCategoryHeight` or `standardCategoryHeight`). Position content using fixed pixel offsets.
- **SongSelectScene:**
  - Collapsed pack: non-uniform scale background to `width` × `collapsedMenuHeight`.
  - Expanded pack: non-uniform scale to `width` × `(expandedHeaderHeight + visibleItems * itemHeight)`. Align header and list within this area. Use a clip/crop node for scrolling if needed.
- **SongDetailScene:** Use `CheckboxListComponent` for category lists. Maintain fixed item heights and header height; keep overall width limited via `menuWidth`. Avoid proportionally scaling backgrounds to determine height.
- **TutorialScene:** Use capped width for the large panel (`menu-expanded-super-big`) and center it; uniform scaling is fine for decorative, non-list panels.

## CheckboxListComponent

- Prefer content-driven height. For small fixed lists (`menu-expanded-small`), non-scrolling visible area equals `totalHeight - headerHeight`.
- For mid/scrollable lists (`menu-expanded-mid`), use crop nodes for scroll content. Background uses non-uniform scaling to match width and computed content height.

## Asset Usage Notes

- Backgrounds (`menu-collapsed`, `menu-expanded-…`) are designed for stretch in both axes. Always compute `xScale` and `yScale` separately.
- Dots separators (`dots`) scale proportionally to a fraction of menu width; keep alpha and positional offsets constant.

## Checklist (for new/updated scenes)

- Use `LayoutConstants.configure(for: scene.size)` at scene load.
- Use `layout.menuWidth` for panel width and center X.
- Compute `contentHeight` from headers + item counts.
- Apply **non-uniform scaling**: `xScale = width / sprite.size.width`, `yScale = contentHeight / sprite.size.height`.
- Position backgrounds at `y: -contentHeight/2` when building from top-down.
- Keep fonts/buttons/item heights fixed (don’t scale by percent on iPad).
- Test on iPhone and iPad; verify no overlaps and adequate padding.

## Common Pitfalls

- Uniform `setScale` on list backgrounds causes content overflow/underflow on iPad.
- Deriving height from uniformly scaled asset instead of explicit content measurements leads to misalignment.
- Using percentage-based width on iPad makes panels too wide and breaks composition.
