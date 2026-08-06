# frozen_string_literal: true

require "test_helper"

class EmptyStateComponentTest < ViewComponent::TestCase
  test "renders the title alone" do
    render_inline(EmptyStateComponent.new(title: "No orders yet"))

    assert_selector "h3", text: "No orders yet"
    assert_no_selector "p"
  end

  test "renders the description when given" do
    render_inline(EmptyStateComponent.new(title: "No orders yet", description: "They show up after checkout."))

    assert_selector "p", text: "They show up after checkout."
  end

  test "renders the action slot" do
    render_inline(EmptyStateComponent.new(title: "No orders yet")) do |empty|
      empty.with_action { "<a href=\"/orders/new\">New order</a>".html_safe }
    end

    assert_selector "a[href='/orders/new']", text: "New order"
  end
end
