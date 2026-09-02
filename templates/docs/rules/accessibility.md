---
id: accessibility
title: Accessibility — non-negotiable, cheap when done as you go
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim", "app/javascript/controllers/**/*.js"]
triggers: ["accessibility", "a11y", "aria", "aria-label", "contrast", "keyboard", "screen reader", "focus", "outline: none", "clickable div", "semantic HTML", "label for"]
see_also: ["tailwind", "forms-ui", "components"]
modes: [ web ]
tokens: 300
current_state: matches
---

# Accessibility

Non-negotiable, and cheap when done as you go:

- **Semantic HTML** — `button` for actions, `a` for navigation. A clickable `div`
  is invisible to keyboard and screen reader users.
- **`aria-label` on icon-only buttons.**
- **4.5:1 contrast minimum** — check both themes. Dark mode is where this slips;
  see [tailwind](tailwind.md).
- **Every interactive element reachable and operable by keyboard.** ESC closes
  modals (`modal_controller.js` handles this).
- **Focus stays visible.** Never `outline: none` without a replacement.
- **Form inputs have a `label` with a matching `for`**, not just a placeholder —
  see [forms-ui](forms-ui.md).
