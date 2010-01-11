require 'spec/spec_helper'

describe AssetAggregator::Core::Filter do
  it "should raise an exception on #filter" do
    filter = AssetAggregator::Core::Filter.new
    lambda { filter.filter(mock(:fragment), "foo") }.should raise_error
  end
end