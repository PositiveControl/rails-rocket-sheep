---
description: "RuboCop the files this branch changed, and fix what it reports"
---

# When `run_lint` is invoked, execute the following command: 
  - `git fetch origin main && git diff-tree -r --no-commit-id --name-only origin/main HEAD | xargs ls -1 2>/dev/null | xargs bin/rubocop --force-exclusion`
    - lint errors found → fix
    - errors not auto-fixable → halt. Summarize issues, suggest manual fixes.