# frozen_string_literal: true

# Renders the Rails flash as a stack of AlertComponents.
#
# Put it once in the layout, inside a turbo_frame or a plain div:
#
#   = render FlashComponent.new(flash: flash)
#
# The flash hash is passed in rather than read off the view context, so the
# component can be rendered in a test without a request.
class FlashComponent < ApplicationComponent
  # Rails and Devise both speak :notice and :alert. Anything else falls back to
  # the AlertComponent default rather than rendering an unstyled box.
  VARIANT_FOR = {
    "notice" => :notice,
    "success" => :success,
    "warning" => :warning,
    "alert" => :alert,
    "error" => :alert
  }.freeze

  # @param flash [ActionDispatch::Flash::FlashHash, Hash]
  def initialize(flash:)
    @flash = flash
  end

  def render?
    messages.any?
  end

  private

  # Skip non-message keys some gems stash in the flash (:timedout, :form_data).
  def messages
    @messages ||= @flash.to_hash.select { |_key, value| value.is_a?(String) && value.present? }
  end

  def variant_for(key)
    VARIANT_FOR.fetch(key.to_s, AlertComponent::DEFAULT_VARIANT)
  end
end
