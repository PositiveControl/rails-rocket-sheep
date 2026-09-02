---
id: turbo-streams
title: Turbo streams from the controller; model broadcasts are the footgun
applies_to: ["app/controllers/**/*.rb", "app/views/**/*.turbo_stream.slim", "app/models/**/*.rb"]
triggers: ["turbo_stream", "broadcasts_to", "broadcast", "turbo stream append", "live update", "respond_to format.turbo_stream", "after_commit broadcast", "real time"]
see_also: ["turbo-frames", "turbo-status", "callbacks", "jobs"]
modes: [ web ]
tokens: 570
current_state: matches
---

# Turbo streams

## From the controller by default

```ruby
def create
  result = CreateCommentService.call(post: @post, user: current_user, body: comment_params[:body])

  if result.success?
    respond_to do |format|
      format.turbo_stream   # renders create.turbo_stream.slim
      format.html { redirect_to @post }
    end
  else
    render :new, status: :unprocessable_content
  end
end
```

```slim
/ app/views/comments/create.turbo_stream.slim
= turbo_stream.append "comments" do
  = render CommentComponent.new(comment: @comment)
= turbo_stream.update "comment_form" do
  = render CommentFormComponent.new(post: @post, comment: Comment.new)
```

**Always keep the `format.html` branch.** It's what makes the feature work without
JavaScript, and it's what the system test exercises.

## Broadcasting from models: the main Hotwire footgun

```ruby
# BAD — every save pushes to every subscriber, forever
class Comment < ApplicationRecord
  broadcasts_to :post
end
```

That renders and pushes on every create, update, and destroy — including
backfills, imports, and console fixes. It renders in a context with no
`current_user`, so anything user-specific in the partial is wrong for someone.

Model broadcasts are for **genuine multi-user push**: a shared board, a live feed,
a chat. Even then, broadcast from an `after_commit` in a job, not inline, so a slow
render doesn't sit inside the request:

```ruby
after_commit :broadcast_later, on: :create

def broadcast_later
  BroadcastCommentJob.perform_later(id)
end
```

For "the person who clicked should see the result" — the overwhelmingly common
case — that's a controller stream response, not a broadcast.
