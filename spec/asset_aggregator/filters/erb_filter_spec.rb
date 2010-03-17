require 'spec/spec_helper'

describe AssetAggregator::Filters::ErbFilter do
  before :each do
    @variables = { :foo => 'bar', :bar => 123, :baz => 456 }
    @filter = AssetAggregator::Filters::ErbFilter.new(:binding => @variables)
    @source_position = mock(:source_position, :to_s => 'hoohah')
    @fragment = mock(:fragment, :source_position => @source_position)
  end
  
  it "should pass through normal text without a problem" do
    @filter.filter(@fragment, "hi there").should == "hi there"
  end
  
  it "should run ERb commands" do
    @filter.filter(@fragment, "2 + 2 = <%= 2 + 2 %>").should == "2 + 2 = 4"
  end
  
  class MyError < StandardError; end
  
  it "should raise errors, with information about where they came from" do
    lambda { @filter.filter(@fragment, "this is <%= raise(MyError, 'kaboomba') %>") }.should raise_error(RuntimeError, /hoohah.*kaboomba.*MyError/m)
  end
  
  it "should raise syntax errors, with information about where they came from" do
    lambda { @filter.filter(@fragment, "this is <%= blah blah + + * 24 %>") }.should raise_error(RuntimeError, /SyntaxError/m)
  end

  it "should run ERb commands with variables" do
    @filter.filter(@fragment, "<%= foo %>: <%= bar %> + <%= baz %> = <%= bar + baz %>").should == "bar: 123 + 456 = 579"
  end
  
  it "should allow passing in your own Binding" do
    struct = OpenStruct.new
    struct.x = 123
    struct.y = 456
    
    filter = AssetAggregator::Filters::ErbFilter.new(:binding => struct.send(:binding))
    filter.filter(@fragment, "<%= x %> + <%= y %> = <%= x + y %>").should == "123 + 456 = 579"
  end
  
  it "should allow passing in your own object as a binding" do
    struct = OpenStruct.new
    struct.x = 123
    struct.y = 456
    
    filter = AssetAggregator::Filters::ErbFilter.new(:binding => struct)
    filter.filter(@fragment, "<%= x %> + <%= y %> = <%= x + y %>").should == "123 + 456 = 579"
  end
  
  it "should allow passing in no Binding at all" do
    filter = AssetAggregator::Filters::ErbFilter.new
    filter.filter(@fragment, "<% x = 123; y = 456 %><%= x %> + <%= y %> = <%= x + y %>").should == "123 + 456 = 579"
  end
  
  it "should allow trimming newlines" do
    filter = AssetAggregator::Filters::ErbFilter.new
    filter.filter(@fragment, "<%= 1 + 2 %>\n<%= 3 + 4 %>").should == "3\n7"
    filter.filter(@fragment, "<%= 1 + 2 -%>\n<%= 3 + 4 %>").should == "37"
  end
  
  it "should call :binding_proc if supplied" do
    binding_proc_calls = [ ]
    binding_proc = Proc.new do |fragment, input|
      binding_proc_calls << [ fragment, input ]
      { :bar => 333, :baz => 444 }
    end
    
    filter = AssetAggregator::Filters::ErbFilter.new(:binding_proc => binding_proc)
    filter.filter(@fragment, "<%= bar + baz %>").should == "777"
    binding_proc_calls.length.should == 1
    binding_proc_calls[0][0].should == @fragment
    binding_proc_calls[0][1].should == "<%= bar + baz %>"
    
    filter.filter(@fragment, "<%= baz - bar %>").should == "111"
    binding_proc_calls.length.should == 2
    binding_proc_calls[1][0].should == @fragment
    binding_proc_calls[1][1].should == "<%= baz - bar %>"
  end
end
