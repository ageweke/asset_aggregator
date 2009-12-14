require 'spec/spec_helper'

# This spec is NOT meant to test all the features of less; that's a job
# for the specs in less itself. 
describe AssetAggregator::Filters::LessCssFilter do
  def filter(input, prefix = nil)
    AssetAggregator::Filters::LessCssFilter.new(prefix).filter(input)
  end
  
  it "should process input through less" do
    filter(".foo { .bar { color: red } }").strip.should == ".foo .bar { color: red; }"
  end
  
  it "should add a prefix where appropriate" do
    filter(".foo { .bar { color: @my_color; } }", "@my_color: red;").strip.should == ".foo .bar { color: red; }"
  end
end