# QA walkthroughs — a script that shows a reviewer the change

A branch with a user-facing change ships with a script in `script/qa/` that walks a reviewer
through it: it builds the data, drives a real browser to each changed page, outlines the element
that changed and captions it on screen. In the terminal, Enter advances and Esc quits; other keys
are ignored. `/qa_walkthrough <issue>` writes the script (`.claude/commands/qa_walkthrough.md`);
the human QA pass and its report in `docs/qa/` remain `/pr_qa`'s.

Web mode only. An API-only app has no pages to walk, ships no `bin/qa-walkthrough`, and skips
the step with a one-line reason in the PR body.

## Where it sits in the workflow

Every branch, not just features. `/task_plan` ends the Next Actions with the walkthrough steps the
change adds (or the reason it has nothing to show), so they are sized and approved with the rest.
`/implement` lands them like any other action. `/pr_submit` Step 3b gates: the steps are on the
branch → one unattended run; they are missing and the diff touches views, components, controllers,
helpers or JavaScript → the developer is asked, with *create* as the default and two named skips
(covered by an existing walkthrough; not worth one). Nothing user-facing → skipped with a line in
the PR body. `/qa_walkthrough <issue>` does the writing: it extends the parent feature's script
when one exists and starts one otherwise. An API-only app has no pages and skips all of this.

## Running one

```bash
bin/dev                                    # the script drives your own server
bin/qa-walkthrough <name>                  # guided: headed Chrome, Enter advances, Esc quits
QA_AUTO=1 QA_HEADLESS=1 bin/qa-walkthrough <name>   # unattended: a PNG per step
```

`bin/qa-walkthrough` with no argument lists what is available. Screenshots land in
`tmp/qa_walkthrough/<name>/NN.png`; the unattended mode is how an agent checks the script it
wrote and how a reviewer who cannot sit through it still sees every screen. `QA_HOST=url` points
it at a server other than `http://localhost:3000`. Chrome and a matching chromedriver come from
Selenium Manager inside the `selenium-webdriver` gem, the same way system tests get them.

## How it is built

`lib/qa_walkthrough.rb` is the whole framework — about a hundred lines on top of gems already
here. It runs inside `rails runner`, so a script has ActiveRecord and the app's services for data,
and Capybara + Selenium (in `:development, :test` rather than `:test` for this) for the browser.
Two primitives:

- `step "caption" do ... end` — announces, runs the block, paints the caption on screen, pauses.
  A step that raises is reported and skipped, so one bad selector costs a screen, not the run.
- `spotlight css` / `spotlight text: "Shipping", exact: true, note: "…"` — outlines the element
  (for `text:`, the parent of the element whose own text matches) and scrolls to it. `note` is
  the caption's second line: where the number comes from.

Plus `sign_in(user, password:)` through Devise's stock form. The seeded admin from `db/seeds.rb`
is the account to start from; a script that needs another finds-or-creates it.

## Rules a script follows

- **Data by service or model, never by clicking.** The browser is for showing. Clicking is
  reserved for when the click is the change being shown.
- **Spotlight by text**, not by utility classes. Text survives a restyle.
- **No literal for anything a constant owns.** Read the constant into the caption; when product
  changes the number the walkthrough is still right.
- **Say what is not walked** in the header comment. Flows that need a second actor, a live
  external service or a funded account stay with `/pr_qa`.

## Running twice is the real test

The development database keeps every run's records, so the second run is where a script breaks.
The framework reports a database behind on migrations as "run bin/rails db:migrate" before
anything is built, rather than as a `NoMethodError` from the first create. Everything else is the
script's job: anything unique is found-or-created, and any model with a uniqueness rule between
the same two records is cancelled or reused before the step creates its own. Run the unattended
mode twice before committing.

## Deliberate limits

- The script drives its own Chrome window, not the reviewer's browser, and it writes to the
  development database — records it creates stay there. `bin/rails db:reset` is the cleanup.
- No assertions. It is a demonstration, not a test; the system tests own pass/fail. If a step's
  spotlight cannot find its element, that is reported as a failed step and the reviewer looks.
- A headed run needs a display. In a container or over ssh, use the unattended mode and read the
  screenshots.
