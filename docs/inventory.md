# Inventory, Gaps, and Low-Hanging Fruit

What a generated app actually contains, what it doesn't, and what's cheap to add next. Written as a working document for deciding what to build, not as marketing.

Status key: **✅ shipped** · **⚠️ partial** · **❌ absent**

---

## What a generated app looks like

```mermaid
flowchart TB
  subgraph AGENT ["Agent alignment layer"]
    CM["CLAUDE.md<br/>conventions + anti-patterns"]
    WF["WORKFLOW.md<br/>lifecycle spec"]
    CMD[".claude/commands/<br/>19 slash commands"]
    IDX[".llm/README.md<br/>doc index"]
    TSK[".llm/tasks/<br/>resumable task files"]
  end

  subgraph DOCS ["Doc canon"]
    DP["docs/plans<br/>design docs"]
    DSY["docs/system<br/>architecture state"]
    DSO["docs/sop<br/>procedures"]
    DQ["docs/qa<br/>manual test guides"]
  end

  subgraph APP ["Application"]
    SVC["ApplicationService<br/>+ Result"]
    REG["RegistryBase"]
    MOD["Models<br/>UUID · Discard · PaperTrail"]
    VW["Slim + Tailwind<br/>+ Stimulus"]
    SEO["SEO foundation<br/>+ tests"]
  end

  subgraph INFRA ["Infrastructure"]
    SOLID["Solid Stack<br/>4 databases"]
    KAM["Kamal 2 + Docker"]
    CI["GitHub Actions CI<br/>scan · lint · test"]
  end

  CM --> CMD
  CMD --> DOCS
  CMD --> TSK
  IDX --> DOCS
  CM --> APP
  APP --> INFRA
```

---

## Inventory

### Agent alignment

| Item | Status | Notes |
|---|---|---|
| `CLAUDE.md` conventions | ✅ | Style, patterns, anti-patterns with before/after pairs, Slim pitfalls |
| Workflow commands | ✅ | 19 commands, `/pick` → merge |
| `WORKFLOW.md` spec | ✅ | Lifecycle diagrams, gates, sizing, contract slots |
| Doc canon | ✅ | 4 dirs, names load-bearing (commands read/write them) |
| Doc index (`.llm/README.md`) | ✅ | Was referenced by 3 commands but missing — now shipped |
| Task template | ✅ | Resumable task file format |
| `/workflow_setup` wizard | ✅ | Stack + CI tokens pre-filled; asks only repo/board/naming |
| Project `.claude/settings.json` | ✅ | Allowlist + deny rules; credentials blocked from context |
| Hooks | ✅ | RuboCop on Ruby edits, Slim bracket check, Draft-placeholder Stop hook |
| Subagent definitions | ❌ | No `.claude/agents/` — see gap 4 |
| Cross-tool parity | ✅ | `AGENTS.md` + commands table, `.cursor/rules/conventions.mdc`, commands mirrored to `.cursor/commands/` |
| MCP config | ❌ | No `.mcp.json` |

### Application

| Item | Status | Notes |
|---|---|---|
| Service objects | ✅ | `ApplicationService` + `Result` struct, log helpers |
| Registry pattern | ✅ | `RegistryBase` + working `AppConfig` reference |
| UUID primary keys | ✅ | Wired through generators |
| Soft deletes | ✅ | Discard |
| Audit trail | ✅ | PaperTrail `--with-changes` |
| Pagination | ✅ | Pagy |
| Auth | ✅ | Devise (Turbo-configured) + Petergate |
| Frontend | ✅ | Slim, Tailwind, 2 generic Stimulus controllers |
| SEO | ✅ | robots, sitemap, meta, canonical, JSON-LD, integration tests, Lighthouse CI |
| Fixture generator override | ✅ | Prevents the unique-index collision on first test run |
| Billing | ❌ | Deliberate — see [comparison](comparison.md) |
| Teams / multi-tenancy | ❌ | Deliberate |
| Admin panel | ❌ | Deliberate |
| Component library | ❌ | Deliberate |
| API scaffolding | ❌ | Deliberate |
| Seeds / demo data | ✅ | Idempotent admin user, generated password, production-guarded |

