# frozen_string_literal: true

# The client is a separate origin, so this is load-bearing rather than incidental —
# docs/rules/cors.md.
#
# Origins are named and come from credentials. Never `origins "*"`, and never
# reflect the request's Origin back: with credentials that allows every site your
# users visit to call this API as them.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*Array(Rails.application.credentials.dig(:api, :allowed_origins)))

    resource "/api/*",
             headers: :any,
             methods: %i[get post patch put delete options],
             # A browser hides every response header but a safelisted few, so the
             # ones a client has to act on are named here or they are invisible.
             expose: %w[Retry-After Deprecation Sunset Location],
             max_age: 600
  end
end
