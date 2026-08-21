# Adopting from the skills repo: what to take, what it costs, what to leave

**Status: implemented on branch `skills-adoption`.** A1 to A4 shipped as four
commands (`/grill`, `/resolve_conflicts`, `/research`, `/diagnose`), A5 folded into
`/update_docs` Step 5, G6 added as `/pr_review` Step 7, the three stolen
conventions added to `docs/writing-commands.md`, A6 recorded as gap 12 in
`docs/inventory.md`, and the command count moved 19 → 24 across every site.
`bin/lint-docs` is clean. Section 3 stands: the commands did not become skills.

**Superseding A5:** `domain-modeling` was then adopted in full as `/domain_model`,
and with it the skill's ADR path convention. Decisions are now one file each in
`docs/adr/` (see [ADR 0008](adr/0008-decisions-are-one-file-each.md)), and
`/update_docs` Step 5 hands off to the command rather than restating the
three-part test, so the test lives in one place. Point 7 of section 1's
"Worth taking" list called this a fold into an existing command; the fold turned
out to be the smaller half of it.

Source surveyed:
`../skills` (35 skills across `engineering/`, `productivity/`, `misc/`,
`in-progress/`). Target: this repo's workflow commands as they stood at 19, the
38 rules, and the alignment layer `adopt.rb` installs.

Two questions were asked: which skills are worth taking, and whether the
commands should become skills. They have different answers, so they are kept
apart below.

## 1. The coverage map

Every skill falls into one of four buckets against what already ships.

### Already covered (leave out)

| Skill | Covered by |
|---|---|
| `code-review` | `/rails_code_review` + `/pr_review` (but see gap G6) |
| `implement`, `implement-spec` | `/implement`, plus `.llm/tasks/` for resumability |
| `to-spec`, `to-tickets` | `/feature_plan` (design doc, parent, sized sub-issues) |
| `wizard` | `/workflow_setup`, and `bin/` scripts for the rest |
| `git-guardrails-claude-code`, `setup-pre-commit` | `bin/hooks/post_edit`, `.claude/settings.json`, CI |
| `ask-matt` | `/pick` as the entry door, `WORKFLOW.md` as the map |
| `tdd` | `templates/docs/rules/testing.md` plus `/implement` |
| `writing-for-agents` | `docs/writing-commands.md`, which is the shape already taken from it |
| `handoff`, `claude-handoff` | `.llm/tasks/` carries resumable state; `/segue` carries the thread |

`handoff` is the closest call. It only earns a slot for work that is *not* under
a task file, and that window is small enough to skip.

### Wrong shape for this product (leave out)

| Skill | Why not |
|---|---|
| `codebase-design`, `improve-codebase-architecture`, `setup-ts-deep-modules` | Deep-module vocabulary competing with `pattern-budget.md` and the service/form/registry set. Two design vocabularies in one repo is the drift this product exists to prevent |
| `wayfinder` | Decision-ticket machinery on top of three tracker tiers. Collides with `.agents/out-of-scope/more-tracker-tiers.md` |
| `migrate-to-shoehorn`, `scaffold-exercises` | TypeScript and course authoring. No Rails surface |
| `teach`, `to-questionnaire`, `wait-what`, `prototype`, `loop-me`, `writing-beats`, `writing-fragments`, `writing-shape` | Personal working style, not app conventions. A buyer did not pay for someone else's interview habits |
| `setup-matt-pocock-skills` | Configures a tracker and label vocabulary. `/workflow_setup` owns that, and owning it twice is a second source |

### Worth taking (in priority order)

**A1. `grilling` → `/grill`.** The largest real gap. Both design gates (G1 in
`/feature_plan`, G2 in `/task_plan`) end at "human approval" with no procedure
for reaching it. `grilling` is that procedure: a design tree worked in rounds,
the whole frontier asked at once with a recommended answer per question, facts
looked up by the agent and decisions left to the human. 28 lines of source.
Slots into the diagram exactly where `/segue` does, as a valve off planning.

**A2. `resolving-merge-conflicts` → `/resolve_conflicts`.** 14 lines. Rebase
conflicts are guaranteed on the `/pr_submit` and `/pr_fix_ci` paths and no
command covers them today. Cheapest thing on this list.

**A3. `research` → `/research`.** Primary sources only, findings written to one
markdown file with citations, delegated to a background agent so the main
session keeps working. 12 lines. Feeds `/feature_plan`. One caveat under
downstream effects: pick an existing doc canon directory, do not add one.

**A4. `diagnosing-bugs` → `/diagnose`.** 138 lines, and the only one that needs
a rewrite rather than a port. `/test_fix` covers a failing suite and
`/pr_fix_ci` covers a red CI run. Neither covers a bug with no failing test or
a performance regression, which is the common production case. Rails-specific
content already exists to point at (`n-plus-one.md`, `caching.md`,
`audit-trail.md`), so the port is the loop, not the content.

