require 'rspec/core/formatters/base_formatter'
require 'rspec/core/version'

if (RSpec::Core::Version::STRING.scan(/\d+/).map { |s| s.to_i } <=> [3]) < 0
  module Respec
    class Formatter < RSpec::Core::Formatters::BaseFormatter
      def start_dump
        @failed_examples.each do |example|
          output.puts self.class.extract_spec_location(example.metadata)
        end
      end

      def self.extract_spec_location(metadata)
        root_metadata = metadata
        until spec_path?(metadata[:location])
          metadata = metadata[:example_group]
          if !metadata
            warn "no spec file found for #{root_metadata[:location]}"
            return root_metadata[:location]
          end
        end
        metadata[:location]
      end

      def self.spec_path?(path)
        flags = File::FNM_PATHNAME | File::FNM_DOTMATCH
        if File.const_defined?(:FNM_EXTGLOB)  # ruby >= 2
          flags |= File::FNM_EXTGLOB
        end
        File.fnmatch(RSpec.configuration.pattern, path.sub(/:\d+\z/, ''), flags)
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
        @respec_failures << notification.example.location
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
