# Documentation Index

The map of this repo's committed documentation. Agents read this first to find
what already exists — before writing a new doc that duplicates one.

This is the template repo, not an app (`CLAUDE.md`, *Dogfood layer*): the
shipped docs live under `templates/`, so the sections below point there. This
index is kept by hand; `bin/dogfood-sync` never writes it.

**Rules**

- Index **committed docs only**. `.llm/tasks/` and `.llm/threads/` are local
  scratch and never appear here.
- `/feature_plan` adds plan entries. `/pr_submit` re-checks this index for
  duplicates and dead links.
- One line per doc: link plus a short description of what question it answers.

---

## Plans — `docs/plans/`

Design docs for features. Written before issues are created, approved at gate G1.

<!-- plans:start -->
- [2026-10-03-autopilot-backport-design.md](../docs/plans/2026-10-03-autopilot-backport-design.md) — porting autopilot from an adopting app (#55); shipped in #63
- [2026-10-04-round-trip-design.md](../docs/plans/2026-10-04-round-trip-design.md) — adopter fixes (#56–#58) and `bin/rocket-sheep-backport` (#59); approved at G1, autopilot on
- [2026-10-04-round-trip-autopilot.md](../docs/plans/2026-10-04-round-trip-autopilot.md) — its autopilot log; policy accepted at G1
<!-- plans:end -->

## QA — `docs/qa/`

<!-- qa:start -->
- [Autopilot report template](../docs/qa/autopilot-report-template.md) — rendered from `templates/`; the shape of a run's QA report
<!-- qa:end -->

## Where the rest lives

- **Rules shipped to apps** — [templates/docs/rules/INDEX.md](../templates/docs/rules/INDEX.md). This repo is not a Rails app; they apply to `templates/app/` and the like.
- **System docs shipped to apps** — [templates/docs/system/](../templates/docs/system/), autopilot's spec included.
- **SOPs shipped to apps** — [templates/docs/sop/](../templates/docs/sop/).
- **Decisions** — about this generator: [.agents/adr/](../.agents/adr/); about a generated app: [templates/docs/adr/](../templates/docs/adr/). The two number separately, so both have a 0016: match on the filename.
- **Requests already declined** — [.agents/out-of-scope/](../.agents/out-of-scope/).
- **Buyer-facing product docs** — [docs/](../docs/), with what's shipped and what's next in [docs/inventory.md](../docs/inventory.md).

Workflow lifecycle, gates, and sizing rules: `WORKFLOW.md`.
