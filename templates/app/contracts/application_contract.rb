# frozen_string_literal: true

# Validates an untrusted request body before a model sees it —
# docs/rules/request-contracts.md.
#
# Declare the type, then validate the range. ActiveModel casts "abc" to 0 for an
# integer attribute, silently, so a declared type without a bound turns a client's
# typo into a free item. `numericality` here reads the value the client sent, not
# the cast one, so "abc" fails as "is not a number" even when 0 is in range.
#
#   class Items::CreateContract < ApplicationContract
#     attribute :title, :string
#     attribute :price_cents, :integer
#
#     validates :title, presence: true, length: { maximum: 120 }
#     validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
#   end
#
# An update contract validates only what the client sent, and `to_h` returns only
# that, so a PATCH of one field cannot blank the others:
#
#   class Items::UpdateContract < ApplicationContract
#     attribute :title, :string
#     attribute :price_cents, :integer
#
#     validates :title, presence: true, length: { maximum: 120 }, if: -> { provided?(:title) }
#     validates :price_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
#   end
class ApplicationContract
  include ActiveModel::Model
  include ActiveModel::Attributes

  # `NumericalityValidator` reads `#{attr}_before_type_cast` when the record
  # responds to it. ActiveRecord does; ActiveModel::Attributes keeps the raw value
  # but defines no reader, so without this the validator sees the cast 0 and passes.
  attribute_method_suffix "_before_type_cast", parameters: false

  def initialize(params = {})
    @provided = params.keys.map(&:to_sym) & self.class.attribute_names.map(&:to_sym)
    super
  end

  # Whether the client sent this key at all. `nil` from the client is provided;
  # a key the body did not carry is not. This is the difference between "clear
  # the title" and "leave the title alone".
  def provided?(name)
    @provided.include?(name.to_sym)
  end

  # The `errors` extension of a problem document: one entry per field, each with a
  # machine-readable code — docs/rules/error-envelope.md.
  def error_details
    errors.map do |error|
      { field: error.attribute, code: error.type, detail: error.full_message }
    end
  end

  # Only the attributes this contract declares and the client actually sent, so a
  # service can splat it without carrying anything nobody validated and without
  # blanking a field the client never mentioned.
  def to_h
    attributes.symbolize_keys.slice(*@provided)
  end

  private

  def attribute_before_type_cast(name)
    @attributes[name].value_before_type_cast
  end
end
