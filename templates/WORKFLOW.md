# Dev Workflow — Spec & Diagrams

Command-driven lifecycle for any coding agent, on any of three tracker tiers. Diagrams are mermaid — they render
natively on GitHub, GitLab, and VS Code. No external dependencies.

**Tracker tier: `{{TRACKER}}`** — one of `github-projects`, `beads`, `labels`, resolved once by `/workflow_setup`.
Where this spec says "board", read it as whatever your tier uses to hold state; §2 gives the mapping.

## The chain

```
/pick (entry, routes by state) ⇢ /feature_plan → /task_plan → /implement → /pr_submit → human merge → automation → deploy (per-team SOP)
```

Every command ends by naming the next one — the workflow self-navigates. `/pick` is the entry door, not a chain stage: it surfaces prioritized ready work and routes by item shape + board state.

## 1. Lifecycle master map

The filled node at top is the entry: every session starts at `/pick`. `/feature_plan` feeds new sub-issues back to it. `/segue` is the escape valve off planning and implementation — an isolated discussion thread whose findings merge back without polluting the workstream.

```mermaid
flowchart TB
  E((" "))
  PK["/pick — ENTRY — routes by shape + board state"]
  E --> PK
  subgraph R1 [" "]
    direction LR
    FP["/feature_plan — design doc → docs/plans/ — parent + sized sub-issues"]
    G1{"G1 — design approved"}
    TP["/task_plan — task file + impl plan — branch prefix/#35;n/slug"]
    G2{"G2 — plan approved"}
    FP --> G1
    TP --> G2
  end
  PK -. "epic / unshaped: decompose" .-> FP
  G1 -. "sub-issues on board" .-> PK
  PK -- "sized Todo issue" --> TP
  subgraph R2 [" "]
    direction LR
    IM["/implement — code + tests — commit per logical unit"]
    G3{"G3 — suite green"}
    PS["/pr_submit — local suite + docs resolved — PR with Closes #35;n"]
    RV["review — /pr_review · /pr_qa · /pr_comment_resolver"]
    G4{"G4 — comments resolved"}
    MG["human merges"]
    IM --> G3 --> PS --> RV --> G4 --> MG
  end
  subgraph R3 [" "]
    direction LR
    AUTO["automation — issue closed → board Done — branch auto-deleted"]
    DEP["deploy — per-team SOP slot"]
    AUTO -.-> DEP
  end
  SG1["/segue thread (planning valve)"]
  SG2["/segue thread (implementation valve)"]

  G2 --> IM
  MG --> AUTO
  PK -. "In Progress: resume" .-> IM
  TP -. blocked on a decision .-> SG1 -. findings merge .-> TP
  IM -. rabbit hole .-> SG2 -. findings merge .-> IM
  IM -. "scope escape: forecast &gt;600 lines" .-> FP

  style E fill:#0F7480,stroke:#0F7480
  style PK fill:#0F7480,stroke:#0B3A40,color:#FFFFFF
  style G1 fill:#F6E9D8,stroke:#A6651A,color:#5C3A0F
  style G2 fill:#F6E9D8,stroke:#A6651A,color:#5C3A0F
  style G3 fill:#E3EFE6,stroke:#3E7C4F,color:#1F4229
  style G4 fill:#F6E9D8,stroke:#A6651A,color:#5C3A0F
  style MG fill:#F6E9D8,stroke:#A6651A,color:#5C3A0F
  style AUTO fill:#E3EFE6,stroke:#3E7C4F,color:#1F4229,stroke-dasharray:4 3
  style DEP fill:#FDFDFB,stroke:#5F6E7C,stroke-dasharray:4 3,color:#3D4954
  style FP fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style TP fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style IM fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style PS fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style RV fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style SG1 fill:#FDFDFB,stroke:#5F6E7C,stroke-dasharray:4 3,color:#3D4954
  style SG2 fill:#FDFDFB,stroke:#5F6E7C,stroke-dasharray:4 3,color:#3D4954
  style R1 fill:none,stroke:none
  style R2 fill:none,stroke:none
  style R3 fill:none,stroke:none
```

Legend: teal = command · filled teal = entry · amber = human gate · green = automated gate / automation · dashed grey = optional / out of core.

## 2. State machine

The tracker is the single state home. Commands fire the transitions. State lives in the tracker — never in a session's memory.

