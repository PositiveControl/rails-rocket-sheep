# frozen_string_literal: true

# App-wide constants: branding, feature flags, limits, timing.
#
# Usage:
#   AppConfig::BRANDING[:name]           # => "My App"
#   AppConfig::Limits::MAX_UPLOAD_SIZE   # => 10.megabytes
#   AppConfig::Features.enabled?(:beta_api)
#
# This is plain frozen constants, not a registry. A registry is for a fixed set
# of *variants that each carry attributes* — see plan_registry.rb for that shape.
# Values with no variants don't need one.
module AppConfig
  # Application branding — change these before you deploy
  BRANDING = {
    name: "My App",
    tagline: "Built with Rails Rocket Sheep",
    support_email: "support@example.com"
  }.freeze

  # Feature flags. Fine for a handful of toggles; reach for Flipper when flags
  # need to change without a deploy or vary per user.
  module Features
    ENABLED_FEATURES = %i[
      # Add feature flags here
      # :new_dashboard
      # :beta_api
    ].freeze

    def self.enabled?(feature)
      ENABLED_FEATURES.include?(feature.to_sym)
    end
  end

  # Application limits
  module Limits
    MAX_UPLOAD_SIZE = 10.megabytes
    MAX_ITEMS_PER_PAGE = 100
    DEFAULT_ITEMS_PER_PAGE = 25
  end

  # Timing constants
  module Timing
    SESSION_TIMEOUT = 2.hours
    TOKEN_EXPIRY = 24.hours
    CACHE_TTL = 1.hour
  end
end
