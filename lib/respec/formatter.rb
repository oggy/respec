require 'rspec/core/formatters/base_formatter'
require 'rspec/core/version'

module Respec
  def self.failures_path
    ENV['RESPEC_FAILURES'] || File.expand_path(".respec_failures")
  end

  if (RSpec::Core::Version::STRING.scan(/\d+/).map { |s| s.to_i } <=> [3]) < 0

    class Formatter < RSpec::Core::Formatters::BaseFormatter
      def initialize(output=nil)
        super(output)
      end

      def start_dump
        open(Respec.failures_path, 'w') do |file|
          @failed_examples.each do |example|
            file.puts example.metadata[:full_description]
          end
        end
      end
    end

  else

    class Formatter < RSpec::Core::Formatters::BaseFormatter
      def initialize(output=nil)
        @respec_failures = []
        super(output)
      end

      def example_failed(notification)
        @respec_failures << notification.example.full_description
      end

      def start_dump(notification)
        open(Respec.failures_path, 'w') do |file|
          @respec_failures.each do |failure|
            file.puts failure
          end
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
  config.add_formatter Respec::Formatter
end
