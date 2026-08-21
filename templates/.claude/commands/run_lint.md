---
description: "RuboCop the files this branch changed, and fix what it reports"
---

# Run Lint

Lint only the files this branch touched, and fix what comes back. The full-suite
run belongs to CI; this is the fast check before a commit. Takes no argument:
`/run_lint`.

1. Lint the changed files:

   ```bash
   git fetch origin main && git diff-tree -r --no-commit-id --name-only origin/main HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion
   ```

2. Offences that RuboCop can correct: fix them.
3. Offences it cannot: stop, summarise what is left, and say what the manual fix
   is. Do not silence a cop to make the run pass.
