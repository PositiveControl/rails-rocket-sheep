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
- [QA walkthroughs](../docs/system/qa_walkthrough.md) — the reviewer script per change, and how to run one
- [Autopilot](../docs/system/autopilot.md) — how an approved feature runs itself: log template, driver, guard
- [Autopilot — what a step reads](../docs/system/autopilot-steps.md) — activation, policy by gate id, log entries, whose comment is whose, halt
- [Workflow usage](../docs/system/workflow-usage.md) — what an autopilot step costs, and the cache TTL settings
- [Workflow optimizations](../docs/system/workflow-optimizations.md) — each change made to cut cost and time, and how to see its effect
<!-- system:end -->

## ADRs — `docs/adr/`

One decision per file, numbered. *Why* a rule exists and what was accepted for it.
Written by `/domain_model`.

<!-- adr:start -->
- [Rails 8 Solid Stack](../docs/adr/0001-rails-8-solid-stack.md) — database-backed jobs, cache, and cable instead of Redis
- [Primary Keys Follow the Database](../docs/adr/0002-primary-keys-follow-the-database.md) — UUIDs on PostgreSQL, bigints on MySQL, and what each costs
- [Service Object Pattern](../docs/adr/0003-service-object-pattern.md) — where business logic lives, and the Result it returns
- [Real Deletes by Default, Discard Opt-In](../docs/adr/0004-real-deletes-by-default-discard-opt-in.md) — when a model earns soft deletion
- [Slim Templates](../docs/adr/0005-slim-templates.md) — why views are Slim and never ERB
- [ViewComponent for UI Units](../docs/adr/0006-viewcomponent-for-ui-units.md) — the component/partial line
- [Pattern Budget](../docs/adr/0007-pattern-budget.md) — the six sanctioned directories, and what a seventh costs
- [Registries as `Data` Objects](../docs/adr/0008-registries-as-data-objects.md) — fixed variant sets without a base class
- [Slices Merge on the Agent's Review, Features on a Human's](../docs/adr/0014-slices-merge-on-the-agents-review-features-on-a-humans.md) — where the human reads, and why a fresh session reviews a slice
- [An Accepted Design May Run Itself](../docs/adr/0016-an-accepted-design-may-run-itself.md) — autopilot: consent and policy at G1, a driver between slices, the autopilot log for the feature-PR reviewer
<!-- adr:end -->

## SOP — `docs/sop/`

Procedures somebody will need to repeat.

<!-- sop:start -->
- [Add SEO to a page](../docs/sop/add-seo-to-a-page.md) — meta tags, canonical URLs, JSON-LD, sitemap entry (web mode)
- [Add an endpoint](../docs/sop/add-an-endpoint.md) — route, request test, contract, filter, policy, service, serializer, controller, regenerate (API mode)
- [Harden a Kamal server](../docs/sop/harden-a-kamal-server.md) — firewall, SSH, unattended upgrades after `kamal setup`
- [Extract database and storage](../docs/sop/extract-database-and-storage.md) — move the database and Active Storage off the app server
- [Set up the beads tracker tier](../docs/sop/beads-setup.md) — only if `/workflow_setup` chose tier `beads`
- [Find slow tests](../docs/sop/find-slow-tests.md) — read the Slowpoke report and act on it
- [Update from the template](../docs/sop/update-from-the-template.md) — three-way merge the alignment layer against a newer template
- [Run a feature on autopilot](../docs/sop/run-a-feature-on-autopilot.md) — set up, start, watch, resume, finish, read the log, and abort an autopilot run
<!-- sop:end -->

## QA — `docs/qa/`

Manual test guides. Written by `/pr_qa` for flows that automated tests don't cover.

<!-- qa:start -->
- [Autopilot report template](../docs/qa/autopilot-report-template.md) — copy after a feature's first autopilot run, to judge the workflow by numbers
<!-- qa:end -->

---

## Conventions

Coding conventions are one rule per file in `docs/rules/`, routed by
`docs/rules/INDEX.md`. `CLAUDE.md` at the repo root carries the non-negotiables
in one line each and links out. Docs here describe *this system*; they never
restate conventions.

Workflow lifecycle, gates, and sizing rules: `WORKFLOW.md`.
