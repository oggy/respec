require_relative '../spec_helper'
require 'rspec/version'

describe Respec::Formatter do
  use_temporary_directory TMP
  let(:formatter) { Respec::Formatter.new }

  def failures
    File.read("#{TMP}/failures.txt")
  end

  describe Respec::Formatter do
    if (RSpec::Core::Version::STRING.scan(/\d+/).map { |s| s.to_i } <=> [3]) < 0

      before { Respec.stub(failures_path: "#{TMP}/failures.txt") }

      def make_failing_example(description)
        metadata = {full_description: description}
        mock(RSpec::Core::Example.allocate, metadata: metadata)
      end

      it "records failed example names and dumps them at the end" do
        failed_examples = [make_failing_example('example 1'), make_failing_example('example 2')]
        formatter.instance_variable_set(:@failed_examples, failed_examples)
        formatter.start_dump
        expect(failures).to eq "example 1\nexample 2\n"
      end

      it "empties the failure file if no examples failed" do
        formatter.start_dump
        expect(failures).to eq ''
      end

    else

      before { allow(Respec).to receive(:failures_path).and_return("#{TMP}/failures.txt") }

      def make_failure_notification(description)
        result = RSpec::Core::Example::ExecutionResult.new
        example = double(RSpec::Core::Example.allocate, full_description: description, execution_result: result)
        RSpec::Core::Notifications::FailedExampleNotification.new(example)
      end

      it "records failed example names and dumps them at the end" do
        formatter.example_failed(make_failure_notification('example 1'))
        formatter.example_failed(make_failure_notification('example 2'))
        formatter.start_dump(RSpec::Core::Notifications::NullNotification)
        expect(failures).to eq "example 1\nexample 2\n"
      end

      it "empties the failure file if no examples failed" do
        formatter.start_dump(RSpec::Core::Notifications::NullNotification)
        expect(failures).to eq ''
      end

    end
  end
end
