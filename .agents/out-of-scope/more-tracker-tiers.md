# A fourth tracker tier is out of scope

`/workflow_setup` resolves one of three tiers: `github-projects`, `beads`, or
`labels`. Requests to add another tracker are out of scope.

## Why this is out of scope

A tier is not a config value. It is a branch inside `/pick`, `/feature_plan`,
`/task_plan`, `/implement`, `/pr_submit`, and `/workflow_setup`, each hard-coding a
CLI shape: the command to list ready work, the flags to move an item, the output to
parse, the way a merge closes an issue. Every new tier is permanent maintenance
surface that has to keep working as that tool's CLI evolves, and has to be
re-verified against all six commands.

The three tiers were chosen to span the axes rather than the market:
`github-projects` for a board with automation, `labels` for a repo with nothing but
issues, `beads` for a local database with no network. A fourth tracker almost
always lands inside one of those shapes, which is why the tiers are named after
mechanisms and not products.

`docs/inventory.md` already carries the verification debt for two of the three
tiers. Adding a fourth before that debt is paid makes the situation worse, not
better.

## What to do instead

Point the closest tier at your tool. A tracker with a CLI that lists, transitions,
and closes items fits the `labels` tier's shape with a local edit to the commands,
and that edit stays yours rather than becoming everyone's maintenance.

## What would change our mind

The tier branches being extracted behind one small interface, so a tracker is a
table of four commands rather than a branch in six files. That is a refactor worth
doing on its own merits; a new tracker would then be cheap enough to argue about
again.
