require 'spec/spec_helper'

describe AssetAggregator::Core::FreezableReferenceSet do
  before :each do
    @set = AssetAggregator::Core::FreezableReferenceSet.new
    @asset_aggregator = mock(:asset_aggregator)
  end
  
  def make_ref(aggregate_type, fragment_source_position_file, reference_source_position_file, descrip)
    AssetAggregator::Core::FragmentReference.new(
      aggregate_type,
      AssetAggregator::Core::SourcePosition.new(fragment_source_position_file, nil),
      AssetAggregator::Core::SourcePosition.new(reference_source_position_file, nil),
      descrip
    )
  end
  
  it "should not raise if we add a reference to a duplicate fragment after we've used the data" do
    ref1 = make_ref(:foo, 'bar', 'baz', 'whatever')
    @set.add(ref1)
    
    @asset_aggregator.should_receive(:aggregated_subpaths_for).with(:foo, ref1.fragment_source_position).and_return([ 'agg_1', 'agg_2' ])
    @set.each_aggregate_reference(:foo, @asset_aggregator) { |subpath, references| }
    
    ref2 = make_ref(:foo, 'bar', 'bonk', 'something else')
    @set.add(ref2)
  end
  
  it "should raise if we add a reference to a distinct fragment after we've used the data" do
    ref1 = make_ref(:foo, 'bar', 'baz', 'whatever')
    @set.add(ref1)
    
    @asset_aggregator.should_receive(:aggregated_subpaths_for).with(:foo, ref1.fragment_source_position).and_return([ 'agg_1', 'agg_2' ])
    @set.each_aggregate_reference(:foo, @asset_aggregator) { |subpath, references| }
    
    ref2 = make_ref(:foo, 'bar2', 'bonk', 'something else')
    lambda { @set.add(ref2) }.should raise_error
  end
end
