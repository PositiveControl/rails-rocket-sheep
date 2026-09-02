# Skills are a generated overlay over the rule index, not a second corpus

Amends [ADR 0001](0001-plain-markdown-commands-not-skills.md),
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

`docs/rules/` stays the only source. Generation additionally installs **one** skill,
`.claude/skills/rails-conventions/SKILL.md`, whose `description` covers Rails work
under `app/`, `db/migrate/`, `config/` and `test/`, and whose body is the three-step
route: read `docs/rules/INDEX.md`, read only the rules it names, fall back to
`SYMPTOMS.md` on a miss.

It carries no routing tables. The draft of this decision put `INDEX.md`'s
route-by-path table in the body, to save the agent a hop; that was dropped when it
was built. [ADR 0012](0012-routing-is-two-tier-in-both-modes.md) had since made the
index the one place routing lives — and copying the table back out would have
recreated, inside a generated app, the third copy this decision's own consequences
list as its worst cost, plus a `lint-docs` check to hold the copy in step. The hop
it saves is one file read; the drift it avoids is an agent routed to the wrong rule
with nothing to tell it. There is also a second index now, one per mode, and a
pointer needs no branch: both modes install their router under the same name.

So the skill repeats no fact from anywhere. It is a door, not a map.

Rejected: one skill per rule. Thirty-eight-plus skill descriptions is a listing an
agent pays for on every turn to route work the index routes for free, and it puts
thirty-eight `description` lines under maintenance beside the `title` and
`triggers` they restate. The index is already the router; the skill's job is to
make the index model-invocable, not to replace it.

`bin/lint-docs` gains two checks, both cheap because the body is a pointer: a
`SKILL.md` exists at all, and every path it names resolves — the same check the
workflow commands already get, extended to the skill. Nothing else changes. The enforcement layer stays harness-specific because it degrades to
nothing (ADR 0001); the skill is now the same kind of thing — an agent in Cursor
loses the auto-pull and still reads the same index that says which rule applies.

## Consequences

Accepted:

- ~~**A third copy of the routing tables exists in a generated app.**~~ Avoided,
  by dropping the tables from the body. `INDEX.md` stays the only place the routing
  is written, and the skill names it rather than restating it. This was the
  consequence that decided the built shape.
- **The skill is Claude Code only, and the corpus must not come to depend on it.**
  The moment a rule says "the skill will pull this in", the corpus has forked by
  tool, which is what 0001 was protecting. Rules keep stating their own
  `applies_to`.
- **Auto-invocation is a heuristic.** The skill firing depends on a description
  matching the model's read of the task. It will miss. `CLAUDE.md` keeps telling
  the agent to read the index, because the skill is an addition to the routing
  path and not a replacement for it.
- **One more thing generation can get wrong silently.** A skill naming an index
  that is not there routes an agent nowhere, which is worse than no skill. Hence
  the `bin/lint-docs` checks landing in the same change, not after it. Both were
  proved to fire before the change was committed.
- **The pointer costs a hop.** The skill fires, its body sends the agent to the
  index, the index sends it to a rule: three reads where an inlined table would
  have been two. That is the price of one copy instead of two, and it is only paid
  when the skill fires on work that actually needs routing.

Gained: the one consequence 0001 accepted and could not mitigate. A rule can now
reach an agent that never asked for it, without any rule being written twice.

## Revisit when

A second harness ships a model-invocable format, or the single-skill router
measurably fails to fire on work it should cover. Inlining the path table is the
other thing to revisit, and the evidence for it would be agents that read the
skill and then stop before reading the index — not an argument that two reads are
better than three. The first makes this a generated
pair rather than a generated file; the second is an argument for per-rule skills
that should be made with evidence about what did not fire, since it reverses the
rejection above.
