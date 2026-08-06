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

## System — `docs/system/`

How things currently work. Architecture state, not intentions.

<!-- system:start -->
- [Architecture Decision Records](../docs/system/architecture.md) — decisions taken and their consequences
- [Design Patterns](../docs/system/design-patterns.md) — UI and view patterns
- [Models](../docs/system/models.md) — model reference
<!-- system:end -->

## SOP — `docs/sop/`

Procedures somebody will need to repeat.

<!-- sop:start -->
- [Add SEO to a page](../docs/sop/add-seo-to-a-page.md) — meta tags, canonical URLs, JSON-LD, sitemap entry
- [Harden a Kamal server](../docs/sop/harden-a-kamal-server.md) — firewall, SSH, unattended upgrades after `kamal setup`
- [Extract database and storage](../docs/sop/extract-database-and-storage.md) — move PostgreSQL and Active Storage off the app server
<!-- sop:end -->

## QA — `docs/qa/`

Manual test guides. Written by `/pr_qa` for flows that automated tests don't cover.

<!-- qa:start -->
*None yet.*
<!-- qa:end -->

---

## Conventions

Coding conventions, style, and process rules live in `CLAUDE.md` at the repo
root — the single source. Docs here describe *this system*; they never restate
conventions.

Workflow lifecycle, gates, and sizing rules: `WORKFLOW.md`.
