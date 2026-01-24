# frozen_string_literal: true

# Base module for registry pattern - single source of truth for configuration entities.
#
# The registry pattern centralizes configuration for domain entities (products, plans,
# building types, etc.) in one place, avoiding scattered hardcoded values.
#
# Usage:
#   module PlanRegistry
#     extend RegistryBase
#
#     ITEMS = {
#       free: {
#         name: "Free",
#         price: 0,
#         features: [:basic_access],
#         limits: { projects: 3, storage_gb: 1 }
#       },
#       pro: {
#         name: "Pro",
#         price: 29,
#         features: [:basic_access, :api_access, :priority_support],
#         limits: { projects: 100, storage_gb: 50 }
#       },
#       enterprise: {
#         name: "Enterprise",
#         price: 299,
#         features: [:basic_access, :api_access, :priority_support, :sso, :audit_log],
#         limits: { projects: :unlimited, storage_gb: 500 }
#       }
#     }.freeze
#
#     class << self
#       def items = ITEMS
#
#       # Convenience accessors
#       def price(type) = get(type, :price)
#       def features(type) = get(type, :features)
#       def limit(type, key) = get(type, :limits)&.dig(key)
#
#       # Query methods
#       def paid_plans = items.select { |_, v| v[:price] > 0 }.keys
#       def has_feature?(type, feature) = features(type)&.include?(feature)
#     end
#   end
#
#   # Usage:
#   PlanRegistry.price(:pro)                    # => 29
#   PlanRegistry.has_feature?(:pro, :sso)       # => false
#   PlanRegistry.limit(:free, :projects)        # => 3
#   PlanRegistry.paid_plans                     # => [:pro, :enterprise]
#
module RegistryBase
  # Get an attribute from a registry entry
  # @param type [Symbol, String] the entry type (key)
  # @param attribute [Symbol] the attribute to retrieve
  # @param level [Integer, nil] optional index for array attributes (1-based)
  # @return [Object, nil] the attribute value
  def get(type, attribute, level = nil)
    data = items[type.to_sym]
    return nil unless data

    value = data[attribute]
    return value unless level && value.is_a?(Array)

    # Level is 1-based for user convenience
    value[level - 1]
  end

  # Check if an entry exists in the registry
  # @param type [Symbol, String] the entry type
  # @return [Boolean]
  def exists?(type)
    items.key?(type.to_sym)
  end

  # Get all entry types (keys)
  # @return [Array<Symbol>]
  def all_types
    items.keys
  end

  # Get entry name (falls back to titleized key)
  # @param type [Symbol, String] the entry type
  # @return [String]
  def name(type)
    items.dig(type.to_sym, :name) || type.to_s.titleize
  end

  # Get all entries matching a condition
  # @yield [type, data] block to filter entries
  # @return [Hash] filtered entries
  def where(&block)
    items.select(&block)
  end

  # Validate registry configuration
  # Override in submodules for custom validation
  # @raise [RuntimeError] if validation fails
  # @return [true] if validation passes
  def validate!
    raise "items must be defined" unless respond_to?(:items)
    raise "items must be a Hash" unless items.is_a?(Hash)
    true
  end

  # Freeze the registry to prevent modification
  # Call this after defining all items
  def freeze!
    items.freeze
    items.each_value(&:freeze)
  end
end
