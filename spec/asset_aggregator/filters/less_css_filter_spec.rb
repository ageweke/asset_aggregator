require 'spec/spec_helper'

# This spec is NOT meant to test all the features of less; that's a job
# for the specs in less itself. 
describe AssetAggregator::Filters::LessCssFilter do
  def filter(input, options = { })
    @fragment = mock(:fragment)
    AssetAggregator::Filters::LessCssFilter.new(options).filter(@fragment, input)
  end
  
  it "should process input through less" do
    filter(".foo { .bar { color: red } }").strip.should == ".foo .bar { color: red; }"
  end
  
  it "should add a prefix where appropriate" do
    filter(".foo { .bar { color: @my_color; } }", :prefix => "@my_color: red;").strip.should == ".foo .bar { color: red; }"
  end
  
  it "should call back on the :processing proc" do
    processing_calls = [ ]
    processing = Proc.new { |fragment, input, time| processing_calls << [ fragment, input, time ] }
    
    filter(".foo { .bar { color: red } }", :processing => processing).strip.should == ".foo .bar { color: red; }"
    processing_calls.length.should == 1
    processing_calls[0][0].should == @fragment
    processing_calls[0][1].should == ".foo { .bar { color: red } }"
    processing_calls[0][2].should >= 0
    processing_calls[0][2].should <= 0.2
    
    filter(".foo { .bar { color: blue } }", :processing => processing).strip.should == ".foo .bar { color: blue; }"
    processing_calls.length.should == 2
    processing_calls[1][0].should == @fragment
    processing_calls[1][1].should == ".foo { .bar { color: blue } }"
    processing_calls[1][2].should >= 0
    processing_calls[1][2].should <= 0.2
  end
end