How each tier stores the five states:

| State | `github-projects` | `beads` | `labels` |
|---|---|---|---|
| Todo | board status Todo | `status: open` | `status:todo` |
| In Progress | board status In Progress | `status: in_progress` (`bd update --claim`) | `status:in-progress` |
| Up for Review | board status Up for Review | `lifecycle=up_for_review` — event bead + label | `status:up-for-review` |
| Done | board status Done | `status: closed` | issue closed |
| Blocked | board status Blocked | `status: blocked`, surfaced by `bd blocked` | `status:blocked` |

`beads` has no native "Up for Review" status, so `/pr_submit` uses `bd set-state <id> lifecycle=up_for_review`, which records an event bead *and* attaches a queryable label.

The **Done** transition differs by tier and is the one real behavioural difference between them:

- `github-projects` and `labels` — `Closes #n` in the PR body closes the issue on merge; the board's "item closed" workflow then sets Done. Fully automatic.
- `beads` — no `Closes #n` equivalent exists. `/pick` reconciles lazily at session start: any bead in `lifecycle:up_for_review` whose linked PR has merged gets closed. No CI job, no webhook, and it self-heals if a session is skipped.

```mermaid
stateDiagram-v2
  direction LR
  [*] --> Todo : /feature_plan creates issues
  Todo --> InProgress : /task_plan — plan approved
  InProgress --> UpForReview : /pr_submit
  UpForReview --> InProgress : changes requested
  UpForReview --> Done : merge → Closes #n closes issue → board automation
  InProgress --> Blocked : dependency hit
  Blocked --> InProgress : unblocked
  Done --> [*]
```

## 3. Swimlanes and gates

Human touches are few and high-leverage: two approvals, one review, one merge click. Everything crossing into the human lane is a gate.

```mermaid
flowchart TB
  subgraph H ["Human"]
    direction LR
    H1["approve design doc"]
    H2["approve impl plan"]
    H3["review PR"]
    H4["click merge"]
  end
  subgraph C ["Claude session"]
    direction LR
    C0["/pick — surface + route work"]
    C1["explore + draft design"]
    C2["decompose to sized sub-issues"]
    C3["task file + impl plan + branch"]
    C4["implement · test · commit units"]
    C5["run suite · resolve docs · open PR"]
    C6["address review comments"]
  end
  subgraph G ["GitHub + CI"]
    direction LR
    G1b["issues on board: Todo"]
    G2b["board: In Progress"]
    G3b["fast checks: lint · scans"]
    G4b["auto: issue closed → Done — branch deleted"]
  end

  C0 --> C1 --> H1 --> C2 --> G1b
  G1b --> C0
  C0 --> C3 --> H2 --> C4 --> G2b
  C4 --> C5 --> G3b --> H3 --> C6 --> H4 --> G4b

  style H fill:#F6E9D8,stroke:#A6651A,color:#5C3A0F
  style C fill:#E3F0F1,stroke:#0F7480,color:#0B3A40
  style G fill:#E3EFE6,stroke:#3E7C4F,color:#1F4229
  style C0 fill:#0F7480,stroke:#0B3A40,color:#FFFFFF
```

## 4. The thread ID

The linchpin. One identifier connects every artifact, which is what lets each command resolve state from scratch — any session, any machine, no handoff notes.

The identifier's *shape* is tier-dependent — a GitHub issue number (`1613`) under `github-projects` and `labels`, a bead ID (`bd-a3f2dd`) under `beads` — but its **role is identical in all three**, and every command accepts both shapes. The diagram below shows the `github-projects` form.

```mermaid
flowchart LR
  ID(("issue #35;n"))
  TF["task file — .llm/tasks/n_slug.md (local)"]
  BR["branch — prefix/n/slug"]
  PR["PR title — PREFIX | n | description"]
  CL["PR body — Closes #35;n → auto-close"]
  BD["board item — status = lifecycle state"]
  DOC["doc placeholders — docs/sop · docs/system"]
  DD["design doc — docs/plans/ (via parent)"]

  ID --> TF
  ID --> BR
  ID --> PR
  ID --> CL
  ID --> BD
  ID --> DOC
  ID --> DD

  style ID fill:#0F7480,stroke:#0B3A40,color:#FFFFFF
```

