# A generated app's decisions are one file each, in docs/adr/

## Context

The shipped alignment layer kept its ADRs in a single file,
`templates/docs/system/architecture.md`: eight decisions as `## ADR-001` sections,
plus a template section at the bottom for writing the ninth. The generator's own
decisions were already one file each in `.agents/adr/`, so the two products
disagreed about where a decision lives and what it is called.

One file per decision is what `domain-modeling` (the skill this convention comes
from) specifies, and it is what the doc canon does everywhere else: one rule per
file in `docs/rules/`, one design doc per feature in `docs/plans/`, one procedure
per file in `docs/sop/`. Architecture decisions were the only member of the canon
that did not get a file.

The single file also failed the load it was under. An agent that needed one
decision read all eight. A rule cross-referencing a decision could only point at
the whole document and name the section in prose ("ADR-004 in
`../system/architecture.md`"), so the link went to the top of a 198-line file and
the reader hunted. Nothing checked those references, either: `bin/lint-docs`
verifies paths named by *commands*, not by rules, so a stale ADR pointer inside a
rule file was invisible.

## Decision

A generated app's decisions live in `docs/adr/`, one per file, numbered
`NNNN-<slug>.md`, four digits, newest last. The number lives in the filename and
the H1 carries the decision's title alone. `docs/adr/` joins the doc canon and
gets its own marker block in `.llm/README.md`. `templates/docs/system/architecture.md`
is deleted; `docs/system/` keeps `models.md` and `vocabulary.md`.

The eight shipped decisions moved across unchanged, keeping their numbers, so
`ADR-002` is now `docs/adr/0002-primary-keys-follow-the-database.md` and every rule
that cited a number links the file that holds it. A decision whose title changes
gets a new slug and keeps its number; the number is the identity, the slug is a
convenience.

`adopt.rb` copies the directory by glob, in the same shape as `RULE_FILES`, which
is what makes a ninth decision adoptable and updatable without a manifest edit.

`/domain_model` is the command that writes them, and it owns the three-part test
for whether a decision is owed one at all. `/update_docs` points at it rather than
restating the test.

## Consequences

Accepted:

- **An app generated before this reconciles as a delete plus eight adds.**
  `bin/rocket-sheep-update` reads `adopt.rb` as its manifest and handles both, but
  an owner who edited `architecture.md` locally will be merging their edits into
  new files by hand. That is a one-time cost, and it is the cost of the rename.
- **Eight files where there was one.** `ls docs/adr` is now the index, and a
  reader scanning for "what was decided about deletes" reads filenames rather than
  headings. Numbered filenames are what makes that scan work, so a decision added
  without a number breaks it.
- **The numbers are permanent.** A decision superseded later keeps its file and
  its number and says so in its Status line, rather than being renumbered.

Gained: one decision per file, a link that lands on the decision rather than the
document, and a canon whose members all have the same shape. The generator and the
generated app now agree about what an ADR is and where it lives.

## Revisit when

Never for the shape; that now matches the rest of the canon. If the directory
grows past what `ls` can usefully scan (thirty or so), the answer is an
`INDEX.md` beside the files, the way `docs/rules/` has one, not a return to a
single document.
