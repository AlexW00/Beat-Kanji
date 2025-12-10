# Liquid Glass in SwiftUI — cheat sheet

### What Liquid Glass is

* Dynamic material that blurs background, reflects nearby color/light, and reacts to touch/pointer in real time.
* Built into many system SwiftUI components; you can apply it to custom views.

---

## 1) Apply Liquid Glass to a single view

### Default

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect()
```

* Uses `Glass.regular`
* Shape defaults to a **capsule** behind the content.

### Custom shape

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(in: .rect(cornerRadius: 16))
```

* Use a shape that fits the component (rounded rect, circle, etc.).

### Tint + interactivity

```swift
Text("Hello, World!")
    .font(.title)
    .padding()
    .glassEffect(.regular.tint(.orange).interactive())
```

* `tint(...)` suggests prominence / category.
* `interactive()` makes your custom view respond like system glass buttons.

### Ordering rule

* `glassEffect` **captures** the view’s rendered content for glass.
* Put `glassEffect(...)` **after** modifiers that change appearance (font, padding, background, etc.).

---

## 2) Combine multiple glass views

### Use a container for performance + blending/morphing

```swift
GlassEffectContainer(spacing: 40) {
    HStack(spacing: 40) {
        Image(systemName: "scribble.variable")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()

        Image(systemName: "eraser.fill")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()
            .offset(x: -40)
    }
}
```

**Why container matters**

* Best rendering performance when many glass views exist.
* Glass shapes can **blend** when near each other.
* Shapes can **morph** during transitions.

### Spacing mental model

* Container `spacing` controls *when* shapes merge/morph.
* Larger spacing → shapes merge earlier during movement.
* If container spacing is **larger than** internal layout spacing, shapes may blend even at rest.
* Animating views in/out changes geometry → fluid merge/split.

---

## 3) Force multiple views into one unified glass shape

Use when you want a single capsule across multiple items, even at rest.

```swift
@Namespace private var namespace
let symbolSet = ["cloud.bolt.rain.fill", "sun.rain.fill",
                 "moon.stars.fill", "moon.fill"]

GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        ForEach(symbolSet.indices, id: \.self) { i in
            Image(systemName: symbolSet[i])
                .frame(width: 80, height: 80)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectUnion(id: i < 2 ? "1" : "2",
                                  namespace: namespace)
        }
    }
}
```

Notes:

* All glass views with same **shape + effect + union id** blend into one.
* Useful for dynamically generated views or views not sharing a layout container.

---

## 4) Morph glass shapes during transitions

### Matched morphing via IDs

```swift
@State private var isExpanded = false
@Namespace private var namespace

var body: some View {
    GlassEffectContainer(spacing: 40) {
        HStack(spacing: 40) {
            Image(systemName: "scribble.variable")
                .frame(width: 80, height: 80)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectID("pencil", in: namespace)

            if isExpanded {
                Image(systemName: "eraser.fill")
                    .frame(width: 80, height: 80)
                    .font(.system(size: 36))
                    .glassEffect()
                    .glassEffectID("eraser", in: namespace)
            }
        }
    }

    Button("Toggle") {
        withAnimation { isExpanded.toggle() }
    }
    .buttonStyle(.glass)
}
```

### Transition types

* Default inside container spacing: `GlassEffectTransition.matchedGeometry`
* For simpler or custom transitions:

  * use `.glassEffectTransition(.materialize)`
  * wrap changes in `withAnimation { ... }`
* Use `materialize` when views are farther apart than container spacing.

Rules:

* Provide stable IDs via `glassEffectID(_:in:)` within a `Namespace`.
* `glassEffectID` and `glassEffectTransition` only matter during hierarchy changes / animations.

---

## 5) Performance rules

* Avoid many containers and many glass views outside containers.
* Limit total simultaneous glass effects on screen.
* Prefer grouping glass elements into fewer `GlassEffectContainer`s.

---

## API quick list

* `glassEffect(_ glass: Glass = .regular, in shape: some Shape = Capsule())`
* `Glass.regular`, `.tint(Color)`, `.interactive(Bool = true)`
* `GlassEffectContainer(spacing: CGFloat)`
* `glassEffectUnion(id: String, namespace: Namespace.ID)`
* `glassEffectID(_ id: String, in: Namespace.ID)`
* `glassEffectTransition(_ transition: GlassEffectTransition)`
* `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for standard button visuals

---

## Practical patterns

* **Custom glass HUD/button**: build view → style it → `glassEffect(...).interactive()`
* **Toolbar clusters / morphing buttons**: put items in one `GlassEffectContainer`, tune spacing, assign `glassEffectID`s.
* **Dynamic rows of pills**: apply `glassEffectUnion` per group to form shared capsules.
* **Keep glass last in modifier chain** to ensure correct capture.
