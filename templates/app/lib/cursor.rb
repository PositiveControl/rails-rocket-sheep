# frozen_string_literal: true

# Keyset pagination — docs/rules/cursor-pagination.md.
#
# The cursor encodes the sort key and a unique tiebreak, and nothing else. On
# PostgreSQL the primary key is a uuid, which has no order, so the key is
# (sort column, id) rather than an id on its own.
#
#   page = Cursor.page(scope, after: params[:cursor], limit: per_page, key: filter.sort_key)
#   render json: ItemSerializer.collection(page.records, next_cursor: page.next_cursor)
module Cursor
  Page = Struct.new(:records, :next_cursor, keyword_init: true)

  class InvalidCursor < StandardError; end

  DEFAULT_KEY = [ :created_at, :desc ].freeze

  class << self
    def page(scope, after: nil, limit: 25, key: DEFAULT_KEY)
      field, direction = key
      scope = scope.reorder(field => direction, :id => direction)
      scope = scope.where(*predicate(field, direction, decode(after))) if after.present?

      # One extra row is how you know there is a next page without counting.
      rows = scope.limit(limit + 1).to_a
      more = rows.size > limit
      rows = rows.first(limit)

      Page.new(records: rows, next_cursor: more ? encode(rows.last, field) : nil)
    end

    # Opaque by design: a client that parses a cursor is a client whose sort you
    # cannot change.
    def encode(record, field)
      value = record.public_send(field)
      payload = [ value.is_a?(Time) || value.is_a?(DateTime) ? value.iso8601(6) : value.to_s, record.id.to_s ]
      Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
    end

    def decode(cursor)
      value, id = JSON.parse(Base64.urlsafe_decode64(cursor.to_s))
      [ value, id ]
    rescue ArgumentError, JSON::ParserError
      raise InvalidCursor, "cursor is not one this endpoint issued"
    end

    private

    # Row-value comparison, so the tiebreak is part of one predicate rather than
    # an OR the planner has to unpick.
    def predicate(field, direction, (value, id))
      operator = direction.to_sym == :desc ? "<" : ">"
      [ "(#{field}, id) #{operator} (?, ?)", value, id ]
    end
  end
end
