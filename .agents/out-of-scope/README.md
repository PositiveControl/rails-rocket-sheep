# Out of scope

One file per request this project has decided not to take, with the reasoning.

`docs/comparison.md` tells a buyer what the template does not have. It says
"several of these are deliberate" without saying which, or why, so the same
request arrives again and gets re-argued from scratch. These files are the answer:
the ruling, why the cost is not worth paying, what to do instead, and what would
change our mind.

A ruling is not a permanent no. It is a no with its reasoning attached, so
reversing it takes an argument about the reasoning rather than a fresh debate about
the feature.

| Ruling | Short version |
|---|---|
| [billing](billing.md) | No Stripe, no subscriptions, no plan management |
| [teams-and-multi-tenancy](teams-and-multi-tenancy.md) | Single-tenant; tenancy is an architecture choice, not a feature |
| [admin-panel](admin-panel.md) | No Avo, Administrate, or ActiveAdmin |
| [api-scaffolding](api-scaffolding.md) | **Reversed** — the rule set landed first, then the scaffolding ([ADR 0009](../adr/0009-api-mode-is-a-generation-flag.md)) |
| [more-tracker-tiers](more-tracker-tiers.md) | Three tracker tiers, not four |
