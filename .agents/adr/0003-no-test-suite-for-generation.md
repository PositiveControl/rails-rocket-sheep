# Generation is verified by generating; the docs are verified by a linter

## Context

This repo produces a Rails app. The unit under test is "the app that comes out",
which needs PostgreSQL, a bundle install, and a few minutes. There is no gem, no
runtime, and nothing importable to unit-test: `template.rb` is a Thor script whose
observable behaviour is a directory tree.

A test suite for the generator would either mock Thor, which tests nothing about
whether generation works, or run a real generation, which is what a human does by
hand anyway.

## Decision

No automated suite for generation. Verification is:

```bash
cd $(mktemp -d)
rails new probe --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
cd probe && bin/test && bin/rubocop && bin/brakeman
```

`ruby -c template.rb` on every edit catches syntax errors and proves nothing else.

The docs *are* checked, by `bin/lint-docs`, because their correctness is a set of
facts about the tree rather than a behaviour: whether a rule has an index row,
whether a path resolves, whether a quoted count is real. Those go stale silently
and often, which is exactly what a check is for.

## Consequences

Accepted:

- **Generation can break without anyone noticing.** `template.rb` patches Rails'
  own files by matching strings Rails generates, so a Rails release can break it.
  `docs/inventory.md` carries this as version-coupling debt, and re-verification
  against each Rails release is a manual task nobody is scheduled to do.
- **Verification is slow and needs a database**, so it does not run on every
  commit, and in practice does not run on doc-only changes. That is the trade the
  linter partly covers: the class of defect that ships most often is a doc that
  disagrees with the tree, and that class is now checked in under a second.

## Revisit when

Generation breaks twice from the same cause, or a CI runner with PostgreSQL is
cheap enough to run one probe generation per push. A single smoke job that
generates an app and runs `bin/test` would retire most of this ADR.
