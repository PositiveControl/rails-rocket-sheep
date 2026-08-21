# A generated app records its origin, and does not track it

## Context

`rails new --template` runs once. What it leaves behind runs for years: 38 rules
routed on every edit, 19 commands, four gates, two hooks. The installer is a
moment; the alignment layer is the product.

That asymmetry has a consequence nobody had written down. When a rule in a
generated app is wrong — as four of them were before the commits leading to this
ADR — the fix lands in the template, and every app already generated keeps the
defect forever. Worse, from inside such an app there is no way to ask the
question: no version, no commit, no date, nothing to compare against.

`docs/faq.md` claimed "the template is versioned and fixes are published". There
were no tags, no version constant, and nothing written into a generated app.

## Decision

A generated app records where it came from, and nothing more.

`template.rb` resolves the template's short commit SHA at generation time and
writes it, with the date, into the generated `CLAUDE.md`. The stamp says plainly
that the app is a copy rather than a dependency, and that its own copy governs it.

There is no update channel, no marketplace, and no release pipeline. Adding one
would mean the generated files are not yours, which is the opposite of what this
product is.

## Consequences

Accepted:

- **A stale convention is diagnosable, not fixed.** Someone comparing an app to
  the template can now see the two commits. Reconciling them is still manual, and
  deliberately so: these files get edited by their owners, and a mechanical update
  would either clobber that or need three-way merges.
- **The SHA can be `unknown`.** A template run from a tarball with no git history
  has no commit to name. Generation must never fail over a stamp, so the lookup is
  guarded and falls back.
- **A SHA is not a release.** It identifies the input exactly, which is what
  diagnosis needs, and communicates nothing about compatibility. If tags arrive,
  the stamp should carry the tag *and* the SHA.

## Revisit when

Tags exist, or a `bin/rocket-sheep-diff` becomes worth writing: given the stamp, it
could show what changed in `docs/rules/` and `.claude/commands/` since generation
and let the owner take what they want. That is the upgrade path this decision
leaves open, and it needs the stamp to exist first.

**Revisited.** That tool is `bin/rocket-sheep-update`, and the merge it needed
turned out to be `git merge-file` rather than anything hand-written — see
[ADR 0005](0005-updates-are-a-three-way-merge-from-the-stamp.md). The stamp is
unchanged and is now what the update reads.
