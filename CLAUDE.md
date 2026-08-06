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
templates/               Everything copied into the generated app.
├── CLAUDE.md.tt         The generated app's conventions file (ERB)
├── AGENTS.md            Tool-neutral pointer to it
├── WORKFLOW.md          Lifecycle spec shipped to the app
├── docs/rules/          36 single-rule convention files + INDEX.md
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

There is no automated suite. Verification is generating an app:

```bash
cd $(mktemp -d)
rails new probe --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
cd probe && bin/test && bin/rubocop && bin/brakeman
```

`ruby -c template.rb` catches syntax errors and is worth running on every edit, but
it proves nothing about generation.

## Conventions for editing this repo

- **One fact, one file.** The whole doc architecture is built on it. Before adding
  a rule or a paragraph, `grep` for the fact — if it exists, link to it instead.
  Duplicated conventions drift, and drift is the failure mode this product exists
  to prevent.
- **Rules go in `templates/docs/rules/`, one per file**, with complete frontmatter
  (`id`, `applies_to`, `triggers`, `see_also`, `tokens`). The `id` must match the
  filename. Add rows to all three tables in `INDEX.md` — route by path, route by
  symptom, full list.
- **Rules say what to do. ADRs say why it was chosen.** `templates/docs/system/architecture.md`
  holds the decisions and their accepted costs. Don't merge the two.
- **Everything is plain markdown.** No harness-specific loading anywhere in
  `templates/` — the routing has to work in Claude Code, Cursor, Codex, and a
  human with `grep`. A feature only one tool supports doesn't go in.
- **The 19 workflow commands are mirrored** from `.claude/commands/` to
  `.cursor/commands/` at generation time, from the same source files. Never edit
  one copy — there is only one source.
- **Product docs at the root describe the template; they do not restate its rules.**
  `README.md` and `docs/` link into `templates/docs/rules/` rather than copying it.

## Where things are decided

- `docs/inventory.md` — what's shipped, what's missing, verification debt, and the
  ordered list of what to do next. Read it before proposing work.
- `docs/comparison.md` — deliberate scope exclusions (billing, teams, admin, API).
  If a request sounds like one of those, check here first.
- `templates/WORKFLOW.md` — the lifecycle the generated app follows, including the
  tracker tiering (`github-projects` / `beads` / `labels`).
