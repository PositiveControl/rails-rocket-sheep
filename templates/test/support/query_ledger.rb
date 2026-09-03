# frozen_string_literal: true

# Records every SQL shape application code emits during the suite, so that
# db/queries.yml is a build output with one human column — docs/rules/query-ledger.md.
#
# Inert unless QUERY_LEDGER_OUT is set, which only the db:queries tasks do. A query
# with no frame under app/ is never recorded: fixtures, schema loads, Solid Queue's
# own traffic and the framework's SELECT 1 all fall out here, so a Rails upgrade
# cannot add entries. An untested query records nothing, which is the property this
# buys: it cannot be reviewed without a test.
module QueryLedger
  module Recorder
    extend self

    # A shape is a query with its literals removed. PostgreSQL already binds as $1;
    # MySQL and Trilogy inline the literal; both end as `?`. A list of them is one
    # `?`, so `IN (1, 2, 3)` and `IN (1)` are the same plan and the same entry.
    def normalize(sql)
      sql.gsub(/\$\d+/, "?")
         .gsub(/'(?:[^'\\]|\\.|'')*'/, "?")
         .gsub(/\b\d+(?:\.\d+)?\b/, "?")
         .gsub(/\?(?:\s*,\s*\?)+/, "?")
         .gsub(/\s+/, " ")
         .strip
    end

    def record(payload)
      return if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])

      frame = Rails.backtrace_cleaner.clean(caller).find { |line| line.start_with?("app/") }
      return unless frame

      entry = { sql: normalize(payload[:sql]), from: frame[/\A[^:]+/], example: example(payload) }
      File.open(ENV.fetch("QUERY_LEDGER_OUT"), "a") { |f| f.puts JSON.generate(entry) }
    rescue StandardError => e
      warn "query ledger: #{e.class}: #{e.message}"
    end

    # The literal query, kept only so db:queries:explain has something to run: a
    # plan needs values, and `?` is not a value. It never reaches db/queries.yml.
    def example(payload)
      binds = payload[:type_casted_binds]
      binds = binds.call if binds.respond_to?(:call)
      return payload[:sql] if binds.blank?

      connection = payload[:connection]
      position = -1
      payload[:sql].gsub(/\$(\d+)|\?/) do |placeholder|
        index = placeholder == "?" ? (position += 1) : Regexp.last_match(1).to_i - 1
        connection.quote(binds[index])
      end
    end
  end

  if ENV["QUERY_LEDGER_OUT"]
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      Recorder.record(payload)
    end
  end
end
