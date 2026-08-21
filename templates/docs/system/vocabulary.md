# Vocabulary

The words this app's workflow and rules use, and what each one means here. One
term, one meaning: where a word has drifted, the alternative to avoid is named.

Definitions only. What to do lives in `docs/rules/`, the lifecycle in
`WORKFLOW.md`, decisions in `docs/adr/`.

## The workflow

**Thread ID**
The one identifier tying an issue to its task file, branch, PR title, board item,
and doc placeholders. Its shape is tier-dependent (`1613` under
`github-projects` and `labels`, `bd-a3f2dd` under `beads`); its role is identical
in all three, and every command accepts both shapes. It is what lets a command
resolve state from scratch in a fresh session.
*Avoid*: "the issue number" when you mean the role rather than the shape.

**Tracker tier**
Which issue tracker this repo runs, resolved once by `/workflow_setup` and stored
as `{{TRACKER}}`: `github-projects`, `beads`, or `labels`. A tier is a branch
inside six commands, not a setting: it decides how ready work is listed, how an
item transitions, and what closes it on merge.
*Avoid*: tracker backend, tracker mode, tracker integration.

**Gate**
One of four points where work stops until a condition holds: G1 design approved,
G2 plan approved, G3 local suite green, G4 review comments resolved. G1, G2, and
G4 are human; G3 is automated. A gate is soft unless repo settings back it, and
branch protection with required CI is what makes G3 and G4 hard.
*Avoid*: checkpoint, approval step, stage.

**Contract slot**
One of three responsibilities with exactly one owner: the state machine (owned by
the tracker tier), the resumability artifact (task files and design docs), and the
memory home (`docs/rules/` plus the `docs/` canon). Ambient tooling that claims a
slot has to be silenced, because two owners of one slot is the drift this workflow
exists to prevent.

**Bead**
A work item under the `beads` tier, identified `bd-<hash>` and stored in a local
database. A bead is an **issue** for every purpose in this workflow; the word
exists only where the tier's mechanics differ, notably that its PR body carries no
`Closes #n` and `/pick` reconciles it closed instead.

**Segue**
A deliberate pause: the workstream stops, the tangent moves to its own session, and
only findings come back. Its artifact is a **thread** file in `.llm/threads/`, and
`/segue_merge` reads that file from `## FINDINGS` onward and no further, by design.
*Avoid*: calling the thread a "conversation" or a "session"; the session is where
you discuss it, the thread is the file.

**Sizing**
The budget on one unit of work: 100 to 600 added lines and 5 to 15 files per PR,
at most five acceptance criteria per issue. A forecast crossing 600 lines
mid-implementation is a signal to stop, split, and land the current slice.

## The documents

**Doc canon**
The five directories under `docs/` whose names are load-bearing, because commands
read and write these exact paths: `rules/` (conventions), `plans/` (design docs),
`system/` (how things work now), `sop/` (procedures), `qa/` (manual test guides).
Inventing a sixth breaks the commands that route by these names.

**Rule**
One convention, one file in `docs/rules/`, with `applies_to` globs and `triggers`
keywords in frontmatter so the index can route to it. A rule says *what to do*.
*Avoid*: "the conventions doc" (there is no single one), "the style guide".

**ADR**
A decision and the cost accepted for it, one file per decision in `docs/adr/`,
numbered `NNNN-<slug>.md`. An ADR
says *why* a rule exists. Rules and ADRs are never merged: a rule that argues with
itself is a rule nobody can check.

**SOP**
A procedure somebody will repeat, in `docs/sop/`. Written from a mistake worth not
repeating, or a sequence worked out by hand once.

**Design doc**
The output of `/feature_plan`, in `docs/plans/`, approved at G1. It is a proposal.
Issues are created from it *after* approval, because issues are commitment.

**Task file**
The output of `/task_plan`, in `.llm/tasks/<id>_<slug>.md`, local and uncommitted.
It is the resumability artifact: `/implement` reloads it in a fresh session, which
is what makes a tenth resume identical to a first run.

**Non-negotiable**
One of the short list in `CLAUDE.md`: a rule stated in one line with a link to the
rule file that carries the reasoning. The list is a routing device, not a second
copy of the rules.

## The code

**Pattern budget**
The rule that six directories under `app/` are sanctioned (`services`, `forms`,
`queries`, `policies`, `lib`, `components`), and a seventh needs an ADR. A pattern
earns a place only if it recurs, the wrong default is expensive, and a reviewer can
check it in a diff.

**Sanctioned directory**
One of those six. Code that fits none of them belongs in a model method, a scope,
or a controller action, which remains the default.

**Registry**
A frozen set of variants as `Data` objects in `app/lib/`, looked up with `fetch` so
a bad key raises. Capabilities are asked of a registry entry, never inferred from
its identity.

**Result**
What an `ApplicationService` returns: success or failure, with a value or an error.
Every caller checks `success?` before touching `value`.

## The commands

**Command**
A markdown instruction file in `.claude/commands/`, mirrored to
`.cursor/commands/`. A tool with slash commands surfaces it as `/name`; a tool
without one reads and follows the file. It is not an executable, and it cannot
invoke another command.

**Long-form / short-form**
A command over about 60 lines carries the full frame (`## Instructions` with
`### Step N`, then `## Reference`). A single-action command keeps the job in a
numbered list. Both are sanctioned shapes.

**Who invokes what**
The table in `WORKFLOW.md` saying, per command, whether it is yours to type or an
agent may reach for it. An agent may run what reads and edits locally; anything
that posts, pushes, moves the board, or stands at a gate is yours.
