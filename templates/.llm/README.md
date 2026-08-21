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
- [Models](../docs/system/models.md) — model reference
- [Vocabulary](../docs/system/vocabulary.md) — what each workflow and doc term means here
<!-- system:end -->

## ADRs — `docs/adr/`

One decision per file, numbered. *Why* a rule exists and what was accepted for it.
Written by `/domain_model`.

<!-- adr:start -->
- [Rails 8 Solid Stack](../docs/adr/0001-rails-8-solid-stack.md) — database-backed jobs, cache, and cable instead of Redis
- [UUID Primary Keys](../docs/adr/0002-uuid-primary-keys.md) — why every table's key is a UUID, and what it costs
- [Service Object Pattern](../docs/adr/0003-service-object-pattern.md) — where business logic lives, and the Result it returns
- [Real Deletes by Default, Discard Opt-In](../docs/adr/0004-real-deletes-by-default-discard-opt-in.md) — when a model earns soft deletion
- [Slim Templates](../docs/adr/0005-slim-templates.md) — why views are Slim and never ERB
- [ViewComponent for UI Units](../docs/adr/0006-viewcomponent-for-ui-units.md) — the component/partial line
- [Pattern Budget](../docs/adr/0007-pattern-budget.md) — the six sanctioned directories, and what a seventh costs
- [Registries as `Data` Objects](../docs/adr/0008-registries-as-data-objects.md) — fixed variant sets without a base class
<!-- adr:end -->

## SOP — `docs/sop/`

Procedures somebody will need to repeat.

<!-- sop:start -->
- [Add SEO to a page](../docs/sop/add-seo-to-a-page.md) — meta tags, canonical URLs, JSON-LD, sitemap entry
- [Harden a Kamal server](../docs/sop/harden-a-kamal-server.md) — firewall, SSH, unattended upgrades after `kamal setup`
- [Extract database and storage](../docs/sop/extract-database-and-storage.md) — move PostgreSQL and Active Storage off the app server
- [Set up the beads tracker tier](../docs/sop/beads-setup.md) — only if `/workflow_setup` chose tier `beads`
- [Find slow tests](../docs/sop/find-slow-tests.md) — read the Slowpoke report and act on it
- [Update from the template](../docs/sop/update-from-the-template.md) — three-way merge the alignment layer against a newer template
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
