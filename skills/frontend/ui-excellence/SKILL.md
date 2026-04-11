---
name: ui-excellence
description: Creates polished, distinctive UIs that don't look like generic AI output. Covers visual hierarchy, typography, color systems, spacing, animation, empty states, loading patterns, responsive design, and dark mode. Apply when building any user-facing interface.
---

# UI Excellence

Build interfaces that look designed, not generated. The biggest tell of AI-built UI is sameness — same spacing, same colors, same layout. This skill fights that.

## When to Apply

- Building any user-facing frontend (web, mobile, desktop)
- Reviewing UI for visual quality
- Polishing before shipping

## Visual Hierarchy (rules/hierarchy.md)

Every screen needs a clear reading order. The user's eye should land on the most important thing first.

**Size creates hierarchy:**
```
Page title:     text-3xl font-bold        (largest = most important)
Section header: text-xl font-semibold     (mid = structure)
Body text:      text-base                 (standard = content)
Caption/meta:   text-sm text-muted        (smallest = supporting)
```

**Don't make everything the same size.** If your card title, description, and metadata are all 16px, nothing stands out.

**Contrast creates focus:**
- Primary content: high contrast (`text-foreground`)
- Supporting content: reduced (`text-muted-foreground`)
- Disabled/inactive: lowest (`text-muted-foreground/50`)

## Typography (rules/typography.md)

- **One font family is enough.** System font stack or one Google Font. Two max.
- **Limit to 3-4 sizes per page.** More than that = visual noise.
- **Line height matters:** body text at 1.5-1.75, headings at 1.2.
- **Max line width: 65-75 characters.** Use `max-w-prose` or `max-w-2xl`. Wall-to-wall text is unreadable.
- **Font weight for emphasis, not italic.** Bold a word, don't italicize a paragraph.

## Color (rules/color.md)

**Use a system, not random hex values:**
```css
/* Semantic color tokens — adapt to light/dark automatically */
--background    /* page bg */
--foreground    /* primary text */
--muted         /* subtle bg (cards, code blocks) */
--muted-foreground  /* secondary text */
--primary       /* buttons, links, active states */
--destructive   /* errors, delete actions */
--border        /* dividers, card edges */
```

**Rules:**
- **Max 2 accent colors.** One primary, one for destructive. Everything else is neutral.
- **Don't colorize everything.** Color should draw attention — if everything is colored, nothing is.
- **Dark mode is not just inverted.** Reduce contrast slightly, use darker shadows, softer borders.
- **Test contrast ratios.** 4.5:1 for body text, 3:1 for large text (WCAG AA).

## Spacing (rules/spacing.md)

**Consistent spacing scale:**
```
4px  (1)  — tight: between icon and label
8px  (2)  — compact: between related items
12px (3)  — default: between form fields
16px (4)  — comfortable: between sections
24px (6)  — loose: between major blocks
32px (8)  — spacious: page padding
48px (12) — dramatic: hero sections
```

**Rules:**
- **Related things are closer together.** A label is closer to its input than to the next label.
- **Unrelated things have more space.** Sections need breathing room.
- **Don't eyeball it.** Use the scale. `p-4` not `p-[17px]`.
- **Padding inside, margin outside.** Cards get padding. Gaps between cards use gap/margin.

## Components That Matter (rules/components.md)

### Empty States
Don't show a blank page. Show:
```
┌─────────────────────────────────┐
│                                 │
│         [illustration]          │
│                                 │
│    No projects yet              │
│    Create your first project    │
│    to get started.              │
│                                 │
│    [ Create Project ]           │
│                                 │
└─────────────────────────────────┘
```
- Explain what would be here
- Provide the action to fill it
- Optional: illustration or icon

### Loading States
- **Skeleton screens** over spinners — show the shape of content, not a wheel
- **Inline loading** for buttons — disable + show spinner inside the button
- **Progressive loading** — show what you have, load the rest

### Error States
- **Inline errors** next to the field, not just a toast
- **Explain what went wrong** in human terms, not error codes
- **Offer a fix:** "Try again" button, "Contact support" link
- **Destructive color** for errors (`text-destructive`), not red text on red background

### Forms
- **Labels above inputs** (not placeholder-as-label — it disappears when you type)
- **Group related fields** visually
- **Progressive disclosure** — don't show 20 fields at once
- **Real-time validation** — don't wait for submit to show errors

