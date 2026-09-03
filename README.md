# Rails Rocket Sheep 🚀🐑

**A Rails 8 application template for building with AI coding agents: Claude Code,
Cursor, Codex, or any agent that reads a `CLAUDE.md` or `AGENTS.md`.**

`rails new` gives you a framework. Rocket Sheep gives you a codebase an agent can be
productive in on the first prompt: the patterns are already there, the conventions
are written down one rule per file, and a generated `CLAUDE.md` routes the agent to
the right rule before it touches anything, and the rules a machine can check are
checked at push time and in CI. The result is that the tenth feature looks like the
first one.

It is applied once and leaves behind ordinary Rails files you own. There is no gem,
no runtime dependency, and nothing to upgrade. MIT licensed.

```bash
rails new myapp --database=postgresql \
  --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/main/template.rb
```

---

## What it adds to `rails new`

- **Conventions an agent reads.** `CLAUDE.md`, `AGENTS.md`, and `docs/rules/` in
  the generated app, one convention per file with the right and wrong version
  side by side, and a two-tier index that routes a file path or a symptom to the
  rule that governs it.
- **Patterns before the agent arrives.** `ApplicationService` with a Result type,
  `ApplicationForm`, `ApplicationComponent`, `Data`-based registries, and a fixed
  budget of directories under `app/` so the catalogue names its own limit.
- **A workflow, not just advice.** 24 slash commands from "what should I do next"
  to a merged PR, with review gates, mirrored to Claude Code and Cursor.
- **Gates that do not depend on the agent cooperating.** An agent will eventually
  miss a rule, so the rules a machine can check are checked. `bin/gates` runs from a
  git `pre-push` hook and again in CI, for every editor and agent, and refuses
  rejected patterns, a directory outside the `app/` budget, a drifted command
  mirror, and a foreign key with no index. A query ledger fails CI on any SQL
  shape the suite emits that nobody has reviewed, and in API mode the OpenAPI
  contract fails CI when it disagrees with the request tests. Everything else
  stays prose on purpose: a gate that fires wrongly gets disabled and takes the
  useful ones with it.
- **The Rails 8 stack, configured.** Solid Queue, Cache, and Cable on their own
  databases, Devise, Petergate, PaperTrail, Discard, Bullet, RuboCop, Brakeman,
  WebMock and VCR, and a Kamal 2 deploy with a database accessory that follows
  your `--database=` choice.
- **Two modes.** Server-rendered HTML with Tailwind, Slim, ViewComponent, Hotwire,
  and a tested SEO foundation. Or `--api`, a JSON API with RFC 9457 errors, cursor
  pagination, Doorkeeper, and an OpenAPI contract generated from the request tests.
  Each mode ships the rule corpus written for it.
- **A way to stay current.** A generated app records the template commit it came
  from, and `bin/rocket-sheep-update` three-way merges newer conventions into it on
  demand. An app that never came from the template can adopt the same layer.

PostgreSQL, MySQL, and MariaDB are supported. SQLite is refused.

---

## Getting started

You need Ruby 3.3+, Rails 8.0+, `git`, and a running PostgreSQL or MySQL server.

**Server-rendered app:**

```bash
rails new myapp \
  --database=postgresql \
  --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/main/template.rb

cd myapp
rails g devise User && rails db:migrate
bin/dev                # http://localhost:3000
bin/test
```

**JSON API:**

```bash
rails new myapi --api \
  --database=postgresql \
  --template=https://raw.githubusercontent.com/PositiveControl/rails-rocket-sheep/main/template.rb

cd myapi
rails g devise User && rails db:migrate
bin/rails server
bin/test
```

Swap in `--database=mysql`, `trilogy`, `mariadb-mysql`, or `mariadb-trilogy` and
everything follows it. `main` is always the latest; to generate from a fixed
version, replace `main` in the URL with a tag from
[Releases](https://github.com/PositiveControl/rails-rocket-sheep/releases), for
example `v1.0.0/template.rb`. It is also listed on
[RailsBytes](https://railsbytes.com/templates/Vwys9d), pinned to the latest release.
The full walkthrough, including what to configure before deploying, is in
[Getting Started](docs/getting-started.md).

---

## How it compares

Jumpstart Pro and Bullet Train are SaaS starter kits: billing, teams, an admin
panel, and a gem or a git remote to keep up with. Suspenders and the other
`rails new` templates are opinionated defaults with no agent layer. Rocket Sheep
is the third thing: thin on features, and the only one that ships the conventions,
routing, and mechanical gates an AI coding agent needs to stay inside the codebase's
patterns. The row-by-row version, including where each alternative is the better
choice, is in [Comparison](docs/comparison.md).

---

## Documentation

**Using the template**

| Guide | What's in it |
|---|---|
| [Getting Started](docs/getting-started.md) | Prerequisites, first run, the first ten minutes in both modes |
| [What's Included](docs/whats-included.md) | Every gem and file the template adds, and why |
| [Working With AI Agents](docs/working-with-ai-agents.md) | How the conventions are structured, and how to extend them |
| [The Agent Workflow](docs/workflow.md) | The 24 slash commands, the gates, sizing rules, setup |
| [Agent Guardrails](docs/agent-guardrails.md) | Permissions and hooks: enforcement, not just conventions |
| [Deployment](docs/deployment.md) | Kamal from zero to a deployed app on a fresh VPS |
| [Staying Current](docs/staying-current.md) | Updating a generated app, and adopting the layer into an app that isn't one |
| [Comparison](docs/comparison.md) | Against plain `rails new`, Jumpstart Pro, and Bullet Train |
| [FAQ](docs/faq.md) | Versions, removing pieces, upgrades, licensing |

The conventions themselves ship inside every generated app as `docs/rules/`. The
source is [templates/docs/rules/](templates/docs/rules/INDEX.md), and the lifecycle
they sit in is [templates/WORKFLOW.md](templates/WORKFLOW.md).

**Working on the template**

| Doc | What's in it |
|---|---|
| [CLAUDE.md](CLAUDE.md) | How this repository is built, tested, and edited |
| [Writing a Command](docs/writing-commands.md) | The shape of a workflow command, and its Done-when |
| [Inventory & Gaps](docs/inventory.md) | What's shipped, what isn't, verification debt, what's next |
| [Architecture decisions](.agents/adr/) | Why this generator is built the way it is, one file each |
| [Out of scope](.agents/out-of-scope/README.md) | Requests already declined, with the reasoning |

**Evidence and design notes**

| Doc | What's in it |
|---|---|
| [First generation findings](docs/first-generation-findings.md) | What generating and running an API app for the first time found |
| [Adoption drift findings](docs/adoption-drift-findings.md) | What happened to the rule corpus when a real app adopted it |
| [JSON boundary audit](docs/json-boundary-audit.md) | A Rails app's JSON surface with no rules governing it |
| [Layer boundary traces](docs/layer-boundary-traces.md) | Three requests traced end to end through a real app |
| [Deterministic gates](docs/deterministic-gates.md) | Which rules are enforced mechanically, where each gate attaches, what is built, and what stays prose on purpose |
| [Skills adoption assessment](.agents/skills-adoption-assessment.md) | What was taken from the skills repo as commands, and why they did not become skills |

---

## What this is not

- **Not a SaaS starter kit.** No billing, teams, or admin panel. Each is a
  [recorded ruling](.agents/out-of-scope/README.md), not an omission.
- **Not a component library.** ViewComponent is set up with four utility
  components. The rest is yours to write.
- **Not a framework.** Everything it adds is a plain Rails file you can delete.

---

## License

[MIT](LICENSE).
