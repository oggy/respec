require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Respec::Formatter do
  describe ".extract_spec_location" do
    use_attribute_value RSpec.configuration, :pattern, "**/*_spec.rb"

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
      Respec::Formatter.should_receive(:warn)
      metadata = {:location => './spec/models/user.rb:47'}
      expect(described_class.extract_spec_location(metadata)).
        to eq './spec/models/user.rb:47'
    end
  end
end
