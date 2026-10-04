---
description: "Write the reviewer walkthrough script for a branch or feature"
argument-hint: "<issue number>"
---

# QA Walkthrough

Write the reviewer walkthrough for a change: a script in `script/qa/` that builds the data, drives a real browser to each changed page, and spotlights what changed with a caption (`docs/system/qa_walkthrough.md`). It is a demonstration for the reviewer, not the QA report — the human pass and its write-up are `/pr_qa`. Pass any issue: `/qa_walkthrough 1613` for one slice or branch, `/qa_walkthrough 1600` for a whole feature. Invoked by `/pr_submit` Step 3b on every branch with a user-facing change, or by hand.

## Instructions

### Step 1: Gather

1. `gh issue view <n>`; if it has a parent, view the parent and its sub-issues too; read the design doc in `docs/plans/`.
2. Read every `docs/system/` and `docs/sop/` file the change touched — they name the surfaces, the services and the selectors.
3. Read `lib/qa_walkthrough.rb` (the two primitives: `step`, `spotlight`) and an existing `script/qa/*.rb` for the shape.
4. **Extend or create?** A script already exists for the parent feature (`script/qa/<feature_slug>.rb`, named in the parent's design doc) → this issue's steps go into it, in the slice's place in the flow. No script → create one, named for the feature if there is a parent, else for this issue.

Two situations end here instead:

| Situation | Do |
|---|---|
| API-only app (`config.api_only`) | Nothing to walk. Say so and stop |
| No `lib/qa_walkthrough.rb` — this app adopted the alignment layer rather than being generated | Install it first: copy `templates/lib/qa_walkthrough.rb` and `templates/bin/qa-walkthrough` from the template checkout, move `capybara` and `selenium-webdriver` in the `Gemfile` from `group :test` to `group :development, :test`, `bundle install`. Commit that on its own, then continue |

### Step 2: Script

Write or extend `script/qa/<slug>.rb`. Rules:

- **One `step` per surface the change touches**, in the order a reviewer would meet them. The caption states what the reviewer should see; `note:` says where the number comes from (service, constant, record).
- **Build data with services and models, never by clicking.** The browser is for showing the result. Click only when the click IS the change (a toggle whose effect is the point).
- **Anything unique is found-or-created** (`User.find_or_create_by!(email:)`), because the development database keeps every run's records. Wrap repeated setups in a lambda inside the block.
- **Spotlight by text** (`spotlight text: "Shipping", exact: true`) unless the view has a stable id or data attribute — text survives restyling, `.flex.gap-2` does not.
- **State what is not walked** in the header comment, and why (needs a second actor, needs a live external service, needs a funded account). Those cases stay with `/pr_qa`.
- **No literals for prices, rates or copy that live in a constant** — read the constant.
- **No assertions.** A step that cannot find its element is reported as `✗` and the reviewer looks; the system tests own pass/fail.

### Step 3: Run it

With `bin/dev` up:
```bash
QA_AUTO=1 QA_HEADLESS=1 bin/qa-walkthrough <slug>
```
Run it **twice**: the second run hits last run's records. Every step must report without `✗`. A uniqueness rule between the same records (one pending order per user, one open request) is the usual second-run failure — reuse or cancel the previous record at the top of the step. A failed step is a wrong selector, a page that needs data the step did not make, or a service that fails outside a request — fix the step, not the app. Look at `tmp/qa_walkthrough/<slug>/NN.png` for any step whose spotlight might have landed on the wrong element.

### Step 4: Ship

Commit the script on the branch being submitted (`QA walkthrough for <issue or feature>`). Mention `bin/qa-walkthrough <slug>` in the PR body's Test plan. Return to `/pr_submit` if it sent you here.

## Reference
- Framework: `lib/qa_walkthrough.rb` · runner: `bin/qa-walkthrough` · scripts: `script/qa/` · screenshots: `tmp/qa_walkthrough/<slug>/`
- Modes: `QA_AUTO=1` (no pauses, a screenshot per step), `QA_HEADLESS=1`, `QA_HOST=url` (default `http://localhost:3000`)
- Sign-in: `sign_in(user, password:)` through Devise's stock form; the seeded admin is `admin@example.com` with the password `db/seeds.rb` printed
- How it works, and its limits: `docs/system/qa_walkthrough.md`
- The manual pass, and the report in `docs/qa/`: `/pr_qa`
