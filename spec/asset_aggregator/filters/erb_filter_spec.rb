require 'spec/spec_helper'

describe AssetAggregator::Filters::ErbFilter do
  before :each do
    @variables = { :foo => 'bar', :bar => 123, :baz => 456 }
    @filter = AssetAggregator::Filters::ErbFilter.new(@variables)
    @fragment = mock(:fragment)
  end
  
  it "should pass through normal text without a problem" do
    @filter.filter(@fragment, "hi there").should == "hi there"
  end
  
  it "should run ERb commands" do
    @filter.filter(@fragment, "2 + 2 = <%= 2 + 2 %>").should == "2 + 2 = 4"
  end

  it "should run ERb commands with variables" do
    @filter.filter(@fragment, "<%= foo %>: <%= bar %> + <%= baz %> = <%= bar + baz %>").should == "bar: 123 + 456 = 579"
  end
  
  it "should allow passing in your own Binding" do
    struct = OpenStruct.new
    struct.x = 123
    struct.y = 456
    
    filter = AssetAggregator::Filters::ErbFilter.new(struct.send(:binding))
    filter.filter(@fragment, "<%= x %> + <%= y %> = <%= x + y %>").should == "123 + 456 = 579"
  end
  
  it "should allow passing in your own object as a binding" do
    struct = OpenStruct.new
    struct.x = 123
    struct.y = 456
    
    filter = AssetAggregator::Filters::ErbFilter.new(struct)
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
end