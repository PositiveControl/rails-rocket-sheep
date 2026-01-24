# frozen_string_literal: true

# Application configuration using the registry pattern.
# Centralized configuration for app-wide settings and constants.
#
# Usage:
#   AppConfig::BRANDING[:name]           # => "My App"
#   AppConfig::Limits::MAX_UPLOAD_SIZE   # => 10.megabytes
#
module AppConfig
  # Application branding
  BRANDING = {
    name: "My App",
    tagline: "Built with Rails Rocket Sheep",
    support_email: "support@example.com"
  }.freeze

  # Feature flags (simple implementation - consider flipper gem for production)
  module Features
    def self.enabled?(feature)
      ENABLED_FEATURES.include?(feature.to_sym)
    end

    ENABLED_FEATURES = %i[
      # Add feature flags here
      # :new_dashboard
      # :beta_api
    ].freeze
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

  # Example registry for subscription plans
  module PlanRegistry
    extend RegistryBase

    ITEMS = {
      free: {
        name: "Free",
        price_cents: 0,
        interval: :month,
        features: %i[basic_access],
        limits: { projects: 3, storage_mb: 100 }
      },
      starter: {
        name: "Starter",
        price_cents: 900,
        interval: :month,
        features: %i[basic_access api_access],
        limits: { projects: 10, storage_mb: 1000 }
      },
      pro: {
        name: "Pro",
        price_cents: 2900,
        interval: :month,
        features: %i[basic_access api_access priority_support webhooks],
        limits: { projects: 100, storage_mb: 10000 }
      }
    }.freeze

    class << self
      def items = ITEMS

      def price_cents(type) = get(type, :price_cents)
      def features(type) = get(type, :features) || []
      def limit(type, key) = get(type, :limits)&.dig(key)

      def paid_plans = items.reject { |_, v| v[:price_cents].zero? }.keys
      def has_feature?(type, feature) = features(type).include?(feature.to_sym)
    end
  end
end
