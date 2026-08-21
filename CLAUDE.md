# Rails Rocket Sheep — working on the template

**This file is for agents working on *this repository* — the template generator.**

It is not the conventions file for a Rails app. The file that ships into generated
apps is [`templates/CLAUDE.md.tt`](templates/CLAUDE.md.tt), and the conventions it
routes to are in [`templates/docs/rules/`](templates/docs/rules/INDEX.md). Editing
those changes what every future generated app is told. Editing this file changes
how you work on the generator.

## What this repo is

A Rails application template (`template.rb`, ~600 lines) plus a `templates/` tree of
files it copies. There is no gem, no runtime, and no test suite. Running it produces
a Rails 8 app; that app is the product.

```bash
rails new myapp --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
rails new myapp --database=mysql      --template=/path/to/rails-rocket-sheep/template.rb
```

`--database=` is read, not re-asked. PostgreSQL, MySQL, MariaDB, mysql2 and
trilogy are supported; anything else raises before a file is written. Only
primary keys actually diverge — see
[ADR 0007](.agents/adr/0007-database-family-is-chosen-at-generation.md).

There are two other ways in, and both go through the same file list. An app that
already exists adopts the alignment layer on its own:

```bash
bin/rails app:template LOCATION=/path/to/rails-rocket-sheep/adopt.rb
```

and an app that already has the layer reconciles it against a newer template
three-way, from the commit stamped in its `CLAUDE.md`:

```bash
bin/rocket-sheep-update --check
```

## Layout

```
template.rb              The generator. Phased, top to bottom, with `say` banners.
adopt.rb                 The alignment layer, and the definition of it. Two callers.
preamble.rb              The three copy helpers and the origin stamp, shared by both.
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
├── .claude/commands/    24 workflow commands (mirrored to .cursor/commands/)
├── .cursor/rules/       Cursor pointer to the same index
├── .llm/                Task template, doc index
├── bin/rocket-sheep-update  Three-way merges a newer template into an app
└── app/ bin/ config/ …  Application code the template installs

docs/                    Product documentation for buyers. Not shipped.
README.md                Sales page. Not shipped.
```

**The distinction that matters:** anything under `templates/` is shipped and is read
by an agent in someone else's app. At the root, `template.rb`, `adopt.rb` and
`preamble.rb` are the generator; everything else there is for humans evaluating or
buying this.

## How `template.rb` works

Two helpers wrap Thor, defined in `preamble.rb`:

```ruby
copy_template_file "docs/sop/beads-setup.md"   # verbatim copy
template_file "config/database.yml.tt"         # ERB render, strips .tt
```

`source_paths` is `[templates/, repo root]`, so paths are relative to `templates/`.

Both entry points pull those in with `instance_eval(File.read(...))`, never
`require` or `load`: a `def` in an `instance_eval`'d string lands on the
generator's singleton class, where `source_paths` overrides `Thor::Actions`'. From
a `require`d file it would land on `Object`, Thor's own method would win, and every
copy would fail to find its source. `template.rb` evaluates `adopt.rb` the same way
for its alignment-layer phase — Thor's `apply` would resolve the path through
`find_in_source_paths` and look for `adopt.rb` inside `templates/`.

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
  `RULE_FILES` and `WORKFLOW_COMMANDS` in `adopt.rb`. Passing absolute paths to
  `copy_template_file` writes them to absolute destinations.
- **The alignment layer is copied by `adopt.rb`, not here.** Phase 12 evaluates it.
  A file copied anywhere else is a file adoption never installs and no update can
  ever reach, because `bin/rocket-sheep-update` reads `adopt.rb` as its manifest.
- **Branch on `POSTGRESQL` / `DB_FAMILY`, never on the adapter string.** `mysql2`
  and `trilogy` differ in the driver and in nothing a convention cares about, and
  MariaDB is MySQL for every purpose here except the label. `DB_ADAPTER`,
  `DB_LABEL`, `DB_PRIMARY_KEY`, `DB_ACCESSORY_IMAGE`, and `DB_PORT` are resolved
  once at the top and are available inside every `.tt`.

## Testing a change

There is no automated suite for *generation*, by decision
([ADR 0003](.agents/adr/0003-no-test-suite-for-generation.md)). Verification is
generating an app:

```bash
cd $(mktemp -d)
rails new probe --database=postgresql --template=/path/to/rails-rocket-sheep/template.rb
cd probe && bin/test && bin/rubocop && bin/brakeman
```

Anything touching a `.tt`, the Kamal accessory, the Dockerfile, or a primary key
has to be generated **both** ways, because half the branches are otherwise never
executed. `--skip-bundle` is enough to exercise every phase without a database
server, and `--database=sqlite3` must abort before writing a file:

```bash
for db in postgresql mysql trilogy mariadb-mysql sqlite3; do
  rails new probe-$db --database=$db --skip-bundle --template=/path/to/template.rb
done
```

`ruby -c template.rb adopt.rb preamble.rb` catches syntax errors and is worth
running on every edit, but it proves nothing about generation.