Under `beads` two edges change: the PR body carries **no** `Closes #n` line, and the "board item" is a bead whose `external_ref` (`gh-<pr>`) is the link `/pick` follows to reconcile it closed. Everything else — task file, branch, PR title, doc placeholders, design doc — is unchanged.

## 5. Tiers

| Tier | Contents |
|---|---|
| **Core** (ships as-is) | `/pick`, `/feature_plan`, `/task_plan`, `/implement`, `/pr_submit`, `/pr_review`, `/pr_qa`, `/update_docs` + 4 gates + conventions |
| **Optional** (adopt piecemeal) | `/segue` ×5, `/pr_comment_resolver`, `/pr_fix_ci`, `/test_fix`, `/run_lint` |
| **Parameterized** (wizard fills) | org/repo/board IDs, default branch, branch + PR title prefixes, lint/test/scan commands, CI check names, review label, persona, iteration filter |
| **Per-team slots** | conventions file (CLAUDE.md), deploy SOP |

Inclusion principle: a tool earns a core spot only if a lifecycle gate or transition breaks without it. Everything else is ambient tooling, governed by non-interference (below).

## Contract slots

Terms used throughout this document (thread ID, tier, gate, contract slot, bead,
segue, sizing) are defined once in [`docs/system/vocabulary.md`](docs/system/vocabulary.md).


Exactly one owner per slot. Ambient tooling a team runs (memory systems, indexers, personas, background agents) must not claim authority over any of them — silence competing instructions or don't run the tool.

| Slot | Owner |
|---|---|
| State machine | The configured tracker tier (Todo → In Progress → Up for Review → Done, + Blocked). See §2 for the per-tier mapping |
| Resumability artifact | Task files + design docs (local, uncommitted; `/implement` reloads them in any fresh session) |
| Memory home | `docs/rules/` (one convention per file, routed by `docs/rules/INDEX.md`) + `docs/` canon for system knowledge; CLAUDE.md names the non-negotiables and links out |

## Gates

| # | Gate | Where | Kind | Blocks |
|---|---|---|---|---|
| G1 | Design doc approved | `/feature_plan` | Human | Issue creation — issues are commitment, the doc is a proposal |
| G2 | Implementation plan approved | `/task_plan` | Human | Any code |
| G3 | Local suite green | `/pr_submit` | Automated | Push / PR creation |
| G4 | Review comments resolved | `/pr_submit` + review | Human | Merge |

Soft vs hard: gates are prompt-enforced unless backed by repo settings. Branch protection with required CI turns G3/G4 hard.

**Repo prerequisites**, by tier:

- All tiers: "Automatically delete head branches" enabled.
- `github-projects`: Projects workflow "item closed → set status Done" enabled · `Closes #N` in every PR body (`/pr_submit` does this).
- `labels`: `Closes #N` in every PR body. The five `status:*` labels exist (`/workflow_setup` creates them).
- `beads`: `bd` on PATH with a reachable database, which needs a running `dolt sql-server` — see `docs/sop/beads-setup.md`. PR bodies must **not** carry `Closes #N`.

## Who invokes what

A command is a markdown file. Anyone who can read it can follow it: you by typing
`/name`, or an agent already in a session that decides the situation fits. That
second case is useful for some of these commands and wrong for others, so the
split is stated rather than left to judgment.

**The criterion.** An agent may reach for a command that reads the repo and edits
files locally. A command that writes somewhere other people see, or that stands at
a gate, is yours to invoke. Posting a review, moving a board item, opening a PR,
resolving a conversation, and approving a plan are all decisions with an audience,
and an agent choosing its own moment to do them removes the checkpoint the gate
exists to create.

| Command | Invoked by | Why |
|---|---|---|
| `/pick` | You | Chooses what to work on next; that is the session's premise, not a step in it |
| `/feature_plan` | You | Ends at G1, and creates issues, which are commitment |
| `/task_plan` | You | Ends at G2, and G2 is the approval that lets code start |
| `/implement` | You | Starts from an approved plan; the approval is the entry condition |
| `/pr_submit` | You | Opens a PR, moves the board, and carries G3 and G4 |
| `/pr_review` | You | Posts review comments on someone else's work |
| `/pr_comment_resolver` | You | Replies to and resolves conversations other people are reading |
| `/pr_qa` | You | Guides a human through a manual pass; there is no pass without the human |
| `/update_docs` | You | Rewrites and deletes across the doc tree; scope is a judgment call |
| `/workflow_setup` | You | Interactive, once, and writes the config every other command reads |
| `/segue`, `/segue_resume`, `/segue_close`, `/segue_merge`, `/segue_kill` | You | The point is that *you* decided to stop the workstream |
| `/run_lint` | Either | Reads the diff, runs RuboCop, fixes locally. Nothing leaves the machine |
| `/test_fix` | Either | The suite is already red; triage and a local fix are bounded work |
| `/rails_code_review` | Either | Reads the branch and reports. It posts nothing |
| `/pr_fix_ci` | Either, up to a point | Reading a failed run and fixing locally is fair game; pushing the fix is yours |

