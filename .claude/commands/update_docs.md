---
description: "Deep doc pass: docs back in step with the system, index honest"
argument-hint: "[directory to scope the pass]"
---

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
| `docs/adr/` | One decision per file, numbered | Why a rule exists and what was accepted. Owned by `/domain_model` |
| `docs/system/` | How things currently work | `models.md` the model reference, `vocabulary.md` the glossary. State, not intentions |
| `docs/sop/` | Procedures somebody will repeat | Written from a mistake, or from a sequence worked out by hand |
| `docs/plans/` | Design docs for features | Owned by `/feature_plan`. Complete or delete placeholders here, never leave them listed |
| `docs/qa/` | Manual test guides | Owned by `/pr_qa` |

Two boundaries that matter:

- **Rules say what to do; ADRs say why it was chosen.** A convention goes in
  `docs/rules/`; the decision behind it and the cost accepted go in `docs/adr/`,
  one file per decision. Don't merge the two.
- **Docs describe this system. They never restate conventions.** Conventions are
  single-sourced in `docs/rules/`; everything else links to them.

`.llm/tasks/` and `.llm/threads/` are local scratch and gitignored. Never
document them, and never index them.

### Step 4: Write or update the docs

Prefer editing an existing doc over adding one. Consolidate hard: two files
covering the same ground means one of them becomes a link. Delete a doc whose
subject no longer exists rather than leaving it to mislead.

If `docs/system/` is genuinely empty (an app whose shipped docs were removed),
rebuild the minimum: `models.md` for the model reference, `vocabulary.md` for the
glossary. Decisions belong in `docs/adr/`, one file each. Do not scaffold beyond
what a reader needs now.

### Step 5: Hand off the decisions and the vocabulary

A doc pass turns up two things that are not docs, and `/domain_model` owns both:

- **A decision taken and never written down.** It becomes an ADR in `docs/adr/`
  when it is hard to reverse, surprising without context, and the result of a real
  trade-off. That test, and the writing, are Step 4 and Step 5 of
  `/domain_model` — do not restate them here.
- **A word doing two jobs.** The code and the docs using different words for one
  thing, one word covering two, or a definition the code has outgrown. The
  glossary is `docs/system/vocabulary.md`, and the same command sharpens it.

Collect what this pass found, then say what needs `/domain_model` and stop
short of rewriting the glossary inline: a term settled mid-doc-pass without the
user in the room is a term that gets re-argued.

### Step 6: Re-sync `.llm/README.md`

The index has marker blocks per directory — `plans`, `adr`, `system`, `sop`, `qa`. Edit
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

### Step 7: Run the checks

Two of the things this command just edited are machine-checkable, so end on them
rather than on a claim:

```bash
bin/doc-tokens     # rewrites the `tokens:` figure in each rule, and the figures derived from it
bin/lint-docs      # rule frontmatter, index routing, read costs, path resolution, quoted counts
```

`bin/doc-tokens` writes; run it first, then `bin/lint-docs` to check what is left.
Fix everything it names. A finding here is a doc that disagrees with the tree, and
an agent reading it has no way to tell — which is the whole reason these exist.

### Step 8: Report

State what you changed, what you consolidated or deleted and why, and anything
you found that needs a decision rather than a doc (that is an ADR, or an issue).
Say that the checks are clean, or which finding you could not resolve and why.

## Reference
- Doc index: `.llm/README.md` — committed docs only, marker blocks per directory
- Conventions: `docs/rules/` + `docs/rules/INDEX.md` — single-sourced, never restated elsewhere
- Read-cost figures for the rule corpus live in `docs/rules/INDEX.md` only
- ADRs: `docs/adr/NNNN-<slug>.md`, one per decision — the test for whether one is owed lives in `/domain_model`
- Vocabulary, one meaning per term: `docs/system/vocabulary.md`
- Lifecycle, gates, sizing: `WORKFLOW.md`
- Local scratch, never indexed: `.llm/tasks/`, `.llm/threads/`
- Placeholder rule: never merge a PR that leaves a `Status: Draft` entry in the index
