---
id: serialization
title: Serialization — one plain object per resource, never a hash in the action
applies_to: ["app/serializers/**/*.rb", "app/controllers/**/*.rb"]
triggers: ["serializer", "as_json", "to_json", "response shape", "JSON keys", "render json", "ApplicationSerializer", "response fields"]
see_also: ["pattern-budget", "sparse-fieldsets-includes", "n-plus-one", "api-versioning"]
modes: [ api ]
tokens: 680
current_state: matches
---

# Serialization

Every response body comes from a serializer in `app/serializers/`. Plain Ruby
objects, one per resource, no gem.

```ruby
class ItemSerializer < ApplicationSerializer
  PRELOADS = [ :category, { capture_images: :image_attachment } ].freeze

  def fields
    {
      id:         record.id,
      status:     record.status,
      title:      record.title,
      price:      money(record.price_cents),
      category:   record.category.name,
      created_at: record.created_at.iso8601
    }
  end
end
```

```ruby
# the controller
render json: ItemSerializer.collection(page)          # => { data: [...] }
render json: ItemSerializer.one(@item), status: :created
```

**The field list is explicit.** Never `record.attributes`, never `as_json(except:)`.
A denylist means the next migration decides what the API exposes, and the first time
that goes wrong it is a column nobody meant to publish.

**One serializer per resource, one shape per resource.** If two endpoints need
different amounts of the same resource, that is
[sparse-fieldsets-includes](sparse-fieldsets-includes.md), not a second serializer —
two serializers for one resource drift, and the second one is always the stale one.

**Keys are `snake_case`, times are ISO 8601 strings, money is minor units with its
currency.** Never a float for money, never a bare epoch integer for a time, never a
`Date` relying on `to_json`.

**`PRELOADS` lives next to the fields that need it.** The serializer knows which
associations it touches; the caller applies them. A serializer that reaches for an
unpreloaded association turns one response into one query per row, and the place it
happens is a response builder nobody profiles —
[n-plus-one](n-plus-one.md).

**Nothing but a serializer builds a response.** No hash literals in actions, no
private `serialize_*` methods on controllers, no `to_json` on a model.

**The cost is measured.** In the audited app none of 289 JSON responses used a
serializer; one record's shape was defined by three copies of the same private
controller method.

Which directory this is and when a new one is justified: [pattern-budget](pattern-budget.md).
