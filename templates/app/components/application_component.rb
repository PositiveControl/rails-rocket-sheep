# frozen_string_literal: true

# Base class for all ViewComponents.
#
# Components live in app/components, are named for what they render (AvatarComponent,
# not UserComponent), and end in -Component. Namespaced components use plural modules
# like controllers: Orders::RowComponent.
#
# Conventions enforced by convention, not code:
#
#   - Everything the template needs arrives through #initialize. A component never
#     reaches for params, session, or current_user on its own — that is what makes it
#     renderable in a unit test with no request.
#   - Template logic lives in private methods on the component, not in the .slim file.
#   - Variants are a frozen hash, not a chain of conditionals.
#   - Override #render? for "should this appear at all", instead of wrapping every
#     call site in a conditional.
#
# Generate one with:
#
#   bin/rails generate component Alert message
#
# which writes the class, a sidecar app/components/alert_component/alert_component.html.slim,
# and a test.
#
# See docs/rules/components.md for the full guidance.
class ApplicationComponent < ViewComponent::Base
  # Join class name fragments, dropping blanks.
  #
  #   class_names("rounded p-4", ("hidden" if collapsed?))
  #   # => "rounded p-4 hidden"
  #
  # @param names [Array<String, nil, false>]
  # @return [String]
  def class_names(*names)
    names.flatten.compact_blank.join(" ")
  end
end
