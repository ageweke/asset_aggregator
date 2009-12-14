require 'spec/spec_helper'

# See the spec for AssetAggregator::Filters::Jsmin. Again, this is
# just a basic sanity check.
describe AssetAggregator::Filters::JsminFilter do
  it "should minimize some simple JavaScript code" do
    maximal_code = %{// A sample function
    if (a < b) {
      /* Nice! */
      alert("hi, there!");
    } else
      alert("goodbye!"); /* Something more */
    }
    
    AssetAggregator::Filters::JsminFilter.new.filter(maximal_code).strip.should == %{if(a<b){alert("hi, there!");}else\nalert("goodbye!");}
  end
end