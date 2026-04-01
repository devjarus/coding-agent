# UI Design Rules

## DES-01: Visual Hierarchy (CRITICAL)

Every screen needs a clear hierarchy: one primary focal point, supporting secondary elements, and de-emphasized tertiary content.

- Headings noticeably larger/bolder than body text (at least 1.5x size difference)
- Primary actions visually dominant: filled buttons, high contrast, larger size
- Secondary actions subdued: outlined or ghost buttons, lower contrast
- Use size, weight, color, and spacing together -- not just one property
- Empty states and loading states deserve design attention

**Anti-patterns:** Everything same size/weight, multiple competing primary buttons, color-only distinction.

## DES-02: Spacing and Rhythm (CRITICAL)

- Use 4px or 8px base unit (Tailwind default scale works well)
- Group related elements with tight spacing (gap-2 to gap-4)
- Separate sections with generous spacing (gap-8 to gap-16)
- Padding proportional to container size
- Vertical rhythm: consistent spacing between repeated elements

```
// Card with good internal rhythm
p-6 space-y-4
// Section separation
mt-12 pt-8 border-t
// Tight grouping
gap-2
```

**Anti-patterns:** Cramped layouts (p-1, p-2 on major containers), inconsistent gaps, no breathing room.

## DES-03: Color Usage (CRITICAL)

- Limit palette: 1 primary brand color, 1-2 accents, neutrals for text/backgrounds/borders
- Color conveys meaning: success (green), error (red), warning (amber), info (blue)
- Background hierarchy: gray-50 page, white cards, gray-100 hover states
- Dark mode: dark surfaces (gray-900, gray-800) with reduced-brightness text
- Accent colors appear sparingly

```
// Light mode surface hierarchy
bg-gray-50    // page
bg-white      // card
bg-gray-100   // hover

// Dark mode
dark:bg-gray-950    // page
dark:bg-gray-900    // card
dark:bg-gray-800    // hover

// Text hierarchy
text-gray-900 dark:text-gray-100    // primary
text-gray-600 dark:text-gray-400    // secondary
text-gray-400 dark:text-gray-600    // muted
```

**Anti-patterns:** Rainbow of colors, pure #000 on #fff, colored backgrounds competing for attention.

## DES-04: Typography (HIGH)

- 2 font sizes for body, 2-3 for headings
- Line height: 1.5 body, 1.2-1.3 headings
- Max line length: 65-75 characters (max-w-prose)
- Weight hierarchy: regular (400) body, medium (500) labels, semibold/bold (600-700) headings
- Use tracking on all-caps text

**Anti-patterns:** >4 distinct sizes per screen, full-width text, everything bold.

## DES-05: Component Polish (HIGH)

- Border radius: one consistent radius everywhere (rounded-lg cards, rounded-md inputs)
- Shadows: sparingly for elevation (shadow-sm cards, shadow-lg modals)
- Transitions: subtle on interactive states (transition-colors duration-150)
- Icons: consistent set (Lucide, Heroicons), sized to match adjacent text
- Borders: subtle (border-gray-200 dark:border-gray-700)
- Hover/active states on every clickable element

**Anti-patterns:** Mixed radii, heavy shadows everywhere, no hover states, mixed icon families.

## DES-06: Layout Patterns (HIGH)

```
// Dashboard: sidebar + main
<div className="flex h-screen">
  <aside className="w-64 border-r bg-gray-50 dark:bg-gray-900 p-4">
  <main className="flex-1 overflow-y-auto p-6">
</div>

// Card grid
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">

// Content page
<div className="mx-auto max-w-3xl px-4 py-8">

// Form
<form className="space-y-6 max-w-lg">
  <div className="space-y-2">
    <label className="text-sm font-medium">
    <input className="w-full rounded-md border px-3 py-2" />
```

## DES-07: Empty States and Edge Cases (MEDIUM)

- Empty states: illustration/icon + clear message + CTA
- Loading: skeleton screens over spinners for page loads
- Error states: explain what happened + retry action
- Zero-data: distinguish "no data yet" from "no results found"

## DES-08: Design References (MEDIUM)

| UI Type | Reference |
|---------|-----------|
| Dashboard | Linear, Vercel Dashboard, Stripe Dashboard |
| Chat interface | ChatGPT, Claude.ai, Slack |
| Email client | Superhuman, Gmail |
| Task manager | Linear, Todoist, Notion |
| Settings page | Stripe settings, GitHub settings |
| Documentation | Stripe Docs, Tailwind Docs |
| Landing page | Vercel, Linear, Stripe |
