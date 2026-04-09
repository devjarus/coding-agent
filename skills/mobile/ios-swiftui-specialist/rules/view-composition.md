# View Composition Rules

## Layout Selection

| Layout | Use When |
|--------|----------|
| VStack/HStack | Small, fixed number of children |
| LazyVStack/LazyHStack | Scrollable lists of dynamic content |
| LazyVGrid/LazyHGrid | Grid layouts (adaptive or fixed columns) |
| ZStack | Overlapping content, backgrounds, badges |
| ViewThatFits | Adaptive layout that picks first fitting child |
| GeometryReader | Only when you truly need parent dimensions (avoid when possible) |

## ForEach Identity

```swift
// CORRECT — stable Hashable ID
ForEach(items) { item in  // item conforms to Identifiable
    ItemRow(item: item)
}

// CORRECT — explicit key path
ForEach(items, id: \.uniqueId) { item in
    ItemRow(item: item)
}

// WRONG — indices for dynamic content
ForEach(items.indices, id: \.self) { index in  // breaks on insert/delete
    ItemRow(item: items[index])
}
```

## View Extraction

- Extract at ~150 lines per view struct
- Each extracted view should have a clear, single responsibility
- Pass only the data the child needs — not the entire model
- Use `@Binding` only when the child modifies the value

## Conditional Views

```swift
// CORRECT — conditional modifier
Text("Hello")
    .foregroundStyle(isActive ? .primary : .secondary)

// CORRECT — if/else with same view types
if isLoading {
    ProgressView()
} else {
    ContentView()
}

// WRONG — conditional views inside ForEach (changes view count)
ForEach(items) { item in
    ItemRow(item: item)
    if item.hasDetail {  // BAD — inconsistent view count
        DetailRow(item: item)
    }
}
```

## ScrollView Best Practices

```swift
// CORRECT — lazy stack inside ScrollView
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}

// WRONG — eager VStack with many items
ScrollView {
    VStack {  // loads ALL children immediately
        ForEach(thousandsOfItems) { item in
            ItemRow(item: item)
        }
    }
}

// WRONG — List inside ScrollView (nested scrolling)
ScrollView {
    List(items) { item in ... }  // List has its own scroll
}
```