## Animation (rules/animation.md)

**Purposeful motion only.** Every animation should answer "why does this move?"

- **Transitions:** 150-200ms for hover/focus. 300ms for layout changes. Ease-out, not linear.
- **Enter/exit:** fade + slight translate (8-16px). Not just opacity.
- **Loading:** subtle pulse on skeletons. Not bouncing dots.
- **Feedback:** button press scales down 2% on active. Confirms the click.
- **Reduced motion:** respect `prefers-reduced-motion`. Remove transforms, keep opacity.

```css
/* Good default transition */
transition: all 150ms ease-out;

/* Entrance animation */
@keyframes enter {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

## Responsive (rules/responsive.md)

- **Mobile first.** Default styles are mobile. Add complexity at larger breakpoints.
- **Test at 375px, 768px, 1280px.** Not just "desktop and mobile."
- **Stack on mobile, grid on desktop.** `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`
- **Touch targets: 44x44px minimum.** Buttons, links, interactive elements.
- **No horizontal scroll.** Use `overflow-x-hidden` on body if needed.
- **Hide complexity on mobile.** Sidebar → bottom nav. Table → card list. Multi-column → single.

## Dark Mode (rules/dark-mode.md)

- **Use CSS variables for all colors.** Switch values, not classes.
- **Don't just invert.** Dark backgrounds get lighter borders, softer shadows, slightly reduced contrast.
- **Shadows change direction.** Light mode: shadow down. Dark mode: subtle glow or no shadow.
- **Images may need adjustment.** Consider `brightness(0.9)` or `contrast(1.1)` filter on dark.
- **Test both modes from the start.** Don't add dark mode as an afterthought.

## Anti-Patterns (what makes UI look "AI-generated")

- **Everything centered.** Mix alignments. Left-align body text.
- **All cards look identical.** Vary sizes, add a featured/hero card.
- **No whitespace.** Cramming content = visual noise. Let it breathe.
- **Rainbow gradients.** Subtle gradients only. One color to transparent, or two close hues.
- **Stock placeholder text.** Use realistic data. "John Doe" → "Sarah Chen".
- **Pixel-perfect symmetry everywhere.** Real design has rhythm, not rigid grids.
- **Every section has an icon.** Use icons sparingly for clarity, not decoration.
- **Default shadows on everything.** Shadow = elevation. Only elevated things get shadows.

## Shadcn verification via data-attrs (for HTML-inspection evaluators)

When the evaluator has to fall back to HTML inspection (no Playwright), shadcn components provide stable data-attributes that make presence-verification reliable without a browser. Useful when you need to prove "the Sidebar primitive is actually rendered" from `curl` output alone.

Common data-attributes to grep for:

- **Sidebar:** `data-sidebar="sidebar|header|content|footer|rail|trigger"` and `data-slot="sidebar-wrapper|sidebar-inset|sidebar-container"`
- **Dialog / AlertDialog:** `data-slot="dialog-content|dialog-overlay|dialog-title"` (when open — may require scraping after an interaction)
- **Dropdown / Popover:** `data-slot="dropdown-menu-content"`, `data-state="open|closed"`
- **Tabs:** `data-slot="tabs-list|tabs-trigger|tabs-content"`, `data-state="active|inactive"`
- **Button / Input:** usually class-based (`class="...inline-flex...h-9..."`) rather than data-attr; less reliable for verification

Example fallback verification:

```bash
curl -s http://localhost:3000/ -o /tmp/home.html
grep -c 'data-sidebar="sidebar"' /tmp/home.html           # should be >= 1 if Sidebar rendered
grep -c 'data-slot="sidebar-wrapper"' /tmp/home.html      # should be >= 1
```

This can't verify visual styling or interaction — only structural presence. Pair with explicit "human 30-second eyeball" notes in review.md for pixel-level things (dark mode FOUC, layout, animations).

## Rules

1. **Hierarchy first.** Before styling, ensure the visual order matches importance.
2. **Less is more.** One accent color, one font, consistent spacing scale.
3. **States are required.** Empty, loading, error, success — every component needs all four.
4. **Test at real sizes.** 375px mobile, 768px tablet, 1280px desktop.
5. **Dark mode from day one.** CSS variables, not hardcoded colors.
6. **Motion with purpose.** If you can't explain why it moves, remove it.
