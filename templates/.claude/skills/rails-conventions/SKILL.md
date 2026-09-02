---
name: rails-conventions
description: "This app's own conventions for Rails code — controllers, services, queries, models, migrations, jobs, tests, and the response boundary. Use before writing or changing any file under app/, db/migrate/, config/, or test/, and whenever a choice about where code goes or what a response looks like comes up. Routes to the one rule file that applies; do not guess a convention."
---

# This app's conventions

Conventions live in `docs/rules/`, one per file. **Do not read them all** — that is
the failure mode this layer exists to prevent.

1. Read `docs/rules/INDEX.md` — that path is from the project root, not from here.
   It routes by the file being edited: a short set that applies to any edit in that
   path, then conditional tables for what the change actually is.
2. Read only the rules it names. Each carries a `tokens:` figure, so the read is
   budgeted before it starts.
3. If the index did not answer — the symptom is known but not the file — the
   fallback is `docs/rules/SYMPTOMS.md`, which holds the symptom table and the full
   annotated list. It costs about twice the index, which is why it is second.

`grep -l "<keyword>" docs/rules/*.md` finds a rule by its `triggers` without loading
anything, and a rule id is always `docs/rules/<id>.md`.

The index is the router, not this file. Nothing here restates a rule, so there is
nothing here to fall out of step with one — and an agent in another harness reaches
the same index by the same route, from `CLAUDE.md` or `AGENTS.md`.

`docs/adr/` says *why* a rule exists. Read it when you want to argue with a rule,
not to follow one.
