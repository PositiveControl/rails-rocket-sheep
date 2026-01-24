# frozen_string_literal: true

# Helper for rendering progress bars with consistent styling
#
# Usage in views:
#   = progress_bar(current: 75, max: 100)
#   = progress_bar(current: 5, max: 10, label: "Tasks completed")
#   = progress_bar(current: 80, max: 100, color: "green", show_percentage: true)
#
module ProgressBarHelper
  # Render a progress bar
  #
  # @param current [Numeric] current value
  # @param max [Numeric] maximum value
  # @param label [String, nil] optional label text
  # @param color [String] Tailwind color name (default: "blue")
  # @param show_percentage [Boolean] show percentage text (default: false)
  # @param size [Symbol] :sm, :md, :lg (default: :md)
  # @param animate [Boolean] animate the bar (default: false)
  # @return [String] HTML for progress bar
  def progress_bar(current:, max:, label: nil, color: "blue", show_percentage: false, size: :md, animate: false)
    return "" if max.zero?

    percentage = [(current.to_f / max * 100).round, 100].min
    height = case size
             when :sm then "h-1"
             when :lg then "h-4"
             else "h-2"
             end

    bar_color = "bg-#{color}-500"
    track_color = "bg-#{color}-100 dark:bg-#{color}-900/30"
    animation = animate ? "transition-all duration-300" : ""

    content_tag :div, class: "w-full" do
      concat(content_tag(:div, class: "flex justify-between mb-1 text-sm") do
        concat(content_tag(:span, label, class: "text-gray-700 dark:text-gray-300")) if label
        concat(content_tag(:span, "#{percentage}%", class: "text-gray-500")) if show_percentage
      end) if label || show_percentage

      concat(content_tag(:div, class: "w-full #{track_color} rounded-full #{height}") do
        content_tag(:div, "", class: "#{bar_color} #{height} rounded-full #{animation}", style: "width: #{percentage}%")
      end)
    end
  end

  # Render a capacity bar (useful for showing usage vs limit)
  #
  # @param current [Numeric] current usage
  # @param max [Numeric] maximum capacity
  # @param label [String, nil] optional label
  # @param warning_threshold [Numeric] percentage at which to show warning color (default: 80)
  # @param danger_threshold [Numeric] percentage at which to show danger color (default: 95)
  # @return [String] HTML for capacity bar
  def capacity_bar(current:, max:, label: nil, warning_threshold: 80, danger_threshold: 95)
    return "" if max.zero?

    percentage = (current.to_f / max * 100).round

    color = if percentage >= danger_threshold
              "red"
            elsif percentage >= warning_threshold
              "yellow"
            else
              "green"
            end

    progress_bar(
      current: current,
      max: max,
      label: label,
      color: color,
      show_percentage: true
    )
  end
end
