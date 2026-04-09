---
name: ios-swiftui-specialist
description: iOS and SwiftUI specialist knowledge — SwiftUI view composition, state management (@State/@Observable/@Bindable), NavigationStack, SF Symbols, Apple HIG compliance, Swift concurrency, accessibility, and testing with XCTest/Swift Testing.
---

# iOS & SwiftUI Specialist

Deep expertise in native iOS development with SwiftUI, following Apple Human Interface Guidelines and modern Swift patterns.

## When to Apply

- Building iOS/iPadOS apps with SwiftUI
- Implementing navigation (NavigationStack, TabView)
- Managing state with @State, @Observable, @Bindable, @Environment
- Working with SF Symbols, Dynamic Type, semantic colors
- Writing tests with XCTest or Swift Testing framework
- Optimizing SwiftUI view performance and diffing
- Ensuring VoiceOver and accessibility compliance

## Core Principles

- **Clarity** — legible content, precise icons, subtle ornamentation
- **Deference** — UI enhances content comprehension without competing
- **Depth** — visual hierarchy through layering and motion

## State Management (rules/state-management.md)

- `@State` must be `private` — view-owned value types only
- `@Binding` only where child needs to modify parent state
- Never declare passed values as `@State` or `@StateObject`
- `@StateObject` for view-owned reference types; `@ObservedObject` for injected
- iOS 17+: prefer `@State` with `@Observable` classes and `@Bindable` for bindings
- `@Environment` for dependency injection (not global state)
- `@SceneStorage` for lightweight state preservation across launches

## View Composition (rules/view-composition.md)

- Stack-based layouts: VStack, HStack, ZStack with explicit spacing/alignment
- LazyVStack/LazyHStack for scrollable content (never eager stacks in ScrollView)
- LazyVGrid/LazyHGrid for grid layouts with adaptive/fixed columns
- Extract views at ~150 lines — prefer small, focused view structs
- ForEach requires stable Hashable identity (never `.indices` for dynamic content)
- Constant view count per ForEach element — no conditional views inside

## Navigation (rules/navigation.md)

- NavigationStack (iOS 16+) with value-based NavigationLink and .navigationDestination
- TabView with explicit .tag values; iOS 18+ tab customization
- Sheets: .sheet/.fullScreenCover with item-based presentation
- Programmatic navigation via NavigationPath for deep linking

## Visual Design (rules/visual-design.md)

- Semantic colors: .primary, .secondary, .background — automatic light/dark
- SF Symbols as primary icon system — use hierarchical rendering
- Dynamic Type: use semantic fonts (.body, .headline, .caption), never fixed sizes
- Materials and blur effects for depth (.ultraThinMaterial, .regularMaterial)
- Safe area respect — never hardcode edge padding
- Design for iPad multitasking: compact/regular size classes

## Accessibility

- Every interactive element needs an accessibility label
- Use .accessibilityHint for non-obvious actions
- Group related content with .accessibilityElement(children: .combine)
- Support Dynamic Type scaling — test at all sizes
- Respect Reduce Motion — check accessibilityReduceMotion for animations
- VoiceOver navigation order must be logical
- Minimum 44x44pt touch targets

## Animation

- `.animation(_:value:)` must include the value parameter
- withAnimation for state-driven transitions
- `.transition()` for view insertion/removal
- matchedGeometryEffect for hero transitions between views
- Respect accessibilityReduceMotion — provide reduced/no animation alternative

## Performance

- Avoid `.fixedSize()` overuse — causes layout instability
- Use `LazyVStack`/`LazyHStack` in `ScrollView` — eager stacks load all children
- Minimize view body complexity — extract computed properties
- Use `EquatableView` or custom Equatable for expensive views
- Avoid closure reference cycles in escaping closures

## Swift Concurrency

- `async`/`await` for all asynchronous work
- `@MainActor` for UI-updating code
- Structured concurrency with TaskGroup for parallel work
- `.task` modifier for view lifecycle-bound async work (auto-cancelled)
- Never block the main thread — use `.task` or Task { } for heavy work

## Testing

- XCTest for unit tests; Swift Testing (`@Test`, `#expect`) for iOS 16+
- ViewInspector or snapshot testing for SwiftUI views
- Test state changes, not view hierarchy
- Mock dependencies via protocol conformance
- UI testing with XCUITest for critical flows

## Common Pitfalls

- Declaring passed values as `@State` (creates independent copy, loses sync)
- Using `List` inside `ScrollView` (nested scrolling)
- Hardcoded colors that break dark mode
- Missing `#available` gating for newer APIs
- `NavigationLink` state issues — values must be `Hashable`
- Memory leaks from captured `self` in closures

## Rules

1. **Follow Apple HIG** — platform conventions over custom patterns
2. **Semantic over literal** — semantic colors, fonts, symbols
3. **Accessibility is required** — VoiceOver, Dynamic Type, Reduce Motion
4. **Test behavior** — state changes and user interactions, not view structure
5. **Gate newer APIs** — `#available` with fallbacks for deployment target
6. **Prefer SwiftUI native** — use UIKit bridging only when SwiftUI can't do it
