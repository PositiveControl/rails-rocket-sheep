# frozen_string_literal: true

require "test_helper"

class AlertComponentTest < ViewComponent::TestCase
  test "renders nothing without content" do
    render_inline(AlertComponent.new)

    assert_no_selector "[role=alert]"
  end

  test "renders content with the default variant" do
    render_inline(AlertComponent.new) { "Heads up" }

    assert_selector "[role=alert]", text: "Heads up"
    assert_selector "[role=alert].bg-blue-50"
  end

  test "applies the requested variant" do
    render_inline(AlertComponent.new(variant: :success)) { "Saved" }

    assert_selector "[role=alert].bg-green-50", text: "Saved"
  end

  test "falls back to the default variant for an unknown one" do
    render_inline(AlertComponent.new(variant: :nonsense)) { "Hm" }

    assert_selector "[role=alert].bg-blue-50", text: "Hm"
  end
end
