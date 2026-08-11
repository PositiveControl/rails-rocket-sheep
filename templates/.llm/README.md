# Documentation Index

The map of this repo's committed documentation. Agents read this first to find
what already exists — before writing a new doc that duplicates one.

**Rules**

- Index **committed docs only**. `.llm/tasks/` and `.llm/threads/` are local
  scratch and never appear here.
- `/feature_plan` adds placeholder entries. `/pr_submit` completes or deletes
  them and re-checks this index for duplicates and dead links.
- Never merge a PR that leaves a `Status: Draft` placeholder listed here.
- One line per doc: link plus a short description of what question it answers.

---

## Plans — `docs/plans/`

Design docs for features. Written before issues are created, approved at gate G1.

<!-- plans:start -->
*None yet.*
<!-- plans:end -->

## Rules — `docs/rules/`

One convention per file, with `applies_to` globs and `trigger` keywords in
frontmatter. Not a narrative — a lookup table.

- [Rule index](../docs/rules/INDEX.md) — routes by file path, by symptom, or by rule id

Read the index and then only the rules it points to. This directory is not
indexed line-by-line here on purpose; the index is the index.

## System — `docs/system/`

How things currently work. Architecture state, not intentions.

<!-- system:start -->
- [Architecture Decision Records](../docs/system/architecture.md) — decisions taken and their consequences
- [Models](../docs/system/models.md) — model reference
- [Invariant drift](../docs/system/invariant-drift.md) — why a rule that must hold on many paths holds on only some, and how to catch it
<!-- system:end -->

## SOP — `docs/sop/`

Procedures somebody will need to repeat.

<!-- sop:start -->
- [Add SEO to a page](../docs/sop/add-seo-to-a-page.md) — meta tags, canonical URLs, JSON-LD, sitemap entry
- [Harden a Kamal server](../docs/sop/harden-a-kamal-server.md) — firewall, SSH, unattended upgrades after `kamal setup`
- [Extract database and storage](../docs/sop/extract-database-and-storage.md) — move PostgreSQL and Active Storage off the app server
- [Set up the beads tracker tier](../docs/sop/beads-setup.md) — only if `/workflow_setup` chose tier `beads`
<!-- sop:end -->

## QA — `docs/qa/`

Manual test guides. Written by `/pr_qa` for flows that automated tests don't cover.

<!-- qa:start -->
*None yet.*
<!-- qa:end -->

---

## Conventions

Coding conventions are one rule per file in `docs/rules/`, routed by
`docs/rules/INDEX.md`. `CLAUDE.md` at the repo root carries the non-negotiables
in one line each and links out. Docs here describe *this system*; they never
restate conventions.

Workflow lifecycle, gates, and sizing rules: `WORKFLOW.md`.
