require 'spec/spec_helper'

describe AssetAggregator::Filters::CssminFilter do
  before :each do
    @fragment = mock(:fragment)
    @filter = AssetAggregator::Filters::CssminFilter.new
  end
  
  it "should compress CSS in a sane manner" do
    result = @filter.filter(@fragment, <<-EOM)
  .foo {
    
    color : green ;
    
    
    background   : blue ;
    
  }
  
  .bar {
    
    font-size : 16 px ;
    
  }
EOM
    result.strip.should == ".foo {color : green ; background : blue }\n.bar {font-size : 16 px }"
  end
end
