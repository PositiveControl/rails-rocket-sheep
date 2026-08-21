# Working With AI Agents

This is the part that makes Rocket Sheep different from other Rails templates. Everything else — Devise, Kamal, Tailwind — you could assemble yourself in an afternoon. This is the part that's tedious to get right and easy to get wrong.

---

## The problem

An AI agent working in a fresh Rails app has no opinions to inherit, so it invents them. Each session, plausibly, and differently.

Session one puts order creation in a service object. Session two puts refund logic directly in the controller — also defensible, also idiomatic Rails, also inconsistent with session one. Session three sees both and picks whichever was closer in the context window.

The failure isn't bad code. It's *divergent* code. Three months in you have four ways to do the same thing and no way to tell an agent which one is correct, because none of them is written down as correct.

## The approach

Three things, in order of importance:

1. **Make the pattern exist in code before the agent arrives.** An agent shown `ApplicationService` with three subclasses will write a fourth subclass. An agent shown nothing will write whatever it likes.
2. **Write the convention down where the agent reads it.** `CLAUDE.md` is loaded into context automatically by Claude Code. Conventions there are constraints. Conventions in your head are not.
3. **Name the anti-patterns explicitly.** Models follow negative examples well, but only when they're given some. "Don't write N+1 queries" is weak. A before/after pair is strong.

---

## What's in the generated `CLAUDE.md`

### Workflow rules

Planning goes in `docs/plans/` before non-trivial features. TDD — tests first, commit when green. Flaky tests get fixed immediately rather than skipped. Small focused commits. Docs updated as features land, with a `grep` for existing docs first so the agent doesn't create a fifth file about the same subject.

That last rule matters more than it looks. Without it agents accumulate near-duplicate documentation indefinitely.

### Style rules, stated as absolutes

- Slim, never ERB
- Service objects for business logic; form objects for multi-model submits
- Components for markup with logic; partials with strict locals for the rest
- Seven actions per controller — a new verb is a new resource
- Validation failures render `status: :unprocessable_content`
- Scopes, not class methods, for queries
- Primary keys per database: UUIDs and `t.uuid :parent_id` on PostgreSQL, bigint and `t.references` on MySQL
- `destroy` by default; Discard only where a table earns soft deletes
- PaperTrail for audit trails
- Registries (`Data` objects, `fetch` lookup) for fixed variant sets

Absolutes work better than preferences. "Prefer service objects" gets interpreted as a suggestion. "Service objects for business logic" gets followed.

### Worked examples in both directions

Every pattern appears twice — the bad version and the good version:

```ruby
# BAD: Hardcoded entity knowledge in service
PLANS = { free: 0, pro: 29 }

# GOOD: Query registry for capabilities
PlanRegistry[plan_type].price_cents
PlanRegistry[plan_type].has_feature?(:api_access)
```

The bad example is doing the work. It names the specific mistake the agent would otherwise make.

### Slim pitfalls

Slim's parser conflicts with Tailwind's bracket syntax, and an agent that doesn't know this produces templates that fail at render time:

```slim
/ Tailwind brackets conflict with Slim — use class=""
div class="max-h-[85vh]"

/ Text starting with ( needs a span wrapper
span.count = "(#{count})"

/ Multi-line Ruby needs a ruby: block
ruby:
  config = { foo: { label: "Foo" } }

/ Strict locals in a partial — exact syntax, first line
/# locals: (order:, compact: false)
```

This section alone prevents a recurring class of failure.

### Two pattern docs, one index

`CLAUDE.md` states the rules in short form and points at the reasoning:
`docs/rules/` for the backend (controllers, services, forms,
queries, policies, jobs, caching) and the view
layer. Both carry a "when not to" for every pattern and a table of patterns
explicitly rejected — repository, CQRS, hexagonal, interactor chains, DI
containers.

Keeping the detail out of `CLAUDE.md` matters for a boring reason: the same rule
written in three places drifts, and the agent then has three answers.

---

## Extending the conventions

`CLAUDE.md` is a living file. The rule of thumb: **when you correct an agent twice for the same thing, that correction belongs in `CLAUDE.md`.**

Good additions:

- A decision you made and don't want revisited → `docs/system/architecture.md` as an ADR, referenced from `CLAUDE.md`
- A procedure with a specific correct order → `docs/sop/`
- A mistake the agent keeps making → the anti-patterns section, with a before/after pair
- A domain rule the code doesn't express → the conventions section

Keep it dense. `CLAUDE.md` is loaded into context on every session, so length is a real cost. Prefer a tight example over a paragraph of prose.

### What not to put in it

- **Anything derivable from the code.** The agent can read your models. Don't maintain a copy of the schema.
- **History.** Git already has it.
- **Aspirations.** "We should eventually migrate to X" is noise until it's a plan in `docs/plans/`.

---

## The docs directories

The generated app ships `docs/rules/` (one convention per file, with a routing index) plus a four-directory doc canon. The names are load-bearing — every workflow command in `.claude/commands/` reads and writes these exact paths, so renaming one breaks the commands. They give an agent a place to put durable work:

| Directory | Contents | Written by |
|---|---|---|
| `docs/plans/` | Design docs, written before issues exist | `/feature_plan` |
| `docs/system/` | How things currently work — architecture state, ADRs, model reference | `/pr_submit`, `/update_docs` |
| `docs/sop/` | Procedures someone will need to repeat | `/pr_submit`, `/update_docs` |
| `docs/qa/` | Manual test guides for flows automated tests don't cover | `/pr_qa` |

`.llm/README.md` indexes committed docs only, so an agent can find what already exists before writing a duplicate. `.llm/tasks/` and `.llm/threads/` are local scratch and gitignored.

The point is continuity. An agent that writes a plan in session one can read it in session five. Without somewhere to put it, that analysis is re-derived every time — slowly, and slightly differently.

---

## Honest limitations

- **Conventions drift under pressure.** An agent deep in a long debugging session will violate `CLAUDE.md` occasionally. It reduces divergence; it doesn't eliminate it.
- **Claude Code is the primary target, but not the only one.** `docs/rules/` is the single source and it is plain markdown with YAML frontmatter, readable by anything; `CLAUDE.md`, `.cursor/rules/conventions.mdc`, and `AGENTS.md` all route to the same index, and the workflow commands are mirrored to `.cursor/commands/` from the same source files. A tool with no slash-command concept can still be told to follow a command file directly. What doesn't transfer is hooks — those are Claude Code-specific, so enforcement (as opposed to instruction) is weaker elsewhere.
- **Opinionated means opinionated.** If you dislike service objects or Slim, this template is fighting you rather than helping. That's a reason not to buy it, and it's better said here than discovered later.
