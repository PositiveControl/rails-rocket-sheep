# Setting up the `beads` tracker tier

Only needed if `/workflow_setup` was configured with tracker tier `beads`. The
`github-projects` and `labels` tiers need none of this.

## What you're installing

Two binaries and one background process:

| Piece | Why |
|---|---|
| `bd` | The issue tracker CLI |
| `dolt` | The database engine beads stores issues in |
| `dolt sql-server` | A running server — **beads cannot operate without it** |

This is the real cost of this tier, and it's why the template does not install
beads for you: a generated app otherwise needs only PostgreSQL. Choose this tier
because you want blocker-aware "what's ready", not by default.

## Install

```sh
# macOS
brew install dolt
# beads: see https://github.com/steveyegge/beads for current install instructions
```

Verify both are on PATH:

```sh
dolt version
bd version
```

## Start the server

Beads auto-detects a server on port **3307** or **3306**.

```sh
mkdir -p ~/.beads-data && cd ~/.beads-data
dolt init --name "<your name>" --email "<your email>"   # first time only
dolt sql-server --port 3307
```

Leave it running. It is a daemon — most people run it under `launchd`, `systemd`,
or a `tmux` session that survives a terminal close. If it isn't running, every
`bd` command fails with **"no beads database found"**.

## Initialise this repo

From the repo root, with the server running:

```sh
bd init --prefix <short-prefix> --server-port 3307
```

The prefix names your issues — `--prefix acme` produces IDs like `acme-a3f2dd`.
Keep it short; it appears in every branch name and PR title.

Confirm:

```sh
bd list          # empty is fine — it proves the connection works
bd ready         # what the workflow's /pick calls
```

## Verify the workflow can use it

```sh
bd create "Smoke test" --type task --description "Delete me"
bd ready                       # should list it
bd update <ID> --claim         # sets assignee + in_progress; fails if already claimed
bd set-state <ID> lifecycle=up_for_review
bd list --label lifecycle:up_for_review   # /pick reconciles against this
bd close <ID>
```

If all six succeed, the tier is working.

## What changes in the workflow

- `/pick` calls `bd ready`, `bd list --status in_progress`, and `bd blocked`.
  `bd ready` **excludes** in-progress work, which is why all three run.
- `/feature_plan` creates an epic and hangs slices off it with
  `bd dep add <child> <parent> --type parent-child`. Dependencies between
  siblings are real, so `bd ready` hides work whose blockers are still open.
- `/task_plan` claims the bead and branches as `<prefix>/bd-<hash>/<slug>`.
- `/pr_submit` sets `lifecycle=up_for_review`, records the PR as
  `--external-ref gh-<pr>`, and writes **no** `Closes #n` line.
- `/pick` closes merged beads on the next run — lazy reconciliation replaces
  GitHub's close-on-merge automation.

## Troubleshooting

**"no beads database found"** — the `dolt sql-server` isn't running, or is on a
port beads doesn't check. Restart it on 3307.

**`bd update --claim` fails** — someone else holds the claim. That's the feature
working; pick different work rather than forcing it.

**Reconciliation never closes anything** — `/pr_submit` skipped the
`--external-ref gh-<pr>` step, so `/pick` has no PR to check. Set it manually with
`bd update <ID> --external-ref gh-<pr>`.

## Going back

Nothing in the application depends on beads. Re-run `/workflow_setup`, choose a
different tier, and stop the dolt server.
