# Skills are a generated overlay over the rule index, not a second corpus

**Status: draft.** Amends [ADR 0001](0001-plain-markdown-commands-not-skills.md),
which stands except for the consequence it accepted: routing is still plain
markdown, and it is no longer only routed *to*.

## Context

ADR 0001 ruled the routing layer plain markdown and named the cost it accepted:
"No model-invocable conventions. An agent is routed to a rule by the index or by a
command; it cannot have one pulled in automatically." The mitigation was that
`applies_to` globs and `triggers` keywords make the routing cheap enough that this
is not a real loss.

It is a partial loss. The routing only fires when something tells the agent to
read `INDEX.md` first — `CLAUDE.md`, `AGENTS.md`, or a command. An agent that
starts by editing `app/controllers/orders_controller.rb` on its own initiative
never passes through the index, and the corpus is silent at exactly the moment it
was written for.

The reason 0001 declined skills was not that skills are worse. It was that
adopting `SKILL.md` as *the* format splits the corpus by tool: Cursor reads
`.cursor/rules/*.mdc`, Codex reads `AGENTS.md`, a human reads with `grep`, and
none of them read `SKILL.md`. That reasoning is intact. What it rules out is
skills as a source. It does not rule out skills as an output.

ADR 0002 already established the mechanism for an output: commands have one
source, `templates/.claude/commands/`, mirrored to `.cursor/commands/` at install
time (`adopt.rb:159-169`). A harness-specific surface generated from a
tool-agnostic source is a shape this product already uses.

## Decision

`docs/rules/` stays the only source. Generation additionally emits **one** skill,
`.claude/skills/rails-conventions/SKILL.md`, whose body is the routing content of
`INDEX.md` — the route-by-path table, the route-by-symptom table — and whose
instruction is to read the one rule file it routed to.

The skill carries no rule content. It is a router, so there is nothing in it to
drift from the rule files; the only fact it repeats is which paths and symptoms
map to which id, which `bin/lint-docs` already checks in `INDEX.md` and can check
here from the same data.

Rejected: one skill per rule. Thirty-eight-plus skill descriptions is a listing an
agent pays for on every turn to route work the index routes for free, and it puts
thirty-eight `description` lines under maintenance beside the `title` and
`triggers` they restate. The index is already the router; the skill's job is to
make the index model-invocable, not to replace it.

`bin/lint-docs` gains one check: the skill's tables match `INDEX.md`'s. Nothing
else changes. The enforcement layer stays harness-specific because it degrades to
nothing (ADR 0001); the skill is now the same kind of thing — an agent in Cursor
loses the auto-pull and still reads the same index that says which rule applies.

## Consequences

Accepted:

- **A third copy of the routing tables exists in a generated app.** `INDEX.md`,
  `.cursor/rules/conventions.mdc`, and now the skill. All three are generated from
  one source in this repo, which is where they are written, but a buyer who edits
  `INDEX.md` in their app leaves two stale. This is the cost ADR 0002 already
  accepted for commands, taken a second time.
- **The skill is Claude Code only, and the corpus must not come to depend on it.**
  The moment a rule says "the skill will pull this in", the corpus has forked by
  tool, which is what 0001 was protecting. Rules keep stating their own
  `applies_to`.
- **Auto-invocation is a heuristic.** The skill firing depends on a description
  matching the model's read of the task. It will miss. `CLAUDE.md` keeps telling
  the agent to read the index, because the skill is an addition to the routing
  path and not a replacement for it.
- **One more thing generation can get wrong silently.** A skill with stale tables
  routes an agent to the wrong rule, which is worse than no skill. Hence the
  `bin/lint-docs` check landing in the same change, not after it.

Gained: the one consequence 0001 accepted and could not mitigate. A rule can now
reach an agent that never asked for it, without any rule being written twice.

## Revisit when

A second harness ships a model-invocable format, or the single-skill router
measurably fails to fire on work it should cover. The first makes this a generated
pair rather than a generated file; the second is an argument for per-rule skills
that should be made with evidence about what did not fire, since it reverses the
rejection above.