### Infrastructure

| Item | Status | Notes |
|---|---|---|
| Solid Stack | ✅ | Queue, Cache, Cable — separate databases, all environments |
| Kamal 2 | ✅ | Postgres accessory bound to localhost, entrypoint migrates |
| CI | ✅ | Rails 8 default: `scan_ruby`, `scan_js`, `lint`, `test` |
| Dependabot | ✅ | Rails 8 default |
| Lint / security | ✅ | RuboCop Omakase, Brakeman — clean on a fresh app |
| Job worker in deploy | ⚠️ | Documented in [deployment](deployment.md), not pre-configured — see gap 6 |
| Job dashboard | ❌ | Mission Control not wired up |
| Backups | ❌ | Documented as day-one work, no automation |
| Uptime monitoring | ❌ | Documented, not provided |
| PR / issue templates | ⚠️ | Deferred — blocked on the tracker-abstraction segue |
| CODEOWNERS | ❌ | Low value for a solo buyer |

---

## Gaps: shipped and remaining

The first wave targeted the weakness that mattered most: **the alignment layer was entirely advisory.** `CLAUDE.md` told an agent what to do; nothing stopped it doing otherwise. Hooks changed that.

```mermaid
flowchart LR
  subgraph BEFORE ["Before: instruction only"]
    A["CLAUDE.md says<br/>'run bin/rubocop'"] -.->|"agent may ignore"| B["commit"]
  end
  subgraph AFTER ["Now: enforcement"]
    C["agent edits .rb"] --> D["PostToolUse hook<br/>runs rubocop"] --> E["fails → fed back<br/>agent must fix"]
  end
```

### ✅ Shipped

**1. `.claude/settings.json` permission allowlist.** Covers the template's binstubs and read-only git/gh, so agents stop asking to run `bin/test`. Deny rules block reading `master.key`, `.kamal/secrets`, and `.env*` into context, and block `push --force` / `reset --hard` / `clean -fd`. Tracked in git as shared config; personal overrides go in the gitignored `settings.local.json`.

**2. Hooks.** `bin/hooks/post_edit` runs RuboCop on edited Ruby and catches Tailwind bracket classes in Slim shorthand — the pitfall `CLAUDE.md` documents but that otherwise fails at render time. `bin/hooks/session_end` reports `Status: Draft` doc placeholders left open. All three exit 0 on any internal error: a broken hook must never block work. See [Agent Guardrails](agent-guardrails.md).

**5. `AGENTS.md`.** Tool-neutral pointer to `CLAUDE.md` with an orientation table. Deliberately a pointer, not a second source — anything restated would drift. `.cursorrules` still absent.

**7. Seeds.** `db/seeds.rb` creates an admin user, idempotent, password from `SEED_ADMIN_PASSWORD` or generated and printed once, and refuses to run in production without `SEED_ALLOW_PRODUCTION=1`.

### ⏸ Blocked

**3. PR and issue templates — ~30 min.** Unblocked by the tracker segue, but now the last step of a three-phase piece of work rather than a standalone task — the PR template must be tier-neutral, with `Closes #n` injected by `/pr_submit` only under the GitHub-Projects tier. See *Tracker tiering* below.

---

## Decided: tracker tiering

Settled by segue `.llm/threads/2026-08-06-tracker-abstraction.md` (merged). Full plan: `~/.claude/plans/composed-leaping-abelson.md`.

**Three tiers, resolved once by `/workflow_setup` into a `{{TRACKER}}` token:**

| Tier | For | State machine |
|---|---|---|
| `github-projects` | Today's buyer | Projects v2 board, `Closes #n` automation — unchanged |
| `beads` | GitHub Issues without a board | `bd` CLI, detected not shipped; real dependency semantics via `bd ready` |
| `labels` | No tracker at all | `status:*` labels; nothing hard-fails |

