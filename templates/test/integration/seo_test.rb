# frozen_string_literal: true

require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  test "homepage includes meta description" do
    get root_url
    assert_select 'meta[name="description"]', true, "Missing meta description"
  end

  test "homepage includes canonical URL" do
    get root_url
    assert_select 'link[rel="canonical"]', true, "Missing canonical URL"
  end

  test "homepage includes WebSite JSON-LD" do
    get root_url
    assert_json_ld("WebSite")
  end

  test "sitemap returns valid XML" do
    get sitemap_url(format: :xml)
    assert_response :success
    assert_includes response.content_type, "xml"
    assert_includes response.body, "<urlset"
  end

  test "robots.txt is accessible and references sitemap" do
    get "/robots.txt"
    assert_response :success
    assert_includes response.body, "Sitemap:"
    assert_includes response.body, "Disallow: /admin/"
  end

  private

  def assert_json_ld(expected_type)
    scripts = css_select('script[type="application/ld+json"]')
    assert scripts.any?, "Expected at least one JSON-LD script tag"

    found = scripts.any? do |script|
      data = JSON.parse(script.text)
      data["@type"] == expected_type
    rescue JSON::ParserError
      false
    end

    assert found, "Expected JSON-LD with @type '#{expected_type}'"
  end
end
