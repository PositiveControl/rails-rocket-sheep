# Update from the template

**Status:** Complete

This app was generated from [Rails Rocket Sheep](https://github.com/PositiveControl/rails-rocket-sheep),
and the first lines of `CLAUDE.md` name the commit. The template keeps moving:
rules get corrected, commands get sharper. This is how to take those changes
without giving up ownership of your copy.

---

## The model

Your `docs/rules/`, `.claude/commands/`, `WORKFLOW.md` and the rest are **your
files**. Nothing fetches them behind your back and no version is pinned. What
`bin/rocket-sheep-update` does is a three-way merge:

| Side | What it is |
|---|---|
| base | the template at the commit stamped in `CLAUDE.md` |
| yours | the file as it is in this repo, edits and all |
| theirs | the template at the ref you are moving to |

Where only the template changed, you get the change. Where only you changed, you
keep yours. Where both changed the same lines, you get conflict markers — the
same thing `git merge` leaves, resolved the same way.

Only the alignment layer moves: conventions, rules, commands, the doc canon,
hooks, PR and issue templates. `Gemfile`, `app/`, `config/` and `db/` are never
touched.

---

## Look first

```bash
bin/rocket-sheep-update --check
```

Writes nothing. Prints what would merge, what would conflict, and what needs
hands. Exits non-zero when anything is pending, so it works in CI as a
"the template moved" signal.

## Then take it

```bash
git switch -c chore/template-update
bin/rocket-sheep-update
git diff
```

It refuses to run on a dirty working tree, because reading `git diff` afterwards
is the whole review. Resolve any conflict markers, run the gates, and open the
PR like any other change:

```bash
bin/test && bin/rubocop && bin/brakeman
```

On success it rewrites the stamp in `CLAUDE.md` to the commit you moved to. That
stamp is what the *next* update reads, so keep the line.

## Options

| Flag | Why |
|---|---|
| `--check` | report only |
| `--ref REF` | move to a tag, branch, or SHA instead of `main` |
| `--from SHA` | you deleted the stamp, or adopted the layer by hand |
| `--force` | run with uncommitted changes anyway |

| Variable | Why |
|---|---|
| `ROCKET_SHEEP_TEMPLATE` | use a checkout you already have instead of cloning |
| `ROCKET_SHEEP_REPO` | clone from your own fork |

Without `ROCKET_SHEEP_TEMPLATE` it keeps a full clone in
`tmp/rocket-sheep-template/` (gitignored) and fetches into it on later runs.

A ref resolves to `origin/<ref>` when the checkout has one, because `git fetch`
advances the remote-tracking ref and never the local branch — in the cached clone
the local `main` is stale by definition after the first update. When a local
branch of the same name exists and differs, the run says so and uses the remote;
pass the SHA to `--ref` to mean the local one. A `--ref` that turns out to be an
ancestor of the stamp warns too: merging toward it rolls the layer backwards and
offers every change taken since for removal.

---

## What it cannot do for you

- **`CLAUDE.md` and `docs/system/models.md`** are rendered from ERB at
  generation time, so an upstream diff to them is not a diff of your file. They
  are listed as hand-merge, with the template path to read.
- **Files the template deleted** are reported, never deleted. Removing your copy
  is your call.
- **Files renamed upstream** show up as an add plus a report of the old path.
- **A conflict is a decision**, not a defect. The template does not know why you
  changed that rule; you do.

## When there is no stamp

An app that adopted the layer with `adopt.rb` after the fact, or one whose
`CLAUDE.md` was rewritten, has nothing to diff from. Find the commit you took
the layer from and pass it once:

```bash
bin/rocket-sheep-update --from 1a2b3c4
```

The run puts the stamp back.
