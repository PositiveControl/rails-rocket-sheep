# Adoption installs the alignment layer only

## Context

`rails new --template` is the only door into this product, and it only opens for
an app that does not exist yet. The alignment layer — conventions, rules,
workflow commands, the doc canon, hooks — is the part of the template that has
nothing to do with when an app was created. An app three years old benefits from
it exactly as much as an app three minutes old, and cannot have it.

The obvious version of adoption is "run the template against an existing app",
which is not possible: `template.rb` deletes `config/database.yml`, patches
`config/application.rb` and the layout by matching strings Rails generates, adds
fourteen gems, and installs Devise. Against a real app that is not an
installation, it is a demolition.

## Decision

`adopt.rb` is a second entry point, run with Rails' own mechanism:

```bash
bin/rails app:template LOCATION=/path/to/rails-rocket-sheep/adopt.rb
```

It installs the alignment layer and nothing else. It never touches `Gemfile`,
`app/`, `config/`, or `db/`. The only pre-existing files it can collide with are
`CLAUDE.md`, `AGENTS.md`, and `.gitignore`, and the first two arrive through
Thor's conflict prompt, where `d` diffs before deciding.

The same file is what `template.rb` evaluates for its own documentation phase.
That is the point: one list of what the layer contains, used by the generator, by
adoption, and by `bin/rocket-sheep-update` to decide what an update may merge. A
second copy of that list would drift, and drift is the failure mode this product
exists to prevent.

The three shared helpers and the origin stamp live in `preamble.rb`, which both
entry points `instance_eval`. They cannot be `require`d: `source_paths` has to
land on the generator's singleton class to override `Thor::Actions`'.

## Consequences

Accepted:

- **The rules describe patterns the adopting app does not have.**
  `ApplicationService`, `ApplicationForm`, the registry pattern, Slim,
  ViewComponent — the corpus documents all of them, and adoption installs none.
  This is the real cost. It is stated in the closing output, and the instruction
  is to adopt the pattern when next needed or delete the rule, because a rule
  pointing at a class that does not exist is worse than no rule. The corpus
  already has precedent: query objects and policy objects are documented
  patterns with no base class shipped.
- **A three-command app gets nineteen commands' worth of workflow.** Commands
  assume each other and assume the gates. An app whose lifecycle is different
  will delete some, and deleting is easier than inventing.
- **Adoption cannot run from a URL.** It copies the `templates/` tree beside it,
  so the repo has to be on disk. That is also what the update path wants kept.
- **`template.rb` got shorter but gained an indirection.** Its documentation
  phase is now three lines pointing at another file, which is one more hop for
  someone reading top to bottom.

## Revisit when

Someone asks for the patterns as well, at which point the answer is a third
entry point that installs base classes and gems, not a flag on this one — the
collision surface is completely different and the two should fail separately.
