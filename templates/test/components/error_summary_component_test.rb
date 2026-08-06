# frozen_string_literal: true

require "test_helper"

class ErrorSummaryComponentTest < ViewComponent::TestCase
  class ExampleForm < ApplicationForm
    attribute :email, :string
    validates :email, presence: true

    def save = valid?
  end

  test "renders nothing when the record is valid" do
    form = ExampleForm.new(email: "a@example.com")
    form.valid?

    render_inline(ErrorSummaryComponent.new(record: form))

    assert_no_selector "[role=alert]"
  end

  test "lists each error message" do
    form = ExampleForm.new
    form.valid?

    render_inline(ErrorSummaryComponent.new(record: form))

    assert_selector "[role=alert] li", text: "Email can't be blank"
    assert_selector "h2", text: "1 error prevented this from being saved"
  end

  test "accepts a custom title" do
    form = ExampleForm.new
    form.valid?

    render_inline(ErrorSummaryComponent.new(record: form, title: "Fix these"))

    assert_selector "h2", text: "Fix these"
  end
end
