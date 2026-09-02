# frozen_string_literal: true

# The OpenAPI document is generated from the request tests and committed, and CI
# fails when the two disagree — docs/rules/openapi-contract.md.
#
#   bin/rails api:contract        regenerate openapi.yaml
#   bin/rails api:contract:check  exit 1 on drift, which is what CI runs
namespace :api do
  CONTRACT_PATH = "openapi.yaml"

  desc "Regenerate #{CONTRACT_PATH} from the request tests"
  task :contract do
    File.write(CONTRACT_PATH, Api::ContractBuilder.generate)
    puts "#{CONTRACT_PATH} written"
  end

  namespace :contract do
    desc "Fail if #{CONTRACT_PATH} disagrees with the request tests"
    task :check do
      fresh = Api::ContractBuilder.generate
      committed = File.exist?(CONTRACT_PATH) ? File.read(CONTRACT_PATH) : ""

      if fresh == committed
        puts "#{CONTRACT_PATH} is current"
      else
        warn "#{CONTRACT_PATH} disagrees with the request tests. Run `bin/rails api:contract` and commit the result."
        exit 1
      end
    end
  end
end

module Api
  # Runs the integration suite with the recorder armed, then folds what it saw into
  # an OpenAPI document. Deliberately minimal: it describes the endpoints, statuses
  # and problem types the tests actually exercised, and claims nothing else.
  module ContractBuilder
    extend self

    def generate
      entries = collect
      abort "No API requests recorded. Are there request tests under test/integration?" if entries.empty?
      to_yaml(entries)
    end

    def collect
      require "tempfile"
      Tempfile.create("openapi") do |file|
        ok = system({ "OPENAPI_OUT" => file.path }, "bin/rails", "test", "test/integration",
                    out: File::NULL)
        abort "The request tests failed, so the contract they would describe is not trustworthy." unless ok

        File.readlines(file.path).map { |line| JSON.parse(line) }.uniq
      end
    end

    def to_yaml(entries)
      paths = entries.group_by { |e| e["path"] }.transform_values do |for_path|
        for_path.group_by { |e| e["method"].downcase }.transform_values { |for_method| operation(for_method) }
      end

      {
        "openapi" => "3.1.0",
        "info" => { "title" => Rails.application.class.module_parent_name, "version" => "v1" },
        "paths" => paths.sort.to_h.transform_values { |ops| ops.sort.to_h }
      }.to_yaml
    end

    def operation(observations)
      responses = observations.sort_by { |o| o["status"] }.to_h do |o|
        [ o["status"].to_s, response_object(o) ]
      end
      { "responses" => responses }
    end

    def response_object(observation)
      described = observation["problem_type"] ? "problem: #{observation['problem_type']}" : "observed in a request test"
      content = { observation["media_type"] => {} }
      content[observation["media_type"]] = { "x-top-level-keys" => observation["keys"] } if observation["keys"].any?
      { "description" => described, "content" => content }
    end
  end
end