**Either** means an agent may follow the file when the situation calls for it, and
that you can still type it. It does not mean the agent should run it speculatively:
`/test_fix` when the suite is red, not on a hunch.

### A command cannot invoke a command

Each command ends by naming what runs next, and that chain is what makes the
workflow navigable. The naming is an instruction to **you**, not automation: there
is no mechanism by which one of these files invokes another. `/pick` routing an
epic to `/feature_plan` means it tells you to run `/feature_plan`.

This matters when writing one. A step that reads "then run `/task_plan`" will not
happen on its own. Either the step does the work inline, or the command ends and
says what to type. Where a real handoff is wanted rather than a suggestion, the
mechanism is a subagent definition under `.claude/agents/`, which this template
does not ship yet.

## Sizing

Grounded in analysis of 100 merged PRs: under 300 added lines merged in a median of 1 day; 600+ took 3. An issue fits when its acceptance criteria fit in ≤5 testable bullets — more is an epic; decompose.

| Size | Added lines | Guidance |
|---|---|---|
| XS | <100 | Fine as-is; consider batching with related work |
| S | 100–300 | Ideal — merges in ~1 day |
| M | 300–600 | Healthy upper bound |
| L | 600–1,200 | Split if possible; expect ~3-day review |
| XL | 1,200+ | Must split, or accept slow and shallower review |

**Scope-escape rule:** mid-implementation forecast passes 600 added lines or new acceptance criteria appear → stop, split a sub-issue, land the current slice clean.

## Command inventory

| Command | Tier | Job |
|---|---|---|
| `/pick` | Core | Entry door: prioritized ready work + context trees; routes epic/unshaped → `/feature_plan`, sized Todo → `/task_plan`, In Progress → `/implement`, Blocked → show blocker. Enforces sizing at the door |
| `/feature_plan` | Core | Explore → design doc (G1) → sized sub-issues + doc placeholders → board Todo |
| `/task_plan` | Core | Read design doc → task file + plan (G2) → branch → In Progress |
| `/implement` | Core | Idempotent resume: load task file, orient, execute, commit per logical unit |
| `/pr_submit` | Core | Suite (G3) → docs complete-or-delete → PR with `Closes #n` → stack footer (`bin/pr-stack`) → comments (G4) |
| `/pr_review` | Core | Reviewer side: full-context diff review |
| `/pr_qa` | Core | Guided manual QA pass, structured report |
| `/update_docs` | Core | On-demand deep doc pass; keeps the index honest |
| `/segue`, `/segue_resume`, `/segue_close`, `/segue_merge` | Optional | Isolated discussion thread; findings-only merge-back |
| `/segue_kill` | Optional | Abandon a dead-end segue: record why it died, skip the merge |
| `/rails_code_review` | Optional | Rails-specific review of a branch against this stack's conventions |
| `/pr_comment_resolver`, `/pr_fix_ci`, `/test_fix`, `/run_lint` | Optional | Utilities called by core commands |
| `/workflow_setup` | Setup | One-time wizard: parameters, conventions, token fill, automation checks |

## Documentation rules

- Doc canon: `docs/rules` (one convention per file + `INDEX.md`), `docs/plans` (design docs), `docs/system` (architecture state), `docs/sop` (procedures), `docs/qa` (manual test guides)
- `.llm/README.md` indexes **committed docs only**; `.llm/tasks/` and `.llm/threads/` are local scratch (gitignored)
- Doc updates happen at defined points only: `/feature_plan` creates placeholders, `/pr_submit` completes-or-deletes them (+ index dupe/dead-link check), `/update_docs` for deep passes
- Never merge a PR leaving a Draft placeholder behind
