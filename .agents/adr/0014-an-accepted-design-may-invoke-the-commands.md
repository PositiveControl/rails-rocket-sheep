# An accepted design may invoke the commands; nothing else may

Amends [0001](0001-plain-markdown-commands-not-skills.md).

## Context

ADR 0001 accepted a ceiling: **no automatic command invocation.** A command names
the next command, and a human types it. `templates/WORKFLOW.md` repeats it under
*Who invokes what*, so nobody writes a step that expects automation.

What that ceiling bought was the checkpoint. Every gate — approving a plan, ruling
on a disputed finding, merging — had a person at it, because nothing could reach
the gate without one.

An adopting app (dopeempire) measured the cost. On a multi-slice feature whose
design was already approved, most of the person's touches between G1 and the
feature PR were approvals of things the design had settled, and a three-slice
feature took a day at the keyboard. It built autopilot: the developer approves a
written policy at G1, a driver script runs each step as a fresh agent process, and
every answer the policy gives is written to a committed log. It then ran features
through it, and issue #55 ports it here.

The driver invokes `/task_plan`, `/implement`, `/pr_submit`, `/pr_review` and
`/pr_comment_resolver` without a human typing them. That is exactly what 0001
ruled out.

## Decision

The ceiling has one exception, and only one: **a multi-slice feature whose design
was approved at G1 with autopilot consent.** For that feature, `bin/autopilot` may
invoke the commands a slice needs, and each command follows its *Autopilot*
paragraphs in place of asking.

Everything else in 0001 stands:

- **Routing stays plain markdown.** The *Autopilot* paragraphs in the commands, the
  spec in `templates/docs/system/autopilot-steps.md`, and `WORKFLOW.md`'s
  *Autopilot* section are markdown any harness can read.
- **Enforcement is harness-specific and degrades to nothing.** The driver, the
  guard hook, the allowlist and the `settings.json` entries are Claude Code only.
  Without them, a person types each command and every gate asks, as before. Other
  CLIs get stubs in the driver that fail clearly, never a guessed adapter.
- **Outside an autopilot run, the ceiling holds.** Commands follow their
  *Autopilot* paragraphs only when the design doc says `**Autopilot:** on` **and**
  `AUTOPILOT=1` is set, which only the driver does. A person running a command by
  hand is asked.
- **G1 and the merge to `main` stay human.** A single-slice feature never runs on
  autopilot, because its PR targets `main`.

The generated app's own reasoning is
`templates/docs/adr/0016-an-accepted-design-may-run-itself.md`. This ADR is the
generator's side: why the template ships a driver at all.

## Consequences

- The checkpoint moves rather than disappears: to the policy approved at G1 and to
  the autopilot log read at the feature PR. Both are weaker than a person at each
  gate, and the halt list is where that is priced.
- The template ships its largest piece of executable code in the alignment layer,
  and the first that runs agents. It ships with its test suite, which an adopter's
  `bin/test` runs.
- *Who invokes what* in `templates/WORKFLOW.md` now states an exception, not a
  flat ceiling. A future request to invoke commands automatically elsewhere is a
  request to widen this ADR, not to follow a precedent.

## Revisit when

A second harness's permission and hook model is verified well enough to write a
real adapter, or the subagent definition tracked as gap 4 in `docs/inventory.md`
offers a narrower way to sequence a slice than a driver script.
