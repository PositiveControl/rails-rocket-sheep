# The Agent Workflow

Every generated app ships with 19 slash commands that drive work from "what should I do next" through to a merged PR. This is the piece that turns the conventions in `CLAUDE.md` from advice into a process.

Full spec, diagrams, and gate definitions live in the generated app's `WORKFLOW.md`. This page is the orientation.

---

## The chain

```
/pick (entry, routes by state) → /feature_plan → /task_plan → /implement → /pr_submit → human merge → automation
```

Every command ends by naming the next one, so the workflow self-navigates. `/pick` is the entry door for every session — it surfaces prioritized ready work and routes each item by shape and tracker state.

```mermaid
flowchart LR
  PK["/pick"] --> FP["/feature_plan"]
  FP --> G1{{"G1 design approved"}}
  G1 --> TP["/task_plan"]
  PK --> TP
  TP --> G2{{"G2 plan approved"}}
  G2 --> IM["/implement"]
  PK --> IM
  IM --> G3{{"G3 suite green"}}
  G3 --> PS["/pr_submit"]
  PS --> G4{{"G4 comments resolved"}}
  G4 --> MG["human merges"]
  MG --> AU["automation: issue closed, board Done, branch deleted"]
```

## Why a workflow at all

The conventions layer stops an agent writing *inconsistent* code. It does nothing about the other failure modes:

- **Unbounded scope.** An agent handed "add billing" will happily produce a 2,000-line PR nobody can review.
- **Lost state between sessions.** Close the laptop mid-feature and the next session starts from nothing.
- **Work that skips review.** Code that never had a plan approved, or shipped with a stale doc placeholder.

The workflow fixes those with three mechanisms: **gates**, **the thread ID**, and **sizing rules**.

---

## Gates

Four checkpoints. Two human approvals, one automated check, one review.

| # | Gate | Where | Kind | Blocks |
|---|---|---|---|---|
| G1 | Design doc approved | `/feature_plan` | Human | Issue creation — issues are commitment, the doc is a proposal |
| G2 | Implementation plan approved | `/task_plan` | Human | Any code |
| G3 | Local suite green | `/pr_submit` | Automated | Push / PR creation |
| G4 | Review comments resolved | `/pr_submit` | Human | Merge |

Gates are prompt-enforced by default. Branch protection with required CI checks turns G3 and G4 into hard gates that GitHub enforces rather than the agent.

The design of G1 is the non-obvious one: the agent may not create issues until you've approved the design. Issues are a commitment; a design doc is a proposal you can throw away cheaply.

---

## The thread ID

One identifier connects every artifact. This is what lets any command reconstruct state from scratch — any session, any machine, no handoff notes. Its shape depends on the tracker tier — a GitHub issue number (`1613`), or a bead ID (`bd-a3f2dd`) — but its role is the same, and every command accepts both. The diagram shows the GitHub form.

```mermaid
flowchart LR
  ID(("issue #n")) --> TF["task file<br/>.llm/tasks/n_slug.md"]
  ID --> BR["branch<br/>prefix/n/slug"]
  ID --> PR["PR title<br/>PREFIX | n | description"]
  ID --> CL["PR body<br/>Closes #n"]
  ID --> BD["board item<br/>status = state"]
  ID --> DOC["doc placeholders<br/>docs/sop · docs/system"]
```

Practical effect: `/implement` is idempotent. Run it in a fresh session with no memory of the previous one and it reloads the task file, orients itself, and continues. State lives in the tracker and in the task file — never in a conversation.

---

## Sizing

Grounded in analysis of 100 merged PRs: under 300 added lines merged in a median of one day; 600+ took three.

| Size | Added lines | Guidance |
|---|---|---|
| XS | <100 | Fine; consider batching with related work |
| S | 100–300 | Ideal — merges in ~1 day |
| M | 300–600 | Healthy upper bound |
| L | 600–1,200 | Split if possible; expect ~3-day review |
| XL | 1,200+ | Must split |

An issue fits when its acceptance criteria fit in ≤5 testable bullets. More than that is an epic — decompose it.

**Scope-escape rule:** if a forecast passes 600 added lines mid-implementation, or new acceptance criteria appear, stop. Split a sub-issue and land the current slice clean. This is the rule that prevents the runaway PR.

---

## Segues

`/segue` is the escape valve. Mid-planning or mid-implementation you hit a question that deserves real thought but would derail the current thread — a library choice, a data-model concern, an unexpected constraint.

```
/segue        open an isolated thread
/segue_close  write findings and the path forward
/segue_merge  merge findings back into the workstream
/segue_resume pick up an open thread in a fresh session
/segue_kill   abandon a dead end, recording why it died
```

Only the *findings* merge back — not the exploration. The workstream stays clean, and the reasoning is preserved rather than lost in scrollback.

---

## Command inventory

