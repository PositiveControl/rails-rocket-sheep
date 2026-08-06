# frozen_string_literal: true

require "test_helper"

class FlashComponentTest < ViewComponent::TestCase
  test "renders nothing when the flash is empty" do
    render_inline(FlashComponent.new(flash: {}))

    assert_no_selector "[role=alert]"
  end

  test "renders one alert per message" do
    render_inline(FlashComponent.new(flash: { "notice" => "Saved", "alert" => "Careful" }))

    assert_selector "[role=alert]", count: 2
    assert_selector "[role=alert]", text: "Saved"
    assert_selector "[role=alert]", text: "Careful"
  end

  test "maps alert to the danger variant" do
    render_inline(FlashComponent.new(flash: { "alert" => "Nope" }))

    assert_selector "[role=alert].bg-red-50", text: "Nope"
  end

  test "ignores non-string flash values gems stash there" do
    render_inline(FlashComponent.new(flash: { "timedout" => true, "notice" => "Saved" }))

    assert_selector "[role=alert]", count: 1
  end
end
