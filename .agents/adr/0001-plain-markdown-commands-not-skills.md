# Commands are plain markdown; enforcement may be harness-specific, routing may not

## Context

The generated app's alignment layer has two halves. **Routing** is how an agent
finds what applies: `CLAUDE.md`, `AGENTS.md`, `docs/rules/INDEX.md`, the 24
commands. **Enforcement** is what happens when it ignores them: the hooks, the
permissions file, CI.

Claude Code has a richer format available for the routing half. A skill
(`SKILL.md` with frontmatter, progressive disclosure, model-invocable) would let
the model pull in a convention on its own rather than being routed to it, and
would let some commands run without a human typing them.

Adopting it would split the corpus by tool. Cursor reads `.cursor/commands/` and
`.cursor/rules/*.mdc`. Codex reads `AGENTS.md`. A human reads with `grep`. None of
them read `SKILL.md`.

## Decision

The routing layer is plain markdown with no harness-specific loading. Commands are
markdown instruction files; conventions are markdown rule files; the indexes are
markdown tables. A tool with a slash-command concept surfaces a command as
`/name`, and a tool without one reads and follows the file, which
`templates/AGENTS.md` tells it to do.

The enforcement layer may be harness-specific, because it degrades to nothing.
`.claude/settings.json`, `bin/hooks/post_edit`, and `bin/hooks/session_end` are
Claude Code only. An agent in Cursor loses the RuboCop-on-edit check and still
reads the same rule that says RuboCop must pass. Nothing about the routing depends
on the hook existing.

## Consequences

Accepted:

- **No model-invocable conventions.** An agent is routed to a rule by the index or
  by a command; it cannot have one pulled in automatically. The `applies_to` globs
  and `triggers` keywords in each rule's frontmatter exist to make the routing
  cheap enough that this is not a real loss.
- **No automatic command invocation.** A command names the next command, and the
  human types it. This is stated as a ceiling in `templates/WORKFLOW.md` under
  "Who invokes what", so nobody writes a step that expects automation.
- **The rule as originally written was too strict.** "No harness-specific loading
  anywhere in `templates/`" reads as a ban on the settings file and the hooks that
  already ship. The line is routing versus enforcement, not Claude versus everyone
  else.

Gained: one corpus, one source of truth per fact, and a product that works for a
buyer on Cursor or Codex without a second tree to maintain.

## Revisit when

The Agent Skills format is read by more than one of the harnesses this product
targets, or a `SKILL.md` layer can be generated from the existing rule files
without becoming a second source. A subagent definition under `.claude/agents/`
is the narrower version of the same idea, and is tracked as a gap in
`docs/inventory.md` rather than blocked by this decision: it adds enforcement-side
capability without moving where a convention lives.