| Command | Tier | Job |
|---|---|---|
| `/pick` | Core | Entry door. Prioritized ready work; routes epic → `/feature_plan`, sized Todo → `/task_plan`, In Progress → `/implement`, Blocked → show blocker |
| `/feature_plan` | Core | Explore → design doc (G1) → sized sub-issues + doc placeholders → Todo |
| `/task_plan` | Core | Read design doc → task file + plan (G2) → branch → In Progress |
| `/implement` | Core | Idempotent resume: load task file, orient, execute, commit per logical unit |
| `/pr_submit` | Core | Suite (G3) → docs complete-or-delete → PR (with `Closes #n` where the tier uses it) → stack footer → comments (G4) |
| `/pr_review` | Core | Reviewer side: full-context diff review |
| `/pr_qa` | Core | Guided manual QA pass, structured report |
| `/update_docs` | Core | On-demand deep doc pass; keeps the index honest |
| `/rails_code_review` | Core | Rails-specific review against this stack's conventions |
| `/segue` ×5 | Optional | Isolated discussion threads with findings-only merge-back |
| `/pr_comment_resolver` | Optional | Work through review comments |
| `/pr_fix_ci` | Optional | Diagnose and fix a failing CI run |
| `/test_fix` | Optional | Fix failing tests |
| `/run_lint` | Optional | Lint and auto-fix |
| `/workflow_setup` | Setup | One-time wizard: tracker tier, repo, board, naming, CI checks |

---

## Tracker tiers

The workflow needs somewhere to hold state. Three options, chosen once by `/workflow_setup`; every command branches on the resulting literal rather than probing at run time.

| Tier | For | Setup cost | What you get |
|---|---|---|---|
| `github-projects` | You have or want a Projects v2 board | A board with five statuses | Richest state, automatic close-on-merge, parent/sibling context |
| `beads` | GitHub Issues without a board, or you want real dependency semantics | `bd` + `dolt` + a running `dolt sql-server` | Blocker-aware "what's ready", first-class dependencies, atomic claim |
| `labels` | No tracker at all | Five labels, created for you | Nothing to run; no dependency tracking, no context tree |

The one real behavioural difference is how work reaches **Done**:

- `github-projects` and `labels` — `Closes #n` in the PR body closes the issue on merge. Fully automatic.
- `beads` — no `Closes #n` equivalent exists, so `/pick` reconciles at session start: any bead marked up-for-review whose PR has merged gets closed. No CI job, no webhook, and it self-heals if you skip a session.

Everything else — the four gates, sizing rules, task files, the doc canon, segues — is identical across tiers.

**Choosing:** if you already run a Projects board, use it. If you don't and don't want to, `beads` buys genuinely better "what should I work on next" semantics at the cost of two binaries and a background daemon on your machine. If that cost isn't worth it, `labels` works and needs nothing.

`beads` setup is documented in the generated app at `docs/sop/beads-setup.md`.

## Setup

The commands arrive with stack tokens already filled — test, lint, and security-scan commands, and the default branch, are known because this template *is* the stack. What remains is repo-specific.

```
/workflow_setup
```

The wizard collects your GitHub org and repo, creates or connects a Projects board, resolves the board's field and option IDs, asks for branch and PR naming conventions, confirms the pre-filled tool commands, and verifies repo automation settings.

Restart your Claude session afterwards, then run `/pick`.

### Requirements

All tiers:
- A GitHub repo with a remote (the wizard stops without one)
- `gh` CLI authenticated

Tier `github-projects` additionally:
- A Projects v2 board with statuses: Todo, In Progress, Up for Review, Done, Blocked
- Board operations need `gh auth refresh -s project`

Tier `beads` additionally:
- `bd` and `dolt` installed, and a running `dolt sql-server`

### Repo automation

All tiers want **"Automatically delete head branches"** enabled on the repo.

Tier `github-projects` adds two more, and with them merging is a single human click and everything downstream is automatic:

1. **Board workflow "item closed → status Done"** — enabled on the project
2. **`Closes #N` in every PR body** — `/pr_submit` writes this automatically

Tier `labels` uses `Closes #N` too. Tier `beads` deliberately does not — reconciliation happens in `/pick`.

---

## Contract slots

Exactly one owner per slot. This matters if you run other agent tooling alongside — memory systems, indexers, background agents. Anything claiming authority over a slot below will fight the workflow, so silence its competing instructions or don't run it.

| Slot | Owner |
|---|---|
| State machine | GitHub issues + Projects board |
| Resumability artifact | Task files in `.llm/tasks/` (local, gitignored) |
| Memory home | `CLAUDE.md` + the `docs/` canon |

---

## Using only part of it

The commands are markdown files. Delete what you don't want.

Ten of the nineteen commands touch no tracker at all — `/pr_qa`, `/rails_code_review`, `/run_lint`, `/test_fix`, `/update_docs`, and all five `segue_*`. They work standalone on any repo.

The tiers exist so the other nine degrade rather than break. If you don't use GitHub at all, delete `.claude/commands/` and `.cursor/commands/`; the rest of the template is unaffected.

**Jira and Linear are not supported, and deliberately so.** The tracker interface is only about four verbs, but the thread ID doesn't survive the move: `Closes #n` is GitHub-native, and both the branch name and PR title key off a repo-local integer. Jira in practice means smart-commits and `PROJ-123` titles — a second convention set rather than an adapter swap, plus permanent maintenance against two vendor APIs. The `beads` tier covers the same "my issues aren't in GitHub Projects" buyer at a fraction of the cost.
