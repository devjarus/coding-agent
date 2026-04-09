# Visual Design Rules

## Semantic Colors

```swift
// CORRECT — adapts to light/dark automatically
Text("Title").foregroundStyle(.primary)
Text("Subtitle").foregroundStyle(.secondary)
Rectangle().fill(.background)
Divider()

// WRONG — hardcoded colors break dark mode
Text("Title").foregroundColor(Color(hex: "#333333"))
```

| Semantic | Light Mode | Dark Mode |
|----------|-----------|-----------|
| `.primary` | Black | White |
| `.secondary` | Gray | Light gray |
| `.background` | White | Near-black |
| `.accentColor` | System blue | System blue |

- Use Asset Catalog colors for brand colors — define both light/dark variants
- `.tint()` to override accent color per-view

## SF Symbols

```swift
// Basic usage
Image(systemName: "star.fill")

// Hierarchical rendering — multi-color depth
Image(systemName: "folder.badge.plus")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.blue)

// Variable value (iOS 16+)
Image(systemName: "speaker.wave.3", variableValue: volume)
```

- Use SF Symbols as primary icon system — 5000+ icons, all sizes
- Hierarchical rendering for subtle depth
- `.symbolEffect` for animated symbols (iOS 17+)
- Check SF Symbols app for available icons and variants

## Typography

```swift
// CORRECT — semantic fonts that scale with Dynamic Type
Text("Heading").font(.title)
Text("Body").font(.body)
Text("Caption").font(.caption)

// Custom weight with semantic size
Text("Bold Body").font(.body.bold())

// WRONG — fixed sizes don't scale
Text("Heading").font(.system(size: 24))
```

| Semantic | Default Size | Use For |
|----------|-------------|---------|
| `.largeTitle` | 34pt | Screen titles |
| `.title` | 28pt | Section headers |
| `.title2` | 22pt | Subsections |
| `.headline` | 17pt bold | List row titles |
| `.body` | 17pt | Primary content |
| `.callout` | 16pt | Secondary content |
| `.caption` | 12pt | Timestamps, metadata |

## Materials and Depth

```swift
// Background blur
.background(.ultraThinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)

// Shadows
.shadow(color: .black.opacity(0.1), radius: 8, y: 4)

// Corner radius
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

## Safe Areas

```swift
// CORRECT — respect safe areas (default)
VStack { ... }

// Extend into safe area when intentional
Image("hero")
    .ignoresSafeArea(.container, edges: .top)

// WRONG — hardcoded padding for notch
VStack { ... }
    .padding(.top, 44)  // breaks on different devices
```

## iPad Considerations

- Use `@Environment(\.horizontalSizeClass)` for adaptive layouts
- Compact: single column. Regular: sidebar + detail
- NavigationSplitView for master-detail on iPad
- Support multitasking: Slide Over, Split View, Stage Manager
- Test at all split ratios
