require 'rspec/core/formatters/base_formatter'

module Respec
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def start_dump
      @failed_examples.each do |example|
        output.puts self.class.extract_spec_location(example.metadata)
      end
    end

    def self.extract_spec_location(metadata)
      root_metadata = metadata
      until metadata[:location] =~ /_spec.rb:\d+$/
        metadata = metadata[:example_group]
        if !metadata
          warn "no spec file found for #{root_metadata[:location]}"
          return root_metadata[:location]
        end
      end
      metadata[:location]
    end
  end
end

# We inject this here rather than on the command line, as the logic to assemble
# the list of formatters is complex, and easily broken by adding a --format
# option.
RSpec.configure do |config|
  config.add_formatter 'progress' if config.formatters.empty?
  config.add_formatter Respec::Formatter, ENV['RESPEC_FAILURES'] || File.expand_path(".respec_failures")
end
