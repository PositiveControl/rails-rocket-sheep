# Updates are a three-way merge from the stamp, run on demand

## Context

[ADR 0004](0004-generated-apps-record-their-origin.md) made a generated app
record the commit it came from and stopped there, on the grounds that "a
mechanical update would either clobber [the owner's edits] or need three-way
merges". It named the revisit condition itself: a tool that, given the stamp,
shows what changed in `docs/rules/` and `.claude/commands/` since generation and
lets the owner take what they want.

The cost of stopping there was that a corrected rule reached exactly zero
existing apps. Four rules were wrong before 0004 was written; every app
generated before the fix keeps them, and the only remedy was a human diffing two
trees by hand and re-applying edits file by file. Diagnosable is not fixed.

The reason not to build the tool was the merge itself. That reason was wrong: the
merge does not have to be written. `git merge-file` is a three-way merge over
three paths, present wherever git is, and it produces the same conflict markers
a `git merge` does.

## Decision

`bin/rocket-sheep-update` ships inside the alignment layer. It reads the commit
stamped in `CLAUDE.md`, gets a full checkout of the template, and for every file
in the layer that changed between that commit and the requested ref, runs
`git merge-file` with the template's old blob as base, the template's new blob
as theirs, and the app's file as ours.

Three properties make it an update path rather than a package manager:

- **It is pull, not push.** Nothing runs on its own, nothing is pinned, and no
  version constrains anything. `--check` is the read-only mode.
- **Ownership is preserved by the merge, not by asking.** Where only the template
  changed, the change lands. Where only the app changed, the app wins. Where
  both changed the same lines, the owner gets conflict markers and decides.
- **The scope is the alignment layer, and the layer defines itself.** The set of
  updatable files is read out of the template's own `adopt.rb` at the target ref,
  so there is no second list to drift. `Gemfile`, `app/`, `config/` and `db/` are
  never touched.

On success it rewrites the stamp, which is what makes the next update possible.
`bin/lint-docs` checks that the stamp `CLAUDE.md.tt` writes still matches the
regex the updater reads, because rewording that one line would silently cost
every future app its upgrade path.

## Consequences

Accepted:

- **Conflicts are the owner's work.** A conflict is a decision — the template
  does not know why a rule was changed locally. The claim is that the merge
  shrinks the manual work to the genuinely ambiguous lines, not that it removes
  it.
- **ERB templates cannot be merged.** `CLAUDE.md` and `docs/system/models.md`
  render at install time, so an upstream diff to `CLAUDE.md.tt` is not a diff of
  the app's file. Those are reported as hand-merge with the template path to
  read, and no more.
- **Deletions are reported, never applied.** A file the template dropped may
  still be load-bearing in an app that extended it.
- **A full clone, cached in `tmp/`.** The stamped commit can be arbitrarily far
  back, so `--depth` is not available. `ROCKET_SHEEP_TEMPLATE` reuses a checkout
  you already have.
- **`adopt.rb` is now load-bearing twice.** It installs the layer and defines the
  layer, so a file copied without going through it is a file no update can ever
  reach. `bin/lint-docs` check 9 reads both entry points for exactly this
  reason.
- **This narrows 0004, it does not reverse it.** There is still no marketplace,
  no release pipeline, and no dependency. An app that never runs the command is
  in precisely the position 0004 described.

## Revisit when

Tags exist — `--ref v2.0` already works, but the stamp records a SHA, so
"which release am I on" still has no answer. Or when conflicts turn out to
cluster in one file, which would say that file is badly factored rather than
that merging is hard.