**A5. `domain-modeling`, folded into `/update_docs`, not a new command.** The
generated app ships `docs/system/vocabulary.md` and an ADR home but no
procedure for adding to either. `domain-modeling`'s `ADR-FORMAT.md` and
`CONTEXT-FORMAT.md` are the missing half. This is a step inside a command that
already exists, so it costs no count bump and no router rows.

**A6. `triage`, deferred.** Real gap (`/pick` assumes a groomed board, nothing
grooms it), but the skill depends on its own label vocabulary, which is
`/workflow_setup`'s territory across three tiers. Expensive, and it wants
buyer evidence first. Note it in `docs/inventory.md` rather than building it.

### Shapes worth stealing without taking the skill

- **G6, the spec axis in review.** `code-review` runs two axes in parallel:
  does the code follow documented standards, and does it match what the
  originating issue asked for. Neither `/rails_code_review` nor `/pr_review`
  mentions the issue's acceptance criteria at all (verified by grep). That is a
  step to add to `/pr_review`, not a new command.
- **`grilling`'s round format** (numbered question, recommended answer, rule
  that a question depending on an open question belongs to a later round) is
  reusable in `/feature_plan` and `/task_plan` even if `/grill` is never added.
- **`handoff`'s anti-duplication rule** ("reference specs, plans, ADRs, issues,
  commits by path, never restate them") is one line and belongs in
  `docs/writing-commands.md` as a convention.
- **`research`'s primary-source rule** ("follow every claim back to the source
  that owns it") belongs in `/update_docs` regardless of A3.

## 2. Downstream effects of adding a command

The mechanical half is cheap and the bookkeeping half is not.

**Free.** `adopt.rb` copies commands by glob (`WORKFLOW_COMMANDS`), so a new
file is installed by generation, installed by adoption, mirrored to
`.cursor/commands/`, and merged by `bin/rocket-sheep-update` with no manifest
edit. This is the payoff of ADR 0006 and the reason the marginal command is
mostly free to *ship*.

**Required per command, and checked by `bin/lint-docs`:**

1. A row in `templates/AGENTS.md` and in `templates/WORKFLOW.md`. The linter
   fails on omission ("a router that omits a command is a router that lies").
2. A row in `WORKFLOW.md`'s "Who invokes what" table. `/grill` and `/diagnose`
   are agent-invocable by the stated criterion (they read the repo and edit
   locally); `/research` writes a doc a human will read, so it is arguably
   yours.
3. A quoted `description` under 80 characters with no trigger phrasing, and an
   `argument-hint` if the body reads `$ARGUMENTS`.
4. The long-form frame once the file passes 60 lines. `/grill` and `/diagnose`
   will; `/resolve_conflicts` and `/research` will not.
5. Any tracker vocabulary must use a `{{TOKEN}}` that `/workflow_setup` fills.
6. Every backticked `/name` the new command mentions must be a real command,
   and the commands it slots between should name it back.

**The count bump.** `bin/lint-docs` matches `(\d+) (workflow|slash )?commands?`
across the whole repo, so "19" has to change everywhere at once:
`README.md:177`, `CLAUDE.md:52`, `CLAUDE.md:215`, `docs/writing-commands.md:3`,
`docs/workflow.md:3`, `docs/workflow.md:7`, `docs/whats-included.md:123`,
`docs/staying-current.md:87`, `docs/faq.md:24`, `docs/inventory.md:16`,
`docs/inventory.md:61`, `docs/inventory.md:235`, and the prose in ADR 0002 and
ADR 0004, and ADR 0001. Fifteen sites. The linter finds the twelve under
`docs/` and the root, so this is tedious rather
than risky, but it is the reason to add the set in one pass instead of one
command at a time.

**The diagram.** `WORKFLOW.md`'s lifecycle map gains `/grill` as a second
planning valve alongside `/segue`, and `/diagnose` hangs off `/implement`.
`/pick`'s routing table gains an "undecided, needs sharpening" branch.

**The always-loaded cost.** Commands themselves load on invocation, but
`CLAUDE.md`, `AGENTS.md`, and `WORKFLOW.md` are read every session and each
gains rows. Going 19 → 23 is a modest addition to that, and a real one.

**The honest downside.** `docs/inventory.md:235` already names "19 commands is
a lot to learn" as a weakness. Four more commands makes the product's one
admitted rough edge rougher. This is the argument for taking A1 to A4 and
stopping, and for A5 being a step inside `/update_docs` rather than a
twenty-fourth file.

## 3. Should the commands become skills?

No, and ADR 0001 already holds. It was read before writing this.

**What migration would actually buy:**

- **Model invocation.** An agent pulling a command in itself rather than
  waiting to be told. This is the only genuine gain.
