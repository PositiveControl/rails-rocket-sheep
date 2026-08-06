# frozen_string_literal: true

# A single inline message: success, notice, warning, or error.
#
#   = render AlertComponent.new(variant: :success) do
#     | Order placed.
#
# Renders nothing when given no content, so call sites don't need a conditional.
#
# Variants are a frozen hash rather than a case statement — adding one is a
# single line, and the full Tailwind class names appear literally in the source
# where the compiler can see them.
class AlertComponent < ApplicationComponent
  VARIANTS = {
    notice: "bg-blue-50 border-blue-200 text-blue-800 dark:bg-blue-950 dark:border-blue-900 dark:text-blue-200",
    success: "bg-green-50 border-green-200 text-green-800 dark:bg-green-950 dark:border-green-900 dark:text-green-200",
    warning: "bg-yellow-50 border-yellow-200 text-yellow-900 dark:bg-yellow-950 dark:border-yellow-900 dark:text-yellow-200",
    alert: "bg-red-50 border-red-200 text-red-800 dark:bg-red-950 dark:border-red-900 dark:text-red-200"
  }.freeze

  DEFAULT_VARIANT = :notice

  # @param variant [Symbol] one of VARIANTS' keys; unknown values fall back to :notice
  def initialize(variant: DEFAULT_VARIANT)
    @variant = variant.to_sym
  end

  # @return [Boolean] false when there is nothing to say
  def render?
    content.present?
  end

  private

  def classes
    class_names("rounded border px-4 py-3 text-sm", VARIANTS.fetch(@variant, VARIANTS[DEFAULT_VARIANT]))
  end
end
