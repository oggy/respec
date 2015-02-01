require 'rspec/core/formatters/base_formatter'
require 'rspec/core/version'

if (RSpec::Core::Version::STRING.scan(/\d+/).map { |s| s.to_i } <=> [3]) < 0
  module Respec
    class Formatter < RSpec::Core::Formatters::BaseFormatter
      def start_dump
        @failed_examples.each do |example|
          output.puts example.metadata[:full_description]
        end
      end
    end
  end
else
  module Respec
    class Formatter < RSpec::Core::Formatters::BaseFormatter
      def initialize(*)
        @respec_failures = []
        super
      end

      def example_failed(notification)
        @respec_failures << notification.example.full_description
      end

      def start_dump(notification)
        @respec_failures.each do |failure|
          output.puts failure
        end
      end

      RSpec::Core::Formatters.register self, :example_failed, :start_dump
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