- **Progressive disclosure.** Frontmatter in context, body on demand. Worth
  something for `/pr_submit` (256 lines) and `/pr_review` (244), and available
  today by moving the `## Reference` block to a linked file, which is what the
  short-form/long-form split in `docs/writing-commands.md` is already for.
- **Bundled support files.** A skill can ship `scripts/` beside itself, the way
  `diagnosing-bugs` ships `hitl-loop.template.sh`. This repo already ships
  scripts in `bin/`, so the packaging buys convenience, not capability.

**What it would cost:**

- The corpus forks by harness. Cursor reads `.cursor/commands/` and
  `.cursor/rules/*.mdc`; Codex reads `AGENTS.md`; neither reads `SKILL.md`.
  `docs/faq.md:24` and `docs/staying-current.md:87` both sell Cursor parity as
  part of the alignment layer. A migration makes those sentences false, or
  makes them true only via a second tree.
- Model invocation is *wrong* for 10 of the 19. `/pr_submit`, `/pr_review`,
  `/pr_comment_resolver`, `/feature_plan`, `/task_plan`, `/pick`, `/pr_qa`,
  `/update_docs`, `/workflow_setup` all stand at a gate or write where other
  people can see. An agent that decides its own moment to run `/pr_submit`
  removes G3 and G4, which is the checkpoint the gate exists to create. That is
  not an incidental cost; the gate design *depends* on a human typing the name.
- The gain applies only to the agent-invocable remainder, which is where a
  cheaper mechanism already exists: the `applies_to` / `triggers` frontmatter
  pattern used in `docs/rules/` works in a command file too, and `AGENTS.md`
  can say "when the suite is red, follow `.claude/commands/test_fix.md`". Zero
  fork, most of the benefit.

**The path that does not reverse the ADR.** ADR 0001's revisit condition is
already the right one: a `SKILL.md` layer generated from the existing files
without becoming a second source. The Cursor mirror is the precedent. If skills
are wanted later, generate `.claude/skills/` in `template.rb` from the same
command files, as a third destination for one source, and gate it to the
agent-invocable subset so no gate loses its human. That is a mirror, not a
migration, and it needs no ADR reversed.

`docs/inventory.md`'s gap 4 (a `code-reviewer` subagent under `.claude/agents/`)
is the narrower version of the same idea and is still the better first move: it
adds capability on the enforcement side without moving where a convention
lives.

## 4. What was done

1. **A1 to A4 as four commands.** `/grill` (48 lines, short-form),
   `/resolve_conflicts` (49), `/research` (33), `/diagnose` (89, long-form
   frame). Wired both ways: `/pick` routes an unsettled-but-sized issue to
   `/grill`, `/feature_plan` and `/task_plan` suggest it at their gates,
   `/test_fix` hands the no-failing-test case to `/diagnose`, `/pr_submit` and
   `/pr_fix_ci` point a stopped rebase at `/resolve_conflicts`.
2. **A5 folded into `/update_docs`** as Step 5: the three-part ADR test, and the
   vocabulary pass over `docs/system/vocabulary.md`. No new file, no count
   change.
3. **G6 added as `/pr_review` Step 7**, the spec axis: find the originating
   issue, walk its acceptance criteria one at a time, then look the other way for
   work nobody asked for. An unmet criterion is blocking where the PR claims to
   close the issue.
4. **Three conventions** added to `docs/writing-commands.md`: ask a whole round
   rather than a question at a time, reference artifacts instead of restating
   them, and carry the primary source for an external fact.
5. **A6 recorded as gap 12** in `docs/inventory.md`, waiting on buyer evidence
   that the board is the bottleneck.
6. **Counts bumped 19 → 23** across `CLAUDE.md` (×2), `README.md`, `docs/faq.md`,
   `docs/inventory.md` (×3), `docs/staying-current.md`,
   `docs/whats-included.md`, `docs/workflow.md` (×2),
   `docs/writing-commands.md`, and ADRs 0001, 0002, 0004: fifteen lines. The ADR
   files are
   outside the linter's glob (Ruby's `**` skips dot-directories), so those three
   were found by hand rather than by `bin/lint-docs`.
7. **The commands stayed commands.** No `SKILL.md`, no ADR reversed.

Verification: `bin/lint-docs` clean (38 rules, 23 commands),
`ruby -c template.rb adopt.rb preamble.rb` OK, and a
`rails new --database=postgresql --skip-bundle` probe installed all 23 commands
into both `.claude/commands/` and `.cursor/commands/`. That probe then failed at
the `devise:install` phase because this container has no installed gems (no `pg`,
no `devise`), which predates these changes and says nothing about them. A machine
with the bundle available should re-run the probe both ways, and adoption twice
against a `--minimal` app, per `CLAUDE.md`.
