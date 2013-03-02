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

# We inject this here rather than on the command line, as the logic to assemble
# the list of formatters is complex, and easily broken by adding a --format
# option.
RSpec.configure do |config|
  config.add_formatter 'progress' if config.formatters.empty?
  config.add_formatter Respec::Formatter, ENV['RESPEC_FAILURES'] || File.expand_path(".respec_failures")
end
