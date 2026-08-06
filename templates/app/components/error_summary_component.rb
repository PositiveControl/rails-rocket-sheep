# frozen_string_literal: true

# Validation errors for a record or a form object, rendered the same way on
# every form in the app.
#
#   = form_with model: @order do |f|
#     = render ErrorSummaryComponent.new(record: @order)
#
# Works with anything that responds to #errors — ActiveRecord models and
# ApplicationForm subclasses both qualify.
#
# Remember the other half of the contract: the controller must render the form
# again with `status: :unprocessable_content`, or Turbo discards the response
# and the form appears frozen. See docs/system/design-patterns.md.
class ErrorSummaryComponent < ApplicationComponent
  # @param record [#errors]
  # @param title [String, nil] heading; defaults to a count
  def initialize(record:, title: nil)
    @record = record
    @title = title
  end

  def render?
    @record.respond_to?(:errors) && @record.errors.any?
  end

  private

  def messages
    @record.errors.full_messages
  end

  def title
    @title || "#{messages.size} #{'error'.pluralize(messages.size)} prevented this from being saved"
  end
end
