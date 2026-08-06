# frozen_string_literal: true

# The state every collection view forgets. A list that renders nothing when
# empty reads as a broken page.
#
#   - if @orders.any?
#     = render partial: "orders/order", collection: @orders, as: :order
#   - else
#     = render EmptyStateComponent.new(title: "No orders yet",
#                                      description: "Orders appear here once a customer checks out.") do |empty|
#       - empty.with_action do
#         = link_to "New order", new_order_path, class: "..."
class EmptyStateComponent < ApplicationComponent
  renders_one :action

  # @param title [String]
  # @param description [String, nil]
  def initialize(title:, description: nil)
    @title = title
    @description = description
  end

  private

  attr_reader :title, :description
end
