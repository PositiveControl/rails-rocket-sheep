# A Claude Code plugin is a second door to the same generator

## Context

The template is reached by URL: `rails new --template=https://raw.githubusercontent.com/...`.
An agent asked to start a Rails project has no reason to know that URL, and
nothing in the harness suggests it. Claude Code plugins are what the harness does
suggest: a marketplace an agent can search, a slash command a person can find in a
picker, and a manifest with a description crawlers read.

ADR 0001 and ADR 0010 govern the *generated app's* routing layer and rule out
harness-specific formats as a source of conventions. A plugin that only runs
`rails new` is not a source of anything. It carries no rules and no routing, and
it lands the user in a generated app whose `CLAUDE.md` takes over.

## Decision

The repo hosts one plugin at `plugin/`, with one command, `/rails-rocket-sheep:new`,
that runs `rails new --template=` against a **tagged** release. The marketplace
manifest lives at the repo root, so `claude plugin marketplace add
PositiveControl/rails-rocket-sheep` works without a second repository.

The plugin is not shipped into generated apps. It is a root-level product artifact
like `README.md`, not part of `templates/`.

The plugin's `version` equals the template tag it pins, so there is one number to
move at release time.

## Consequences

- One more place a release tag is pinned. Cutting a release means moving the
  `--template=` URL in `plugin/commands/new.md`, the `version` in
  `plugin/.claude-plugin/plugin.json`, and the `apply` line in the RailsBytes
  script. `CLAUDE.md` lists all three.
- The command is Claude Code only, by design. Cursor and Codex users reach the
  template through the README, RailsBytes, and the raw URL, which the plugin does
  not replace.
- If the community marketplace declines the plugin, the self-hosted marketplace
  still works, and the manifest still exists for crawlers.
