# Comparison

Honest positioning against the alternatives. Some of these are better purchases than Rocket Sheep depending on what you're building — that's said plainly below rather than discovered after you've paid.

---

## Summary

| | `rails new` | Rocket Sheep | Jumpstart Pro | Bullet Train |
|---|---|---|---|---|
| Cost | Free | One-time | ~$249 one-time | Free core / paid tiers |
| Rails 8 Solid Stack | Yes | Yes, multi-database | Yes | Yes |
| Auth | No | Devise + Petergate | Devise + OmniAuth | Devise |
| Billing | No | **No** | Stripe, Paddle, Braintree | Stripe |
| Teams / multi-tenancy | No | **No** | Yes | Yes, core concept |
| Admin panel | No | **No** | Yes | Yes |
| Deployment config | Partial | Kamal 2, tuned | Kamal, Heroku, Render | Various |
| SEO foundation | No | Yes, tested | Partial | Partial |
| AI agent conventions | No | **Yes** | No | No |
| Upgrade path | n/a | None needed — you own the files | Git remote merge | Gem-based |
| Code you own | All | All | All | Framework gems |

---

## vs plain `rails new`

**What you actually save.** Rails 8 already ships Solid Queue, Solid Cache, Solid Cable, Kamal, and Thruster. That's real, and it's why this template is thin rather than enormous. What's left is the assembly: multi-database configuration for the Solid stack, UUID generators wired up, Devise configured for Turbo, Kamal with a working Postgres accessory and an entrypoint that migrates, a Dockerfile that builds, SEO that's actually tested, and the conventions file.

Call it a day or two of setup, plus the specific knowledge of which defaults bite. A few examples that are not obvious until they cost you an afternoon:

- Rails 8 runs `solid_*:install` *after* bundling, overwriting Solid config a template wrote earlier
- Devise needs `navigational_formats` adjusted or Turbo breaks redirects
- The stock fixture generator emits two identical records, which violates Devise's unique email index the first time you run tests
- Slim's parser conflicts with Tailwind's bracket syntax

**When plain Rails is the right answer.** You disagree with the opinions, you're building something small, or you want to make these decisions yourself. All completely reasonable. The template is a set of defaults, and defaults you fight are worse than no defaults.

---

## vs Jumpstart Pro

Jumpstart Pro is a **SaaS starter kit**. Rocket Sheep is an **application foundation**. Different products.

**Jumpstart Pro is the better buy if** you're building a subscription SaaS and want billing, teams, an admin panel, OmniAuth providers, API keys, and a marketing site on day one. It's mature, actively maintained, and has a large user base. If your product needs Stripe subscriptions with plan management, buying Jumpstart is cheaper than building that yourself, and cheaper than buying Rocket Sheep and then building it.

**Rocket Sheep is the better buy if** you're not building a subscription SaaS — an internal tool, a client project, a content site, an API — and want a clean foundation without carrying billing and multi-tenancy code you'll never use. And if you're working with AI coding agents, where the conventions layer is the whole point.

**The honest trade:** Jumpstart Pro gives you vastly more code. That's an advantage when you need the code and a liability when you don't. Its upgrade path (merging from a git remote) means ongoing merge work. Rocket Sheep is applied once and then it's just your app — there's nothing to upgrade, because there's nothing left that isn't yours.

---

## vs Bullet Train

Bullet Train is built around teams and roles as a first-class concept, with a super-scaffolding system that generates full CRUD from a model definition. It's the most opinionated option here.

**Bullet Train is the better buy if** your app is fundamentally about teams with granular role-based permissions, and you want scaffolding to generate large amounts of consistent UI quickly.

**Rocket Sheep is the better buy if** you want plain Rails you can read end to end. Bullet Train's power comes from framework gems — magic that saves enormous time when you're inside the paved path and costs real time when you step outside it. Rocket Sheep adds no gems of its own. Every file it writes is a file you can open, understand, and delete.

---

## vs rolling your own template

This is the real competition, and it's a legitimate choice — most experienced Rails developers eventually accumulate one.

**Roll your own if** you've built more than two or three Rails apps recently and already know your preferences. Your template will fit you better than anyone else's, by definition.

**Buy this if** you want the assembly work done and are happy to adopt a reasonable set of opinions, or you want the AI conventions layer without writing and iterating on `CLAUDE.md` yourself. That file is the part that takes longest to get right, because you only learn what belongs in it by watching agents get things wrong repeatedly.

---

## What Rocket Sheep does not have

Stated plainly so nobody buys the wrong thing:

- **No billing.** No Stripe, no subscriptions, no plan management. `AppConfig::PlanRegistry` is an example of the registry pattern, not a billing system.
- **No teams or multi-tenancy.** Single-tenant. Adding tenancy is on you.
- **No admin panel.** No Avo, no Administrate, no ActiveAdmin.
- **No component library.** Tailwind is configured; components are yours.
- **No API scaffolding.** No JSON serializers, no versioning, no docs generation.
- **No OmniAuth.** Devise with email and password only.
- **No background job dashboard.** Solid Queue's Mission Control is not wired up.

Several of these are deliberate. A template that includes everything is a framework, and frameworks are the thing you eventually fight.
