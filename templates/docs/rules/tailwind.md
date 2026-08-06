---
id: tailwind
title: Tailwind — semantic colors, dark mode, responsive
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim", "app/components/**/*.rb"]
triggers: ["tailwind", "colors", "semantic color", "dark mode", "dark:", "responsive", "breakpoint", "sm:", "lg:", "mobile first", "palette"]
see_also: ["tailwind-build", "components", "accessibility"]
tokens: 300
---

# Tailwind

## Semantic colors

| Purpose | Class | Use |
|---|---|---|
| Primary | `blue-500` | Primary actions, links |
| Success | `green-500` | Confirmations |
| Warning | `yellow-500` | Caution states |
| Danger | `red-500` | Errors, destructive actions |
| Info | `cyan-500` | Informational messages |

Semantic meaning lives in a [component's](components.md) `VARIANTS` hash, not
scattered across templates. When the palette changes, one hash changes.

## Dark mode

Every surface and text color needs its dark counterpart. Miss one and the page is
unreadable in dark mode for exactly the users who never report it.

```slim
.bg-white.dark:bg-gray-800.rounded-lg.shadow.p-6
  h3.text-lg.font-semibold.text-gray-900.dark:text-gray-100 Card title
  p.text-gray-600.dark:text-gray-300 Body copy
```

Contrast must hold in both themes — see [accessibility](accessibility.md).

## Responsive

Mobile-first — unprefixed classes are the small screen, prefixes add up from there.

```slim
.grid.grid-cols-1.sm:grid-cols-2.lg:grid-cols-4.gap-4
```

| Prefix | Min width | Target |
|---|---|---|
| `sm:` | 640px | Tablet portrait |
| `md:` | 768px | Tablet landscape |
| `lg:` | 1024px | Desktop |
| `xl:` | 1280px | Large desktop |

Classes assembled at runtime do not survive the build — [tailwind-build](tailwind-build.md).
Bracket values need `class=""` in Slim — [slim-gotchas](slim-gotchas.md).
