require 'spec/spec_helper'

describe AssetAggregator::OutputHandlers::CssOutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @output_handler = AssetAggregator::OutputHandlers::CssOutputHandler.new(@aggregate_type, @subpath, { })
  end

  it "should have the right extension" do
    @output_handler.extension.should == 'css'
  end
end
