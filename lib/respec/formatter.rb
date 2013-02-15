require 'rspec/core/formatters/base_formatter'

module Respec
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def start_dump
      @failed_examples.each do |example|
        output.puts self.class.extract_spec_location(example.metadata)
      end
    end
    
    def self.extract_spec_location(metadata)
      while !(metadata[:location] =~ /_spec.rb:\d+$/) do
        metadata = metadata[:example_group]
        raise 'No spec file could be found in meta data!' unless metadata
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
