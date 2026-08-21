# Billing is out of scope

No Stripe, no Paddle, no subscriptions, no plan management. `PlanRegistry` is a
worked example of the registry pattern that happens to use plan names; it is not a
billing system and should not grow into one.

## Why this is out of scope

Billing is the part of a SaaS that varies most between products and least between
templates. Plans, trials, proration, dunning, tax, currency, webhook
reconciliation, and the invoice UI are all decisions with a right answer per
business and no right answer in general. A template's billing layer is therefore
either too thin to use in production or an opinion the buyer spends longer
removing than writing.

It is also the largest single maintenance surface a template can take on. Payment
provider APIs move, webhook payloads change shape, and a stale billing integration
is worse than none because it looks finished.

## What to do instead

- Need Stripe subscriptions with plan management on day one? Jumpstart Pro ships
  it, and buying it is cheaper than building it. `docs/comparison.md` says so
  plainly, and that is the honest recommendation.
- Adding it here: `pay` or the Stripe gem, a service object per operation
  (`docs/rules/service-objects.md`), and webhooks as jobs
  (`docs/rules/jobs.md`). The conventions carry it; the template does not.

## What would change our mind

Nothing about billing itself. The nearest thing worth doing is a `docs/sop/`
procedure for wiring a payment provider into these conventions, which teaches the
integration without shipping and maintaining it.
