---
id: rate-limiting
title: Rate-limit what strangers can reach
applies_to: ["app/controllers/**/*.rb"]
triggers: ["rate_limit", "rate limiting", "throttle", "too many requests", "sign in", "password reset", "signup", "brute force", "contact form", "webhook"]
see_also: ["controllers", "caching"]
modes: [ web, api ]
tokens: 330
current_state: matches
---

# Rate-limit what strangers can reach

Rails 8 ships rate limiting. It uses `Rails.cache`, which here is Solid Cache, so
there is nothing to install.

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes,
             only: :create,
             with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again shortly." }
end

class PasswordResetsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create,
             by:   -> { params.dig(:user, :email).to_s.downcase },
             with: -> { head :too_many_requests }
end
```

Defaults: `by:` is the remote IP, `with:` is `head :too_many_requests`.

**Apply to:** sign-in, password reset, signup, invite acceptance, contact forms,
webhook endpoints, anything that sends mail or costs money per call.

**Don't apply to:** authenticated CRUD. You'll rate-limit your own power users.
