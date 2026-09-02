# Slim Templates

**Applies to:** server-rendered mode. An API-only app has no templates, so this
decision is inert there — it keeps its number rather than being renumbered away.

**Status:** Accepted

**Context:**
Needed to choose a templating language.

**Decision:**
Use Slim instead of ERB for all views.

**Consequences:**
- (+) Cleaner, more readable templates
- (+) Enforces proper indentation
- (+) Less visual noise than ERB
- (-) Learning curve for ERB developers
- (-) Some Tailwind syntax requires workarounds (see docs/rules/slim-gotchas.md)
