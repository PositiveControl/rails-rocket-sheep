# frozen_string_literal: true

module StructuredDataHelper
  # Renders a <script type="application/ld+json"> tag with the given hash.
  #
  # Usage in Slim views:
  #   - content_for(:head) do
  #     = jsonld_tag(your_schema_hash)
  #
  # See docs/how-tos/add-seo-to-a-page.md for the full pattern.
  def jsonld_tag(data)
    tag.script(data.to_json.html_safe, type: "application/ld+json")
  end

  # Converts milliseconds to ISO 8601 duration (e.g., "PT3M45S").
  # Useful for MusicRecording, Video, Recipe, and other schema types.
  def iso8601_duration(ms)
    total_seconds = ms / 1000
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "PT#{minutes}M#{seconds}S"
  end
end