The other two entry points are verified the same way — by running them. Adoption
needs an app that did *not* come from this template, which `--minimal` gives you
cheaply:

```bash
cd $(mktemp -d)
rails new plain --minimal --skip-git && cd plain && bundle install
git init . && git add -A && git commit -m init
bin/rails app:template LOCATION=/path/to/rails-rocket-sheep/adopt.rb
git status                     # only the alignment layer, never Gemfile/app/config
```

and the update path needs two template commits and an app stamped at the first:

```bash
cd plain && git add -A && git commit -m adopt
ROCKET_SHEEP_TEMPLATE=/path/to/a/checkout bin/rocket-sheep-update --from SHA --ref SHA
```

Run adoption twice: the second run must report every file identical and must not
append to `.gitignore` again.

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
real command, every doc under `templates/` is one `template.rb` or `adopt.rb`
actually copies, every command appears in `AGENTS.md` and `WORKFLOW.md`, the origin
stamp `CLAUDE.md.tt` writes still matches the regex `bin/rocket-sheep-update` reads
it back with, and every count quoted in prose anywhere in the repo is the real
one. Run it after touching
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
  `templates/docs/adr/`, one file per decision, and ship, and decisions about *this
  generator* go in [.agents/adr/](.agents/adr/) and do not. Don't merge either
  pair.
- **A word gets one meaning, defined once.** The shipped vocabulary is
  `templates/docs/system/vocabulary.md`: thread ID, tracker tier, gate, contract
  slot, doc canon, pattern budget, and the rest, each with the near-synonym to
  avoid. Reaching for a new term for an existing thing is how "backlog" ends up
  meaning two things; add the term there and use it everywhere, rather than
  defining it again in place.
- **A declined request gets a file, not a conversation.** A no with its reasoning
  attached is reversible on the reasoning; a no in a thread gets re-argued from
  scratch every few months. New ruling → a file in
  [.agents/out-of-scope/](.agents/out-of-scope/README.md), with the ruling, the
  cost, the alternative, and what would change our mind.
- **A decision with an accepted cost is an ADR, not a comment.** Before arguing
  with how this repo is built, read `.agents/adr/`: plain-markdown commands rather
  than skills and the routing-versus-enforcement line
  ([0001](.agents/adr/0001-plain-markdown-commands-not-skills.md)), the Cursor
  mirror ([0002](.agents/adr/0002-mirror-commands-to-cursor-at-generation.md)),
  why generation has no test suite while the docs have a linter
  ([0003](.agents/adr/0003-no-test-suite-for-generation.md)), why a generated
  app records its origin without tracking it
  ([0004](.agents/adr/0004-generated-apps-record-their-origin.md)), why an update is
  a three-way merge the owner asks for rather than a channel
  ([0005](.agents/adr/0005-updates-are-a-three-way-merge-from-the-stamp.md)), and
  why adoption installs the alignment layer and nothing else
  ([0006](.agents/adr/0006-adoption-installs-the-alignment-layer-only.md)),
  why the database family is read from `rails new` while only primary keys
  diverge
  ([0007](.agents/adr/0007-database-family-is-chosen-at-generation.md)), and why a
  generated app's decisions are one file each in `docs/adr/`
  ([0008](.agents/adr/0008-decisions-are-one-file-each.md)).
  Reversing one is fine; reversing one without knowing what it bought is not.
- **Routing is plain markdown; enforcement need not be.** No harness-specific
  loading in the *routing* layer — `CLAUDE.md`, `AGENTS.md`, the rule index, the
  commands — because it has to work in Claude Code, Cursor, Codex, and a human
  with `grep`. The *enforcement* layer may be tool-specific, since it degrades to
  nothing: the hooks and `.claude/settings.json` are Claude Code only, and an
  agent elsewhere still reads the same rule. See
  [ADR 0001](.agents/adr/0001-plain-markdown-commands-not-skills.md).
- **The 24 workflow commands are mirrored** from `.claude/commands/` to
  `.cursor/commands/` at generation time, from the same source files. Never edit
  one copy — there is only one source. `bin/rocket-sheep-update` merges both
  destinations for the same reason.
- **`adopt.rb` is the manifest of the alignment layer, used three ways.** It
  installs the layer during generation, installs it into an app that already
  exists, and tells `bin/rocket-sheep-update` which files an update may merge.
  Adding a copy there is what makes a file adoptable and updatable; there is no
  second list to keep in step.
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
- **A claim about the product is checked before it is written.** `docs/faq.md`
  said the template was versioned when it had no tags and no version constant. A
  buyer-facing promise is as capable of drifting as a rule is, and nothing checks
  prose about the outside world, so read the tree before writing the sentence.
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
- `templates/docs/sop/update-from-the-template.md` — the shipped procedure for
  taking template changes into an app that already exists. It is the buyer-facing
  half of ADR 0005; keep the two in step.
- `docs/comparison.md` — the buyer-facing version of the same list: what the
  template does not have, stated so nobody buys the wrong thing.
- `templates/WORKFLOW.md` — the lifecycle the generated app follows, including the
  tracker tiering (`github-projects` / `beads` / `labels`).
