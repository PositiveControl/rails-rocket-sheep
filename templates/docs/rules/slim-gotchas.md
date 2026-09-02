---
id: slim-gotchas
title: Slim gotchas — where Slim collides with Tailwind and Ruby
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim"]
triggers: ["slim", "bracket", "max-h-[", "arbitrary value", "pipe", "text on its own line", "multi-line ruby", "interpolation in attribute", "strict locals", "template renders blank", "unexpected element"]
see_also: ["tailwind-build"]
tokens: 630
current_state: matches
---

# Slim gotchas

Slim's terseness collides with Tailwind's bracket syntax and Ruby's in specific,
repeatable ways. These are the ones that bite. `bin/hooks/post_edit` catches the
first one automatically.

## Bracket values need `class=""`

```slim
/ BAD: Slim parses [85vh] as attributes
div.max-h-[85vh]

/ GOOD
div class="max-h-[85vh]"
div class="max-h-[85vh] w-[calc(100%-2rem)] grid-cols-[1fr_2fr]"

/ Same for arbitrary properties and variants
div class="[--my-var:10px] [&>*]:mt-4 [&:nth-child(2)]:bg-blue-500"
```

## Text on its own line needs a pipe

```slim
/ BAD: parsed as an element
div.pr-4
  Some text here

/ GOOD
div.pr-4
  | Some text here

/ Or inline
div.pr-4 Some text here

/ Dynamic
div.pr-4 = user.name
```

## Text starting with a special character

```slim
/ BAD: ( is read as Ruby
span.count
  (5 items)

/ GOOD
span.count
  | (5 items)

/ GOOD
span.count = "(#{count} items)"
```

## Multi-line Ruby needs a `ruby:` block

Each `-` line is evaluated independently, so a multi-line hash fails silently.

```slim
/ BAD
- config = {
-   foo: "bar"
- }

/ GOOD
ruby:
  config = {
    foo: "bar",
    baz: "qux"
  }
```

## Interpolation in attributes needs a local first

```slim
/ BAD: loop variable not resolved
- items.each do |item|
  a href="/items/#{item.id}"

/ GOOD
- items.each do |item|
  - path = "/items/#{item.id}"
  a href=path

/ BEST: a route helper
- items.each do |item|
  a href=item_path(item)
```

Same for dynamic classes:

```slim
- color_class = "text-#{type}-500"
div class=color_class

/ Or array syntax
div class=["text-#{type}-500", "font-bold"]
```

A class assembled at runtime does not exist in the compiled CSS —
see [tailwind-build](tailwind-build.md).

## Strict locals — exact syntax, first line

Rails matches the magic comment with a regex, so spacing matters:

```slim
/# locals: (order:, compact: false)
```

Partials only — files whose names start with `_`. Full partial rules are in
[partials](partials.md).
