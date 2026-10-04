# Workflow config

Written by `/workflow_setup` on 2026-10-03. Re-running the wizard reads this as defaults.

| Token | Value |
|---|---|
| `{{TRACKER}}` | `labels` |
| `{{GITHUB_ORG}}` | `PositiveControl` (personal account — GraphQL uses `user(login:)`) |
| `{{GITHUB_REPO}}` | `rails-rocket-sheep` |
| `{{BRANCH_PREFIX}}` | `feat` → `feat/<id>/<slug>` |
| `{{PR_TITLE_PREFIX}}` | *(none — segment dropped; titles are `<issue> \| <description>`)* |
| `{{REVIEW_LABEL}}` | `ready for review` |
| `{{FAST_CI_CHECKS}}` | `docs, generate (web), generate (api)` (hardcoded names replaced in pr_submit, pr_comment_resolver, pr_fix_ci) |
| `{{FAST_CI_CHECKS_JQ}}` | `"docs","generate (web)","generate (api)"` |
| `{{SLOW_CI_CHECKS}}` | *(none)* |
| `{{SUITE_SKIP_PATHS}}` | `^$` (nothing skips the suite: `bin/test` checks the docs) |
| Board tokens (`PROJECT_*`, `STATUS_*`) | `n/a` |
| `{{PERSONA}}` | `Staff Rails Engineer, TDD advocate` |
| Iteration filter in `/pick` | off |
| Default branch | `main` |
| Lint / test / scan | n/a here — verification is `templates/bin/lint-docs`, `ruby -c template.rb adopt.rb preamble.rb`, probe generation (see CLAUDE.local.md) |
