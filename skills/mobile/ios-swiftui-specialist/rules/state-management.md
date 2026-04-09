# State Management Rules

## Property Wrapper Selection

| Wrapper | Use When | Scope |
|---------|----------|-------|
| `@State` | View-owned value types, simple toggles/counts | Private to view |
| `@Binding` | Child needs to read AND write parent's state | Passed down |
| `@StateObject` | View creates and owns a reference type (pre-iOS 17) | View lifecycle |
| `@ObservedObject` | Reference type passed from parent (pre-iOS 17) | Injected |
| `@EnvironmentObject` | Shared reference type via environment (pre-iOS 17) | Tree-wide |
| `@Observable` + `@State` | View-owned observable class (iOS 17+) | View lifecycle |
| `@Bindable` | Create bindings to @Observable properties (iOS 17+) | Passed down |
| `@Environment` | System values or custom dependency injection | Tree-wide |
| `@SceneStorage` | Lightweight state preservation across launches | Per scene |
| `@AppStorage` | UserDefaults-backed persistence | App-wide |

## Hard Rules

1. `@State` properties MUST be `private`
2. Never declare a value received from a parent as `@State` — it creates an independent copy
3. Never use `@StateObject` for injected objects — use `@ObservedObject`
4. iOS 17+: prefer `@Observable` over `ObservableObject` — finer-grained updates
5. Use `@Bindable` to create bindings from `@Observable` properties
6. `@Environment(\.dismiss)` for programmatic dismissal — not custom callbacks

## Data Flow Pattern

```swift
// iOS 17+ recommended pattern
@Observable class ViewModel {
    var items: [Item] = []
    var isLoading = false
    
    func fetch() async { ... }
}

struct ParentView: View {
    @State private var viewModel = ViewModel()
    
    var body: some View {
        ChildView(viewModel: viewModel)
            .task { await viewModel.fetch() }
    }
}

struct ChildView: View {
    @Bindable var viewModel: ViewModel
    // Can create $viewModel.items bindings
}
```

## Pre-iOS 17 Pattern

```swift
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}

struct ParentView: View {
    @StateObject private var viewModel = ViewModel() // owns it
    
    var body: some View {
        ChildView(viewModel: viewModel)
    }
}

struct ChildView: View {
    @ObservedObject var viewModel: ViewModel // borrows it
}
```
