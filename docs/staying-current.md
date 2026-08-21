# Staying Current

Two questions this page answers:

1. My app was generated months ago and the template has moved. How do I take the
   changes?
2. I have a Rails app that was never generated from this template. Can it have
   the workflow anyway?

Both are the same mechanism from two directions, and both concern only the
**alignment layer**: `CLAUDE.md`, `docs/rules/`, `docs/system/`, `docs/sop/`, the
workflow commands and their Cursor mirror, `WORKFLOW.md`, `AGENTS.md`, `.llm/`,
the hooks, `.claude/settings.json`, and the PR and issue templates. `Gemfile`,
`app/`, `config/` and `db/` are never touched by either.

---

## 1. Updating an app that was generated from the template

Your generated app is a copy, not a dependency. Nothing is pinned, nothing phones
home, and nothing changes until you ask. What the app *does* carry is the commit
it came from, stamped into the first lines of its `CLAUDE.md`.

```bash
cd your-app
bin/rocket-sheep-update --check
```

That prints what changed in the alignment layer between your stamp and the
template's `main` — and writes nothing. To take it:

```bash
git switch -c chore/template-update
bin/rocket-sheep-update
git diff
```

For every file that changed upstream, this is a three-way merge:

| | |
|---|---|
| base | the template at your stamped commit |
| yours | your file, edits and all |
| theirs | the template at the ref you asked for |

**Where only the template changed, you get the change. Where only you changed, you
keep yours. Where both changed the same lines, you get conflict markers** — the
same ones `git merge` leaves, resolved the same way. That is the trade: you keep
ownership of every file, and in exchange you arbitrate the overlaps.

It refuses to run on a dirty working tree, because reading `git diff` afterwards
is the review. On success it rewrites the stamp to the commit you moved to, which
is where the next update starts.

Two things it will not do for you: `CLAUDE.md` and `docs/system/models.md` are
rendered from ERB at generation time, so it names them for hand-merging rather
than guessing; and files the template deleted are reported, never deleted.

The shipped procedure lives in every generated app at
`docs/sop/update-from-the-template.md`, so the agent working in your app can read
it too.

### Why not a gem, or a version to bump?

Because then the files would not be yours. The whole product is that
`docs/rules/testing.md` is a file you can rewrite when your team disagrees with
it — a rule you cannot edit is advice from a stranger. The reasoning, and what it
costs, is in
[ADR 0005](../.agents/adr/0005-updates-are-a-three-way-merge-from-the-stamp.md).

---

## 2. Adopting the workflow into an existing Rails app

An app that was never generated from this template can still have the alignment
layer. Adoption uses Rails' own template mechanism:

```bash
git clone https://github.com/PositiveControl/rails-rocket-sheep.git ~/src/rails-rocket-sheep

cd your-existing-app
git switch -c chore/adopt-rocket-sheep
bin/rails app:template LOCATION=~/src/rails-rocket-sheep/adopt.rb
git status
```

You get the rules, the 24 workflow commands and their Cursor mirror, the doc
canon, the hooks, the PR and issue templates, and the origin stamp — so
`bin/rocket-sheep-update` works from then on. Keep the clone: it is what the
update reads.

The only files that can already exist are `CLAUDE.md`, `AGENTS.md`, and
`.gitignore`. The first two arrive as a Thor conflict prompt, where `d` shows the
diff before you decide. Running adoption twice is safe — the second run reports
everything identical.

### The one thing to understand before you run it

**The rules describe patterns adoption does not install.** `ApplicationService`
and `Result`, `ApplicationForm`, the registry pattern, Slim, ViewComponent, the
SEO helper — the rule corpus documents all of them, and adoption writes none of
the code. That is deliberate: rewriting your app's conventions is not an
installation, and no generator should try
([ADR 0006](../.agents/adr/0006-adoption-installs-the-alignment-layer-only.md)).

So on the first pass, read `docs/rules/INDEX.md` and make a decision per rule:

- **Adopt the pattern** when you next need it. Most are one small file.
- **Rewrite the rule** to describe what your app actually does. This is the
  common case and the intended one — the routing index and the frontmatter are
  the valuable part, not any specific opinion.
- **Delete the rule.** A rule pointing at a class you do not have is worse than
  no rule, because an agent will believe it.

Then run `/workflow_setup` to fill the repo and board tokens the commands carry,
and read `WORKFLOW.md`.

### What adoption gives an old app

The parts of this template that are worth the most in an app with existing code
are the parts adoption installs: routed conventions an agent reads before editing
a file, a lifecycle with gates, hooks that enforce two rules rather than
suggesting them, and doc directories the agent writes to instead of inventing a
new `NOTES.md` every session.

The parts it cannot give you are the parts that had to be there from the start.
See [Comparison](comparison.md) for the honest version of that line.
