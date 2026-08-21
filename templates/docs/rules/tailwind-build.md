---
id: tailwind-build
title: Only literal class names survive the Tailwind build
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim", "app/components/**/*.rb", "app/javascript/**/*.js", "app/helpers/**/*.rb"]
triggers: ["class missing", "style not applied", "purged", "dynamic class", "text-#{", "interpolated class", "tailwind not working", "class string in JS"]
see_also: ["slim-gotchas", "registries"]
tokens: 330
---

# Only literal class names survive the build

Tailwind scans source text. A class assembled at runtime does not exist in the CSS,
and the failure is silent — the element renders with no styling.

```slim
/ BAD — text-green-500 is never generated
- div class="text-#{status}-500"

/ GOOD — full class names appear literally in the source
- STATUS_CLASSES = { ok: "text-green-500", failed: "text-red-500" }
- div class=STATUS_CLASSES[status]
```

Two consequences that catch people:

- **Variants belong in a frozen hash** on the component, not a chain of string
  interpolation. Same reason [registries](registries.md) exist.
- **No Tailwind class strings in JavaScript.** Pass them to a Stimulus controller
  as `static classes` so the compiler sees them in the template. Classes present
  only in a `.js` file get purged.
