# Serializers Are Plain Objects

**Applies to:** API mode. In server-rendered mode the response shape is a template,
and the equivalent decision is [ADR 0006](0006-viewcomponent-for-ui-units.md).

**Status:** Accepted

**Context:**
Something has to decide which columns a response publishes. Left unowned, that
decision lands in the action, and then in three copies of a private controller
method, and then a migration decides what the API exposes. Of 289 JSON responses in
an audited app, none went through a serializer, and one record's shape was defined by
three copies of the same private method.

The gem options — `jsonapi-serializer`, `blueprinter`, ActiveModel::Serializers —
each bring a DSL, a lifecycle and a serialization philosophy for what is, at bottom,
a method returning a hash.

**Decision:**
Plain Ruby objects in `app/serializers/`, one per resource, over an
`ApplicationSerializer` base. No gem. `#fields` returns an explicit hash — never
`record.attributes`, never `as_json(except:)`, because a denylist publishes the next
column somebody adds. One serializer per resource: two endpoints needing different
amounts of the same resource is
[`../rules/sparse-fieldsets-includes.md`](../rules/sparse-fieldsets-includes.md), not
a second serializer. `optional` and `includable` are the two declarations, and an
includable names its own preload so the controller can apply it before paginating.

This matches the taste already set by `ApplicationService`
([ADR 0003](0003-service-object-pattern.md)) and the `Data` registries
([ADR 0008](0008-registries-as-data-objects.md)): a base class and a convention, not
a dependency. Conventions are in
[`../rules/serialization.md`](../rules/serialization.md).

**Consequences:**
- (+) The response shape is readable Ruby in one file per resource, with no DSL to
  learn and nothing to upgrade
- (+) Field lists are declarations, which is what lets the contract be generated from
  them ([ADR 0013](0013-the-api-contract-is-generated-from-its-tests.md))
- (+) An explicit list cannot leak a column added later
- (-) Everything a gem would have given is now this app's to write: sparse fieldsets,
  includes, collection meta, caching. The base class is real code with real tests
- (-) No JSON:API compliance, so a client expecting that document structure does not
  get it for free
- (-) A resource with genuinely two audiences (public and internal, say) strains "one
  serializer per resource", and the pressure release is fieldsets rather than a
  second class
