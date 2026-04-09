# Navigation Rules

## NavigationStack (iOS 16+)

```swift
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .navigationTitle("Items")
        }
    }
}
```

- Use value-based `NavigationLink` — not the deprecated view-based variant
- `.navigationDestination` registers destination views by type
- `NavigationPath` for programmatic navigation and deep linking
- Values must conform to `Hashable`

## TabView

```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
    }
    Tab("Search", systemImage: "magnifyingglass") {
        SearchView()
    }
    Tab("Profile", systemImage: "person") {
        ProfileView()
    }
}
```

- iOS 18+: use `Tab` views with labels
- Pre-iOS 18: use `.tabItem { Label("Home", systemImage: "house") }` with `.tag`
- Each tab typically owns its own NavigationStack

## Sheets and Modals

```swift
// Item-based presentation (preferred)
.sheet(item: $selectedItem) { item in
    DetailView(item: item)
}

// Boolean-based presentation
.sheet(isPresented: $showSettings) {
    SettingsView()
}

// Full screen cover
.fullScreenCover(isPresented: $showOnboarding) {
    OnboardingView()
}
```

- Prefer item-based presentation — automatically dismisses when nil
- Use `@Environment(\.dismiss)` inside sheets for programmatic dismissal
- Avoid passing too many bindings into sheets — pass the data model

## Deep Linking

```swift
// Restore navigation state
@SceneStorage("navigationPath") private var pathData: Data?

// Encode/decode NavigationPath for state preservation
func save() {
    pathData = try? JSONEncoder().encode(path.codable)
}
```
