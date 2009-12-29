require 'spec/spec_helper'

describe AssetAggregator::OutputHandlers::JavascriptOutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @output_handler = AssetAggregator::OutputHandlers::JavascriptOutputHandler.new(@aggregate_type, @subpath, Time.now.to_i, { })
  end

  it "should have the right extension" do
    @output_handler.extension.should == 'js'
  end
end
