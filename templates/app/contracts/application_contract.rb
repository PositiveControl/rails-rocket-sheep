# frozen_string_literal: true

# Validates an untrusted request body before a model sees it —
# docs/rules/request-contracts.md.
#
# Declare the type, then validate the range. ActiveModel casts "abc" to 0 for an
# integer attribute, silently, so a declared type without a bound turns a client's
# typo into a free item.
#
#   class Items::CreateContract < ApplicationContract
#     attribute :title, :string
#     attribute :price_cents, :integer
#
#     validates :title, presence: true, length: { maximum: 120 }
#     validates :price_cents, numericality: { only_integer: true, greater_than: 0 }
#   end
class ApplicationContract
  include ActiveModel::Model
  include ActiveModel::Attributes

  # The `errors` extension of a problem document: one entry per field, each with a
  # machine-readable code — docs/rules/error-envelope.md.
  def error_details
    errors.map do |error|
      { field: error.attribute, code: error.type, detail: error.full_message }
    end
  end

  # Only the attributes this contract declares, so a service can splat it without
  # carrying anything the client sent that nobody validated.
  def to_h
    attributes.symbolize_keys
  end
end
