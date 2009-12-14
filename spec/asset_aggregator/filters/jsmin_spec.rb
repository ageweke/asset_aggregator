require 'spec/spec_helper'

# This is NOT intended to be a full spec for jsmin; that's way, way beyond
# scope here. Rather, this is just enough to make sure our translation
# of jsmin (encapsulating it within a class) actually does things right.
describe AssetAggregator::Filters::Jsmin do
  it "should minimize some simple JavaScript code" do
    maximal_code = %{// A sample function
    if (a < b) {
      /* Nice! */
      alert("hi, there!");
    } else
      alert("goodbye!"); /* Something more */
    }
    
    AssetAggregator::Filters::Jsmin.convert(maximal_code).strip.should == %{if(a<b){alert("hi, there!");}else\nalert("goodbye!");}
  end
end