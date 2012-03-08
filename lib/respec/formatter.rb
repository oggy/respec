require 'rspec/core/formatters/base_formatter'

module Respec
  class Formatter < RSpec::Core::Formatters::BaseFormatter
    def start_dump
      @failed_examples.each do |example|
        output.puts example.metadata[:location]
      end
    end
  end
end