**Rejected, so they don't get re-tread:** Jira/Linear adapters (the interface is ~4 verbs, but the thread ID breaks entirely — `Closes #n` is GitHub-native and `prefix/n/slug` keys off a repo-local integer; Jira means smart-commits and a second convention set, not an adapter swap). Shipping `bd init` in `template.rb` — beads needs a running `dolt sql-server`, so the cost is CLI + second binary + daemon added to a product that today needs only Postgres.

**Coupling is three layers, not one:** forge ops (9 files calling `gh` — not worth abstracting, Jira shops still host code on GitHub), the Projects v2 board (5 files, ~4 verbs — the only real coupling), and issue-number-as-thread-ID (a convention, zero calls).

**Phases:**

1. **Agent-harness parity (~4h)** — ✅ done. Command prose neutralised, commands mirrored to `.cursor/commands/` from the same source files, `.cursor/rules/conventions.mdc` added, `AGENTS.md` gained a commands table so a harness with no slash-command concept can be told to follow a file directly.
2. **Tracker tiering (~1.5–2d)** — ✅ done. `/workflow_setup` resolves the tier first and fills `{{TRACKER}}`; `pick`, `feature_plan`, `task_plan`, `pr_submit`, and `implement` branch on the literal. Lazy reconciliation in `/pick` replaces the lost `Closes #n` automation under `beads`. `WORKFLOW.md` §2 and §4 are tier-aware; `docs/sop/beads-setup.md` covers the `dolt sql-server` requirement.
3. **Item 3 (~30m)** — next: tier-neutral PR template, GitHub-tier issue templates.

**Load-bearing assumption, unmeasured:** that a minority of small Rails shops on GitHub use Projects v2 rather than plain Issues. This justifies the beads tier existing. If Projects v2 is near-universal among buyers, Phase 2 is over-built. The design doesn't collapse if it's wrong — it just costs more than it returns.

### Remaining

**4. A `code-reviewer` subagent — ~2 hours.** `/rails_code_review` exists as a command, so the content is written. Packaging it as a `.claude/agents/` definition lets it run in its own context window rather than consuming the main one.

**6. Job worker in `deploy.yml` — ~30 min.** Solid Queue needs a worker. [Deployment](deployment.md) explains the `job:` role and the `SOLID_QUEUE_IN_PUMA` alternative but ships neither. A commented-out `job:` role turns a documentation step into an uncomment.

**8. `docs/qa/` and `docs/plans/` examples — ~30 min.** Both ship empty. One worked QA guide and one design-doc template would make `/pr_qa` and `/feature_plan` output more consistent.

---

## Known weak points

Not gaps to fill — things to be honest about.

**Jira and Linear buyers still aren't served.** The three tiers cover GitHub Projects, GitHub Issues via beads, and no tracker at all — but a shop whose issues live in Jira gets the ten tracker-independent commands and nothing else. That was a deliberate call (the thread ID doesn't survive the move; see [workflow](workflow.md)), but the sales page must say so rather than letting buyers discover it.

**19 commands is a lot to learn.** The chain is self-navigating, which mitigates it, but the first-run experience is a directory of 19 unfamiliar files. A single "start here" path — `/workflow_setup` then `/pick` — is documented but easy to miss.

**Template generation is version-coupled.** The template patches specific Rails files by matching their content. Rails 8.1 or 9 could break generation. Already-generated apps are unaffected, but the product needs re-verification against each Rails release, and that's ongoing maintenance nobody is scheduled to do.

**Conventions drift under pressure.** An agent deep in a long debugging session violates `CLAUDE.md` occasionally. This reduces divergence; it doesn't eliminate it. Gap 2 is the only real answer.

---

## Suggested order

```mermaid
flowchart LR
  DONE["✅ 1 settings · 2 hooks<br/>5 AGENTS.md · 7 seeds"] --> SEG{"segue:<br/>tracker abstraction"}
  SEG --> T3["3. PR/issue templates"]
  DONE --> T4["4. reviewer subagent"]
  T4 --> T8["8. doc examples"]
  T8 --> T6["6. job role"]
```

The cheap alignment gaps are closed. Item 3 unblocks when the segue resolves. Items 4, 6, and 8 are worth doing but can wait for buyer feedback — which is the point at which guessing stops and evidence starts.
