---
description: "Resolve an in-progress merge or rebase conflict, then prove it green"
---

# Resolve Conflicts

Finish a merge or rebase that stopped on conflicts: resolve every hunk on the evidence of why each side changed, then prove the tree is still green. Fixing a *red CI run* is `/pr_fix_ci`; this is the conflicted working tree in front of you. Takes no argument: `/resolve_conflicts`.

Always resolve. Never `git rebase --abort` or `git merge --abort` to escape — that throws away the work and the next attempt hits the same hunks.

1. See where you are:

   ```bash
   git status
   git log --oneline --left-right --boundary HEAD...MERGE_HEAD 2>/dev/null || git log --oneline -10
   git diff --diff-filter=U --name-only
   ```

2. Find the primary source for each side of each conflict before touching it: the commit message that introduced it, the PR, the issue. Two changes that look incompatible usually have compatible intents.

3. Resolve each hunk. Preserve both intents where they can coexist; where they genuinely cannot, keep the one matching the goal of the merge and say what the trade-off cost. Never invent behaviour that neither side had.

4. The generated files that must not be hand-merged:

   | File | Do this instead |
   |---|---|
   | `db/schema.rb` | Take either side, then regenerate: `bin/rails db:migrate` (or `db:schema:dump`). A hand-merged schema disagrees with the migrations, and only one of the two is the truth |
   | `Gemfile.lock` | Resolve `Gemfile` first, then `bundle install` and commit what it writes |
   | `db/migrate/*` | Never renumber or edit a migration that has run elsewhere. Both sides' migrations survive; check for one lost to the rebase with `git log --diff-filter=D -- db/migrate/`. Conventions: `docs/rules/safe-migrations.md` |
   | `.llm/tasks/*`, `.llm/threads/*` | Local scratch. Take the version belonging to this branch's thread |

5. Prove it:

   ```bash
   bin/rubocop --force-exclusion $(git diff --diff-filter=U --name-only --cached)
   bin/test
   ```

   Failures caused by the merge are yours to fix here. Failures that pre-date it are `/test_fix`.

6. Finish the operation, all the way:

   ```bash
   git add -A && git rebase --continue    # or: git commit  (for a merge)
   ```

   Repeat from step 1 for each remaining commit a rebase stops on. Done means `git status` reports no rebase or merge in progress.

7. Report what conflicted, how each hunk was resolved, and any trade-off you took. Then name what runs next: `/run_lint` before committing more, `/pr_submit` once the branch is clean, `/pr_fix_ci` if CI is still red after the push.
