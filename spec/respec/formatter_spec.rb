require_relative '../spec_helper'
require 'rspec/version'

if (RSpec::Version::STRING.scan(/\d+/).map { |s| s.to_i } <=> [3]) < 0
  describe Respec::Formatter do
    describe ".extract_spec_location" do
      before { allow(RSpec.configuration).to receive(:pattern).and_return("**/*_spec.rb") }

      it "should find the spec file for normal examples" do
        metadata = {:location => './spec/models/user_spec.rb:47'}
        expect(described_class.extract_spec_location(metadata)).
          to eq './spec/models/user_spec.rb:47'
      end

      it "should find the spec file for shared examples" do
        metadata = {
          :location => './spec/support/breadcrumbs.rb:75',
          :example_group => {:location => './spec/requests/breadcrumbs_spec.rb:218'},
        }
        expect(described_class.extract_spec_location(metadata)).
          to eq './spec/requests/breadcrumbs_spec.rb:218'
      end

      it "should warn when no spec file is found, and return the root location" do
        expect(Respec::Formatter).to receive(:warn)
        metadata = {:location => './spec/models/user.rb:47'}
        expect(described_class.extract_spec_location(metadata)).
          to eq './spec/models/user.rb:47'
      end
    end
  end
else
  describe Respec::Formatter do
    let(:output) { StringIO.new }
    let(:formatter) { Respec::Formatter.new(output) }

    def make_failure_notification(location)
      example = double(RSpec::Core::Example.allocate, location: location)
      RSpec::Core::Notifications::FailedExampleNotification.new(example)
    end

    it "records failed example names and dumps them at the end" do
      formatter.example_failed(make_failure_notification('/path/to/a:1'))
      formatter.example_failed(make_failure_notification('/path/to/b:2'))
      formatter.start_dump(RSpec::Core::Notifications::NullNotification)
      expect(output.string).to eq "/path/to/a:1\n/path/to/b:2\n"
    end

    it "empties the failure file if no examples failed" do
      formatter.start_dump(RSpec::Core::Notifications::NullNotification)
      expect(output.string).to eq ''
    end
  end
end
