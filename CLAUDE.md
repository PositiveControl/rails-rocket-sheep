# Rails Rocket Sheep — working on the template

**This file is for agents working on *this repository* — the template generator.**

It is not the conventions file for a Rails app. The file that ships into generated
apps is [`templates/CLAUDE.md.tt`](templates/CLAUDE.md.tt), and the conventions it
routes to are in [`templates/docs/rules/`](templates/docs/rules/INDEX.md). Editing
those changes what every future generated app is told. Editing this file changes
how you work on the generator.

## What this repo is

A single Rails application template (`template.rb`, ~680 lines) plus a `templates/`
tree of files it copies. There is no gem, no runtime, and no test suite. Running it
produces a Rails 8 app; that app is the product.

```bash
rails new myapp --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
```

## Layout

```
template.rb              The generator. Phased, top to bottom, with `say` banners.
bin/lint-docs            Checks the docs still agree with the tree. Run on every doc edit.
docs/writing-commands.md The shape a workflow command has to have, and its Done-when.
.agents/adr/             Why this repo is built the way it is. Read before re-opening one.
.agents/out-of-scope/    Requests already declined, with the reasoning. Check before building one.
templates/               Everything copied into the generated app.
├── CLAUDE.md.tt         The generated app's conventions file (ERB)
├── AGENTS.md            Tool-neutral pointer to it
├── WORKFLOW.md          Lifecycle spec shipped to the app
├── docs/rules/          38 single-rule convention files + INDEX.md
├── docs/system/         ADRs, models reference
├── docs/sop/            Procedures
├── .claude/commands/    19 workflow commands (mirrored to .cursor/commands/)
├── .cursor/rules/       Cursor pointer to the same index
├── .llm/                Task template, doc index
└── app/ bin/ config/ …  Application code the template installs

docs/                    Product documentation for buyers. Not shipped.
README.md                Sales page. Not shipped.
```

**The distinction that matters:** anything under `templates/` is shipped and is read
by an agent in someone else's app. Anything at the root except `template.rb` is for
humans evaluating or buying this.

## How `template.rb` works

Two helpers wrap Thor, defined at the top:

```ruby
copy_template_file "docs/sop/beads-setup.md"   # verbatim copy
template_file "config/database.yml.tt"         # ERB render, strips .tt
```

`source_paths` is `[templates/, repo root]`, so paths are relative to `templates/`.

Phases run in order and are labelled with `say`. Rules that are easy to get wrong:

- **Solid Stack configs are re-copied in `after_bundle`** (`SOLID_CONFIGS`). Rails 8
  runs `solid_*:install` after bundling and overwrites anything written earlier.
- **Injections into Rails' own files match on content.** `config/application.rb`,
  `config/environments/development.rb`, and the layout are patched by matching
  strings Rails generates. A new Rails release can break generation — see
  `docs/inventory.md`, item 10.
- **Two `inject_into_file` calls with the same anchor will nest.** The development
  environment injection is one block for exactly this reason; the comment above it
  explains the failure.
- **Directory globs are mapped to relative paths before copying** — see
  `RULE_FILES` and `WORKFLOW_COMMANDS`. Passing absolute paths to
  `copy_template_file` writes them to absolute destinations.

## Testing a change

There is no automated suite for *generation*, by decision
([ADR 0003](.agents/adr/0003-no-test-suite-for-generation.md)). Verification is
generating an app:

```bash
cd $(mktemp -d)
rails new probe --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
cd probe && bin/test && bin/rubocop && bin/brakeman
```

`ruby -c template.rb` catches syntax errors and is worth running on every edit, but
it proves nothing about generation.

The docs *are* checked, by `bin/lint-docs`:

```bash
bin/lint-docs            # exits 0 clean, 1 with a list of findings
```

It asserts what an agent in a generated app is asked to trust: every rule has
complete frontmatter with `id` matching its filename, every rule has a row in all
three `INDEX.md` tables with a matching token count, the read-cost figures in
`INDEX.md` match the corpus, every `{{TOKEN}}` a command uses is one
`/workflow_setup` fills, every path a command names resolves under `templates/`,
every command carries a parseable `description` (and an `argument-hint` wherever
it reads `$ARGUMENTS`), every command opens with an H1 and carries the long-form
frame once it passes 60 lines, every backticked `/name` a command mentions is a
real command, every command appears in `AGENTS.md` and `WORKFLOW.md`, and every count
quoted in prose anywhere in the repo is the real one. Run it after touching
`templates/docs/rules/`, `templates/.claude/commands/`, or any doc that names a
count. A line that legitimately names a different count, or a path the command
creates at runtime, carries a `lint-docs:ignore` marker.

