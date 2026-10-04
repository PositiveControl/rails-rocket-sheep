---
description: "RuboCop and flay the files this branch changed, and fix what they report"
---

# Run Lint

Lint only the files this branch touched, and fix what comes back. The full-suite
run belongs to CI; this is the fast check before a commit. Takes no argument:
`/run_lint`.

1. Lint the changed files. `<BASE>` is the task file's `Base:` line (`.llm/tasks/<id>_*.md`), `main` when there is none:

   ```bash
   git fetch origin <BASE> && git diff-tree -r --no-commit-id --name-only origin/<BASE> HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion
   ```

2. Offences that RuboCop can correct: fix them.
3. Offences it cannot: stop, summarise what is left, and say what the manual fix
   is. Do not silence a cop to make the run pass.
4. RuboCop has no clone detection. Run `bin/flay origin/<BASE>` (no `bin/flay` → skip). It fails on Ruby the branch copies that `<BASE>` lacks: IDENTICAL blocks, or a method or class copied and renamed.
   - Copied → call the existing copy or extract the shared code; never paste another copy
   - Similar shape → a warning; reuse it only if it is the same idea
   - Every copy marked `+` → duplication that already existed, edited in lockstep; extract it or split that edit out
