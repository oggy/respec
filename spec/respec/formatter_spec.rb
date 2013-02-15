describe Respec::Formatter do
  describe ".extract_spec_location" do
    it "should find the spec file for normal examples" do
      metadata = {:location => './spec/models/user_spec.rb:47'}
      described_class.extract_spec_location(metadata).should eq './spec/models/user_spec.rb:47'
    end
    
    it "should find the spec file for shared examples" do
      metadata = {:location => './spec/support/breadcrumbs.rb:75',
                   :example_group => {:location => './spec/requests/breadcrumbs_spec.rb:218'}
                 }
      described_class.extract_spec_location(metadata).should eq './spec/requests/breadcrumbs_spec.rb:218'
    end
    
    it "should cry when no spec file is found" do
      metadata = {:location => './spec/models/user.rb:47'}
      expect {
        described_class.extract_spec_location(metadata)
      }.to raise_exception 'No spec file could be found in meta data!'
    end
  end
end
