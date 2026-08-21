# Update Docs

Deep documentation pass: bring `docs/` in step with how the system now works, and leave `.llm/README.md` an honest index of it. Pass a directory to scope the pass, or omit for everything: `/update_docs docs/system` or `/update_docs`.

Use this when behaviour has drifted from what the docs say, or after a run of merges nobody documented. Routine per-PR doc updates belong to `/pr_submit`, which already resolves placeholders for the branch it is landing.

## Instructions

### Step 1: Read the index before writing anything

`.llm/README.md` is the map of committed documentation. Read it first, then read
the docs in scope. The point is to find what already exists — a new doc that
duplicates an existing one is the failure this command prevents.

### Step 2: Establish what actually changed

```bash
git log --oneline -30
git diff HEAD~10 --stat -- app/ config/ db/
```

Look for behaviour that no doc describes: a new model or service, a changed
deploy step, a process somebody had to work out twice, an architectural decision
taken in a PR comment and never recorded.

### Step 3: Place each fact in the directory that owns it

**One fact, one file.** `grep` for the fact before writing it. If it exists, link
to it instead of restating it.

| Directory | Holds | Notes |
|---|---|---|
| `docs/rules/` | One coding convention per file, plus `INDEX.md` | Hand-maintained. Adding a rule means full frontmatter and rows in all three INDEX tables. Never duplicate a rule anywhere else |
| `docs/system/` | How things currently work | `architecture.md` holds ADRs, `models.md` the model reference. State, not intentions |
| `docs/sop/` | Procedures somebody will repeat | Written from a mistake, or from a sequence worked out by hand |
| `docs/plans/` | Design docs for features | Owned by `/feature_plan`. Complete or delete placeholders here, never leave them listed |
| `docs/qa/` | Manual test guides | Owned by `/pr_qa` |

Two boundaries that matter:

- **Rules say what to do; ADRs say why it was chosen.** A convention goes in
  `docs/rules/`; the decision behind it and the cost accepted go in
  `docs/system/architecture.md`. Don't merge the two.
- **Docs describe this system. They never restate conventions.** Conventions are
  single-sourced in `docs/rules/`; everything else links to them.

`.llm/tasks/` and `.llm/threads/` are local scratch and gitignored. Never
document them, and never index them.

### Step 4: Write or update the docs

Prefer editing an existing doc over adding one. Consolidate hard: two files
covering the same ground means one of them becomes a link. Delete a doc whose
subject no longer exists rather than leaving it to mislead.

If `docs/system/` is genuinely empty (an app whose shipped docs were removed),
rebuild the minimum: `architecture.md` for decisions, `models.md` for the model
reference. Do not scaffold beyond what a reader needs now.

### Step 5: Re-sync `.llm/README.md`

The index has marker blocks per directory — `plans`, `system`, `sop`, `qa`. Edit
between the markers, one line per doc: a relative link plus the question that doc
answers.

```markdown
<!-- sop:start -->
- [Add SEO to a page](../docs/sop/add-seo-to-a-page.md) — meta tags, canonical URLs, JSON-LD, sitemap entry
<!-- sop:end -->
```

Then check the index for the two things that rot: dead links, and `Status: Draft`
placeholders still listed. Complete a draft or delete its entry — a PR must never
merge with one listed, and the session-end hook fails the turn if one survives.

`docs/rules/` is not indexed doc by doc, on purpose. Link `INDEX.md` and stop;
the index is the index.

### Step 6: Report

State what you changed, what you consolidated or deleted and why, and anything
you found that needs a decision rather than a doc (that is an ADR, or an issue).

## Reference
- Doc index: `.llm/README.md` — committed docs only, marker blocks per directory
- Conventions: `docs/rules/` + `docs/rules/INDEX.md` — single-sourced, never restated elsewhere
- Read-cost figures for the rule corpus live in `docs/rules/INDEX.md` only
- ADRs: `docs/system/architecture.md`
- Lifecycle, gates, sizing: `WORKFLOW.md`
- Local scratch, never indexed: `.llm/tasks/`, `.llm/threads/`
- Placeholder rule: never merge a PR that leaves a `Status: Draft` entry in the index
