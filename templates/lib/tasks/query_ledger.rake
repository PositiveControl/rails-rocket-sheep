# frozen_string_literal: true

# Every SQL shape the suite emits from app/ has a committed, reviewed line in
# db/queries.yml, and CI fails on one the file does not know — docs/rules/query-ledger.md.
#
#   bin/rails db:queries          run the suite, merge new shapes in with an empty review
#   bin/rails db:queries:explain  EXPLAIN every unreviewed entry, with its tables' indexes
#   bin/rails db:queries:check    exit 1 on an unknown shape or an empty review (CI)
module QueryLedger
  module Tasks
    extend self

    PATH = "db/queries.yml"
    SCHEMA = "db/schema.rb"
    # The last recording, kept so explain can run the literal queries without a
    # second suite run.
    RECORDING = "tmp/query_ledger.jsonl"

    # nil when there is no ledger yet, which check treats as "not armed".
    def committed
      YAML.load_file(PATH) || [] if File.exist?(PATH)
    end

    def collect
      FileUtils.mkdir_p(File.dirname(RECORDING))
      File.write(RECORDING, "")
      ok = system({ "QUERY_LEDGER_OUT" => File.expand_path(RECORDING) }, "bin/rails", "test", out: File::NULL)
      abort "The suite failed, so the queries it emits are not trustworthy. `bin/test` shows why." unless ok

      recorded
    end

    def recorded
      File.exist?(RECORDING) ? File.readlines(RECORDING).map { |line| JSON.parse(line) } : []
    end

    # Asymmetric on purpose. A shape the suite emits and the file lacks is added
    # with an empty review; a shape the file has and the suite no longer emits is
    # dropped here and never failed by check, so a test whose branch runs only
    # sometimes adds its query once and never flaps.
    def merge(existing, observed)
      reviews = existing.to_h { |entry| [ key(entry), entry["review"] ] }
      observed.map { |entry| key(entry) }.uniq.sort.map do |from, sql|
        { "sql" => sql, "from" => from, "review" => reviews[[ from, sql ]].to_s }
      end
    end

    def write(entries)
      File.write(PATH, YAML.dump(entries, line_width: -1))
    end

    # Two failures: a shape the file lacks, and a review that is empty or says
    # nothing checkable. A review is valid when it names an index db/schema.rb has,
    # or starts with `no index:` and gives a reason — "fine" is a mood, not a review.
    def problems(committed, observed)
      known = committed.map { |entry| key(entry) }
      unknown = observed.map { |entry| key(entry) }.uniq.sort - known
      findings = unknown.map { |from, sql| "#{from}: #{sql}\n    is not in #{PATH}" }

      committed.each do |entry|
        review = entry["review"].to_s.strip
        if review.empty?
          findings << "#{entry['from']}: #{entry['sql']}\n    has no review"
        elsif !valid_review?(review)
          findings << "#{entry['from']}: #{entry['sql']}\n    review #{review.inspect} names no index in #{SCHEMA} and is not `no index: <reason>`"
        end
      end
      findings
    end

    def valid_review?(review)
      return true if review.match?(/\Ano index:\s*\S/)

      index_names.include?(review)
    end

    def index_names
      File.exist?(SCHEMA) ? File.read(SCHEMA).scan(/t\.index .*name: "([^"]+)"/).flatten : []
    end

    def explain(entry)
      connection = ActiveRecord::Base.connection
      puts "-- #{entry['from']}", "   #{entry['sql']}"

      example = recorded.find { |recording| key(recording) == key(entry) }&.fetch("example")
      if example
        begin
          puts connection.explain(example).gsub(/^/, "   ")
        rescue StandardError => e
          puts "   EXPLAIN failed: #{e.message.lines.first&.strip}"
        end
      else
        puts "   no recording in #{RECORDING}; run `bin/rails db:queries` first"
      end

      tables(entry["sql"]).each do |table|
        indexes = begin
          connection.indexes(table)
        rescue StandardError
          []
        end
        indexes.each do |index|
          puts "   #{table}: #{index.name} (#{index.columns.join(', ')})#{' unique' if index.unique}"
        end
      end
      puts
    end

    def tables(sql)
      sql.scan(/\b(?:FROM|JOIN|INTO|UPDATE)\s+[`"]?(\w+)[`"]?/i).flatten.uniq
    end

    def key(entry)
      [ entry["from"], entry["sql"] ]
    end
  end
end

namespace :db do
  desc "Merge the SQL shapes the suite emits into #{QueryLedger::Tasks::PATH}"
  task :queries do
    ledger = QueryLedger::Tasks.merge(QueryLedger::Tasks.committed.to_a, QueryLedger::Tasks.collect)
    QueryLedger::Tasks.write(ledger)

    unreviewed = ledger.count { |entry| entry["review"].to_s.strip.empty? }
    puts "#{QueryLedger::Tasks::PATH}: #{ledger.size} shapes, #{unreviewed} unreviewed"
    puts "Run `bin/rails db:queries:explain`, then write each review line." if unreviewed.positive?
  end

  namespace :queries do
    desc "Fail if the suite emits a shape #{QueryLedger::Tasks::PATH} lacks, or a review is empty or invalid"
    task :check do
      committed = QueryLedger::Tasks.committed
      if committed.nil?
        puts "No #{QueryLedger::Tasks::PATH}, so nothing is gated. `bin/rails db:queries` creates it."
        next
      end

      problems = QueryLedger::Tasks.problems(committed, QueryLedger::Tasks.collect)
      if problems.empty?
        puts "#{QueryLedger::Tasks::PATH} knows every shape the suite emits (#{committed.size} entries)"
      else
        warn problems.join("\n")
        warn "\nRun `bin/rails db:queries`, then `bin/rails db:queries:explain`, and commit #{QueryLedger::Tasks::PATH}."
        exit 1
      end
    end

    desc "EXPLAIN every unreviewed entry against the development database, with its tables' indexes"
    task explain: :environment do
      committed = QueryLedger::Tasks.committed
      abort "No #{QueryLedger::Tasks::PATH}. Run `bin/rails db:queries` first." if committed.nil?

      unreviewed = committed.select { |entry| entry["review"].to_s.strip.empty? }
      puts "Every entry in #{QueryLedger::Tasks::PATH} is reviewed." if unreviewed.empty?
      unreviewed.each { |entry| QueryLedger::Tasks.explain(entry) }
    end
  end
end
