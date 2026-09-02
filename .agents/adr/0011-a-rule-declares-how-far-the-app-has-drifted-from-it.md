# A rule declares in frontmatter whether the app still obeys it

**Status: draft.** Decided; not implemented. No rule carries the field yet and
`bin/lint-docs` does not check it.

## Context

Adopting this corpus into an existing app rewrote most of it, and eight rules grew
the same new part: a paragraph saying how far the codebase had drifted from what the
rule describes, and which half of the rule was still enforceable in review. The
measurements are in [docs/adoption-drift-findings.md](../../docs/adoption-drift-findings.md).

The format has no slot for that, so each of the eight improvised a position and a
voice. It reads well where it is direct — `controllers` states that the routes file
does not obey the rule, that this makes it the target for new controllers rather
than an advisory note, and that nobody should add the three hundred and sixty-first
custom route because three hundred and sixty exist. It reads as an apology
elsewhere. Same information, eight presentations, and nothing can tell whether a
mechanism rule has the paragraph or forgot it.

A generated app does not need this. The mechanisms its rules describe are the ones
`template.rb` just installed, so every rule matches on day one and drifts later.
An adopted app needs it in every mechanism rule from the first commit. Both are
supported paths ([ADR 0006](0006-adoption-installs-the-alignment-layer-only.md)),
so the format has to serve both.

## Decision

Rule frontmatter gains `current_state`, with two values:

```yaml
current_state: matches     # the code does what this rule says
current_state: diverges    # it does not, and the body says how
```

Generation writes `matches` on every rule. Adoption sets `diverges` where it is
true, and `bin/lint-docs` then requires the body to carry a `## Where this app is`
section — and requires that a rule carrying that section declares `diverges`. The
pairing is checked in both directions, so the paragraph cannot go missing and cannot
be left behind after the code catches up.

`diverges` covers both shapes the adoption produced: a different mechanism than the
rule names, and no mechanism at all yet. Which one it is belongs in the prose, where
a reader needs the detail anyway.

**The prose stays in the body, not in the field.** A full-prose frontmatter field was
the obvious reading of this decision and it was rejected: the paragraphs are markdown
with inline code and links, frontmatter is stripped by every renderer, and the
corpus's whole premise is that routing is cheap — an agent scanning `applies_to` and
`triggers` to decide what to read would start paying for paragraphs it did not ask
for. Frontmatter stays metadata; the field is the machine-readable half and the
section heading is where the writing goes.

## Consequences

Accepted:

- **Thirty-eight rules gain a line that says nothing.** `current_state: matches` on
  every shipped rule is a fact about a freshly generated app, and it is the price of
  the field being required rather than optional. Optional would mean a missing field
  is indistinguishable from an unanswered question, which is the state the corpus is
  in today.
- **A required field can be wrong.** A rule saying `matches` while the code has
  drifted is a lie with a checkmark on it, and nothing can detect that — the check
  verifies the pairing of field and section, not the truth of either. `/update_docs`
  is where it should be revisited; the field makes the question askable, not answered.
- **One more thing for `bin/rocket-sheep-update` to merge.** An app that set
  `diverges` on a rule the template later rewrites will conflict on the frontmatter,
  which is correct behaviour and still a conflict someone resolves by hand.
- **A rule can now read as two rules.** The principle and the current state say
  different things by design, and a reader in a hurry may take the current state as
  permission. `controllers` shows the mitigation: state plainly that the gap does not
  make the rule advisory.

Gained: the one part of a rule that only an adopted app has, in a fixed place, with
a check that it is present when it is needed and gone when it is not.

## Revisit when

`/update_docs` or a doc-drift loop can verify the claim rather than the pairing. At
that point the field could carry the commit it was last confirmed at, which is worth
more than a boolean and costs a discipline nobody has yet.
