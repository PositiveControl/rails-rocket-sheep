**Feature branch:** feature/autopilot-backport

# Autopilot backport — design

Parent issue: #55. Source: PositiveControl/dopeempire at `7e612d6` (origin/master,
2026-10-03), stamped from this repo's `7e47077`. Status: **approved at G1, 2026-10-03**.

**Port base moved 2026-10-03:** `4b37255` → `7e612d6`, to carry dopeempire `2005d41` ("Rerun failed CI jobs once before autopilot halts"). At the merge gate, a red check waits out its Actions run, reruns its failed jobs once (`gh run rerun --failed`), logs a `CI rerun` row, and halts only if the checks are still red. It touches `bin/autopilot` and its tests (#61), and the merge-gate paragraphs in `autopilot.md` and `autopilot-steps.md` (#60). `df8ea66`, in the same merge, is app code and is not ported.

## Problem

Autopilot lets a multi-slice feature whose design was approved at G1 run unattended
from its first open slice to a ready feature PR. Each gate is answered by a policy
accepted at G1 and recorded in a committed log. It was built and proven in
dopeempire, which adopted the alignment layer from this template, and it exists only
there. Buyers of the template, and every app generated from it, don't have it.
Dopeempire also can't take template updates cleanly while its copy diverges.

Who it's for: an app owner who has approved a design and wants the slices done
without typing every gate's command. G1 and the merge to `main` stay human.

Some changes in the issue's comments affect the **manual** workflow as well:
- one local review round into a feature branch;
- a `**Findings:**` line in `/pr_review`;
- no CI wait into a feature branch;
- skipping the suite by path;
- narrower `/task_plan` and `/implement` reads;
- the 1h prompt-cache TTL.

These are measured improvements in their own right. They ship even if a buyer never
turns autopilot on.

## Constraints

- **ADR 0001 ceiling.** "No automatic command invocation" is a stated consequence,
  and `templates/WORKFLOW.md` *Who invokes what* repeats it. Autopilot crosses it on
  purpose. This needs a generator ADR that amends 0001; quietly editing the
  paragraph won't do.
- **Routing vs enforcement (0001).** The autopilot paragraphs in commands, the
  spec, and `WORKFLOW.md` are plain markdown and harness-neutral. The driver, guard
  hook, allowlist and `settings.json` entries are Claude Code only, and without them
  the workflow falls back to a human typing each command.
- **One source, mirrored (0002).** Command edits go under
  `templates/.claude/commands/` only.
- **Adoption installs the alignment layer only (0006).** `config/database.yml`'s
  `DB_SUFFIX` is a generator change. Adopters add it by hand, following the run
  guide.
- **`adopt.rb` is the manifest (CLAUDE.md).** Every new file under `templates/` that
  is part of the layer is copied there. Otherwise `bin/rocket-sheep-update` never
  reaches it, and `lint-docs` fails it as an uncopied doc.
- **Tokens are literal (`/workflow_setup`).** Commands read filled values and never
  probe config at run time. Anything a buyer configures is a `{{TOKEN}}`.
- **App ADRs are one file each, sequentially numbered (0008).** Collision is the
  open question below.
- **Modes (0009).** With `--api` there is no walkthrough or capture. The driver and
  the log template already branch on it, and both modes must generate green.
- **No generation test suite (0003).** Verification means generating probe apps.
  The driver's and guard's own Ruby tests ship *into* the app, the way
  `test/bin/flay_test.rb` does, and run under its `bin/test`.
- **Dopeempire-specific values** to strip or re-tokenise:
  - `master`: about 48 occurrences, 15 of them in the guard's rules;
  - `PositiveControl/dopeempire`, `ME |`, `me/`;
  - `clients/` and Godot: in the allowlist, ADR 0018, workflow-optimizations, and the
    skip-suite path list.
- **Moving source.** dopeempire#73 (the live run) is still open, and fixes are
  still landing. See the open question on the port base.

## Approach

Port it as a set of re-tokenised copies, never a rewrite. Each file's review is
"this diff against dopeempire's file shows only the declared substitutions and
deletions". The method:

1. Take each file at the port base.
2. Apply the substitution table. Re-tokenisation is a scripted `sed`, run in the
   slice and pasted into the PR body so the reviewer can replay it:
   - `PositiveControl/dopeempire` → `{{GITHUB_ORG}}/{{GITHUB_REPO}}`
   - `ME` → `{{PR_TITLE_PREFIX}}`
   - `me/` → `{{BRANCH_PREFIX}}/`
   - `ready for review` → `{{REVIEW_LABEL}}`
   - `master` → `main`
3. Strip dopeempire values.
4. Give each tier-specific step all three tier branches.

Components:

| Component | Template path | Kind |
|---|---|---|
| Spec: log template, *The driver*, *Guard* | `templates/docs/system/autopilot.md` | routing |
| Spec read by a running step: *Activation*, *Policy*, log entries, *Whose comment is it*, *Halt* | `templates/docs/system/autopilot-steps.md` | routing |
| Driver state rows, `--usage` fields | `templates/docs/system/workflow-usage.md` (minus `bin/workflow-usage`, which is #59) | routing |
| Record of each optimisation | `templates/docs/system/workflow-optimizations.md` (hash column dropped) | routing |
| Run guide, incl. hand-adding `DB_SUFFIX` | `templates/docs/sop/run-a-feature-on-autopilot.md` | routing |
| App ADR "an accepted design may run itself", extending 0014 | `templates/docs/adr/0016-an-accepted-design-may-run-itself.md` | decision |
| ADR 0014 *Amended* (review rounds) | `templates/docs/adr/0014-…md` | decision |
| *Autopilot* section; amended *Who invokes what* | `templates/WORKFLOW.md` | routing |
| Vocabulary: autopilot, autopilot log, policy, halt, pause, driver, guard | `templates/docs/system/vocabulary.md` | routing |
| Autopilot paragraphs plus manual-workflow changes | `feature_plan`, `task_plan`, `implement`, `pr_submit`, `pr_review`, `pr_comment_resolver`, `resolve_conflicts` | routing |
| Enable-autopilot question; `{{SUITE_SKIP_PATHS}}` | `workflow_setup.md` | routing |
| Driver, with one CI rerun of failed jobs before a red merge gate halts (Claude only; `--cli codex\|cursor` stubs exit non-zero naming what's missing) | `templates/bin/autopilot` + `templates/test/bin/autopilot_test.rb` + fixtures | enforcement |
| Guard (leans to deny) | `templates/bin/hooks/autopilot_guard` + `templates/test/bin/autopilot_guard_test.rb` | enforcement |
| Allowlist | `templates/.claude/autopilot-allowed-tools.txt` | enforcement |
| `PreToolUse` guard entry; `promptCacheTtl: "1h"` | `templates/.claude/settings.json` | enforcement |
| `session_end` quiet under `AUTOPILOT=1` and on a detached HEAD | `templates/bin/hooks/session_end` | enforcement |
| `DB_SUFFIX` | `templates/config/database.yml.tt` (both DB families) | generator |
| Blank optimisation report | `templates/docs/qa/autopilot-report-template.md` | routing |
| Manifest | `adopt.rb`: every path above except `database.yml.tt` | — |
| Generator ADR amending 0001's ceiling; ADR range decision | `.agents/adr/0014-…`, `.agents/adr/0015-…`; `docs/inventory.md` | — |

**Skip-suite paths become a token.** In dopeempire, `/pr_submit` hardcodes
`^(clients|docs|\.llm)/|\.md$`. In the template it becomes `{{SUITE_SKIP_PATHS}}`,
an extended regex. `/workflow_setup` fills it, defaulting to `^(docs|\.llm)/|\.md$`.
The issue suggested `workflow.config.md`, but a command must not read config at run
time, so a token it is.

## Rejected alternatives

- **Rewriting autopilot natively for the template.** It would throw away the live
  run's proof, and the merge back into dopeempire could no longer be close to a
  no-op. A three-way merge that conflicts is how we'd detect a tokenising mistake,
  and only a copy keeps that check.
- **Shipping only the routing layer (markdown, no driver).** Without the driver,
  autopilot is a human typing each command, and that already works. The driver is
  the feature.
- **Supporting Codex and Cursor in the driver now.** Their permission and hook models
  are unverified. Clear stubs follow 0001's degrade-to-nothing line, and a wrong
  adapter would be worse than none.
- **Reading skip paths from `workflow.config.md` at run time.** That breaks the
  literal-token model every other command follows.
- **Waiting for dopeempire#73 to close.** The owner chose to start now. The cost of
  starting early is covered by the final slice below.
- **Porting `bin/workflow-usage` here.** It is tracked on #59 as the first candidate
  for the backport tool, and this design doesn't widen that.

## Decisions to confirm at G1

1. **ADR numbering: the template reserves 0001–0099, and an app's own ADRs start at
   0100.** `/domain_model`'s "next number" means the next free number ≥ 0100 for an
   app's own ADR. The update SOP covers the one-time renumbering of existing
   collisions: dopeempire's 0016 → 0100 and 0017 → 0101, and its 0018 becomes the
   template's 0016. Recorded in `.agents/adr/0015`.
   - *Alternative:* the app renumbers its own ADRs on every collision. That
     recurs with every template ADR, forever.
2. **The size ceiling doesn't apply to this feature** (owner's decision, 2026-10-03).
   The usual 200–1,500 lines / 25 files per PR is waived, so slices follow
   component seams, not line counts. Most of the volume is verbatim port. What a
   reviewer reads is the tokenisation diff against dopeempire, so each PR body
   carries the command that replays it.
3. **Port base: `7e612d6` now, plus a reconcile slice.** The last slice diffs
   dopeempire from `7e612d6` to its HEAD at the time (after #73 closes, if it has),
   over the ported files, and carries any later fixes.
4. **Driver and guard tests are copied by `adopt.rb`.** They pair with
   alignment-layer bins: if an update changes the driver, it must update the driver's
   test too. `test/bin/flay_test.rb` stays generator-only, as it is now.
5. **The report template goes in `docs/qa/`.** `docs/synthesis/` isn't in the
   template's canon.

## Open questions

- Should `/workflow_setup`'s "enable autopilot?" also set `{{AUTOPILOT}}` on/off in
  the commands, or does the presence of `bin/autopilot` plus the consent line in a
  design doc suffice? **Proposal:** no token. Activation is per feature, through the
  design doc's `**Autopilot:** on` line as dopeempire does it. The wizard question
  only explains the feature and fills `{{SUITE_SKIP_PATHS}}`. The question is deferred
  to slice 1, which can decide it without changing other slices.
- The existing `/workflow_setup` bug: it names `{{FAST_CI_CHECKS*}}` but the commands
  hardcode names. Slice 1 touches `/pr_submit` Step 6 anyway. **Proposal:** fix it in
  slice 1, since the token is already filled by the wizard. Flagged so the scope is
  explicit.

## Decomposition

All slices go into `feature/autopilot-backport`. The feature PR to `main` is human.

| # | Slice | Contents | Size | Depends on |
|---|---|---|---|---|
| 1 (#60) | Routing layer: spec, decisions, commands | `autopilot.md`, `autopilot-steps.md`, `workflow-usage.md`, `workflow-optimizations.md`, run guide, report template, app ADR 0016, ADR 0014 amendment, `WORKFLOW.md`, vocabulary, `.agents/adr/0014` + `0015`, inventory, `/domain_model` numbering line; 7 command edits (autopilot paragraphs + manual-workflow changes), `{{SUITE_SKIP_PATHS}}` and `{{FAST_CI_CHECKS*}}` wired, `/workflow_setup` autopilot question; `adopt.rb` doc copies; `lint-docs` green | ~1,900 | — | <!-- lint-docs:ignore -->
| 2 (#61) | Enforcement layer: guard, hooks, driver | `autopilot_guard` + test, allowlist, `session_end` divergence, `settings.json` (`PreToolUse`, 1h TTL), `bin/autopilot` + tests + fixtures, Claude adapter + `--cli` stubs, `DB_SUFFIX` in `database.yml.tt`, `adopt.rb` | ~4,450 | 1 (guard halt message and driver cite `autopilot-steps.md`) |
| 3 (#62) | Reconcile and verify | Diff dopeempire `7e612d6..HEAD` over the ported files and carry fixes; probe apps for postgresql, mysql and `--api` running `bin/gates` and `bin/test`; adoption run twice on a `--minimal` app | 0–400 | 1, 2 |

Then, outside the slices: the feature PR to `main`. **No release follows it**
(owner, 2026-10-03), because more changes will be added first. Release v1.2.0 and
dopeempire's `bin/rocket-sheep-update --check`, which covers #55's criterion 5, are
deferred until those changes land.

## Docs impact

- **New, shipped:** the five `docs/system/` and `docs/sop/` files above, app ADR 0016,
  and `docs/qa/autopilot-report-template.md`. Each one is a placeholder in its slice.
- **Updated, shipped:**
  - `templates/WORKFLOW.md`, `vocabulary.md`, ADR 0014, `.llm/README.md` index;
  - `templates/CLAUDE.md.tt`, a pointer line to the autopilot spec;
  - `templates/docs/sop/update-from-the-template.md`, for ADR renumbering.
- **Generator:**
  - `.agents/adr/0014` (amends 0001) and `0015` (ADR range);
  - the ADR list in root `CLAUDE.md`, `docs/inventory.md`, and `docs/comparison.md`
    if it says "no automation";
  - the README feature list, checked before it is written.
