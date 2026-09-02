---
id: turbo-frames
title: Turbo frames — stable ids, matching responses, lazy loading
applies_to: ["app/views/**/*.slim", "app/components/**/*.slim", "app/controllers/**/*.rb"]
triggers: ["turbo_frame_tag", "turbo frame", "frame missing", "content missing", "dom_id", "turbo_frame: _top", "lazy loading", "loading: :lazy"]
see_also: ["turbo-streams", "turbo-status"]
tokens: 390
current_state: matches
---

# Turbo frames

A frame scopes navigation to a region. Give it a stable id via `dom_id`.

```slim
= turbo_frame_tag dom_id(order) do
  = render OrderRowComponent.new(order:)
```

The server must respond with a matching frame or Turbo drops the response and logs
a console error. Any link inside a frame targets that frame unless told otherwise:

```slim
= link_to "Full page", order_path(order), data: { turbo_frame: "_top" }
```

**Lazy frames** for expensive sections — the page paints, then the frame loads:

```slim
= turbo_frame_tag "order_history", src: order_history_path(order), loading: :lazy do
  = render SpinnerComponent.new
```

## Morphing and scroll preservation

For pages that refresh in place (dashboards, filters):

```slim
/ in the layout head
meta name="turbo-refresh-method" content="morph"
meta name="turbo-refresh-scroll" content="preserve"
```

Morphing keeps focus and scroll on refresh. It also means DOM state a Stimulus
controller set can be reverted — use `data-turbo-permanent` on elements that must
survive. See [stimulus](stimulus.md).