## Conventions for editing this repo

- **One fact, one file.** The whole doc architecture is built on it. Before adding
  a rule or a paragraph, `grep` for the fact — if it exists, link to it instead.
  Duplicated conventions drift, and drift is the failure mode this product exists
  to prevent.
- **A fact about the tree gets checked, not asserted.** Counts, index rows, token
  budgets, and paths are all things `bin/lint-docs` can verify, so prose that
  states one has to pass it. Run it before you commit a doc change; a doc that
  disagrees with the tree is worse than no doc, because the agent cannot tell.
- **Rules go in `templates/docs/rules/`, one per file**, with complete frontmatter
  (`id`, `applies_to`, `triggers`, `see_also`, `tokens`). The `id` must match the
  filename. Add rows to all three tables in `INDEX.md` — route by path, route by
  symptom, full list.
- **Rules say what to do. ADRs say why it was chosen.** There are two ADR homes,
  because there are two products: decisions about a *generated app* go in
  `templates/docs/system/architecture.md` and ship, and decisions about *this
  generator* go in [.agents/adr/](.agents/adr/) and do not. Don't merge either
  pair.
- **A declined request gets a file, not a conversation.** A no with its reasoning
  attached is reversible on the reasoning; a no in a thread gets re-argued from
  scratch every few months. New ruling → a file in
  [.agents/out-of-scope/](.agents/out-of-scope/README.md), with the ruling, the
  cost, the alternative, and what would change our mind.
- **A decision with an accepted cost is an ADR, not a comment.** Before arguing
  with how this repo is built, read `.agents/adr/`: plain-markdown commands rather
  than skills and the routing-versus-enforcement line
  ([0001](.agents/adr/0001-plain-markdown-commands-not-skills.md)), the Cursor
  mirror ([0002](.agents/adr/0002-mirror-commands-to-cursor-at-generation.md)), and
  why generation has no test suite while the docs have a linter
  ([0003](.agents/adr/0003-no-test-suite-for-generation.md)). Reversing one is
  fine; reversing one without knowing what it bought is not.
- **Routing is plain markdown; enforcement need not be.** No harness-specific
  loading in the *routing* layer — `CLAUDE.md`, `AGENTS.md`, the rule index, the
  commands — because it has to work in Claude Code, Cursor, Codex, and a human
  with `grep`. The *enforcement* layer may be tool-specific, since it degrades to
  nothing: the hooks and `.claude/settings.json` are Claude Code only, and an
  agent elsewhere still reads the same rule. See
  [ADR 0001](.agents/adr/0001-plain-markdown-commands-not-skills.md).
- **The 19 workflow commands are mirrored** from `.claude/commands/` to
  `.cursor/commands/` at generation time, from the same source files. Never edit
  one copy — there is only one source.
- **Commands follow [docs/writing-commands.md](docs/writing-commands.md).** The
  frame (`# Title`, job line, `## Instructions` with `### Step N`, `## Reference`),
  the frontmatter, the conventions, and a Done-when checklist split into what
  `bin/lint-docs` checks and what only reading can. A short single-action command
  keeps the job in a numbered list instead; the spec says which is which.
- **Every command declares a `description`, and an `argument-hint` if it takes an
  argument.** Quote both values: a description containing a colon parses as a map,
  and a hint in brackets parses as a list. The description is what a human reads
  in a picker while deciding whether to run the command, so it states the job in
  one line under 80 characters — no trigger phrasing ("use when…"), which belongs
  to things a model invokes rather than a person.
- **Product docs at the root describe the template; they do not restate its rules.**
  `README.md` and `docs/` link into `templates/docs/rules/` rather than copying it.

## Where things are decided

- `.agents/adr/` — why this repo is built the way it is, and what each choice cost.
- `docs/inventory.md` — what's shipped, what's missing, verification debt, and the
  ordered list of what to do next. Read it before proposing work.
- `.agents/out-of-scope/` — requests already declined, one file each, with why the
  cost is not worth paying, what to do instead, and what would change our mind. If
  a request sounds like billing, tenancy, an admin panel, API scaffolding, or a
  fourth tracker tier, read the ruling before designing anything.
- `docs/comparison.md` — the buyer-facing version of the same list: what the
  template does not have, stated so nobody buys the wrong thing.
- `templates/WORKFLOW.md` — the lifecycle the generated app follows, including the
  tracker tiering (`github-projects` / `beads` / `labels`).
