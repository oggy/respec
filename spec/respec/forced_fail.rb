require File.expand_path('../spec_helper', File.dirname(__FILE__))

describe Respec::ForcedFail do
	it "falls on its face" do
		expect(1).to eq(0)
	end
end