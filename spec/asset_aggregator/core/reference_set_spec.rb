require 'spec/spec_helper'

describe AssetAggregator::Core::ReferenceSet do
  before :each do
    @reference_set = AssetAggregator::Core::ReferenceSet.new
    @ref1 = make_ref(:foo, 'bar', 'baz', 'bonk')
  end
  
  def make_ref(aggregate_type, fragment_source_position_file, reference_source_position_file, descrip)
    AssetAggregator::Core::FragmentReference.new(
      aggregate_type,
      AssetAggregator::Core::SourcePosition.new(fragment_source_position_file, nil),
      AssetAggregator::Core::SourcePosition.new(reference_source_position_file, nil),
      descrip
    )
  end
  
  it "should not add duplicate references" do
    @reference_set.add(@ref1)
    @reference_set.add(make_ref(:foo, 'bar', 'baz', 'bongo'))
    @reference_set.instance_variable_get(:@references).length.should == 1
  end
  
  it "should yield subpaths and references correctly, in order" do
    ref2 = make_ref(:foo, 'bar', 'baz', 'something else')
    ref3 = make_ref(:foo, 'baz', 'bonk', 'whatever')
    ref4 = make_ref(:foo, 'aaa', 'baz', 'more')
    ref5 = make_ref(:bar, 'bar', 'baz', 'something else')
    
    [ @ref1, ref2, ref3, ref4, ref5 ].each { |r| @reference_set.add(r) }
    
    asset_aggregator = mock(:asset_aggregator)
    asset_aggregator.should_receive(:aggregated_subpath_for).with(:foo, @ref1.fragment_source_position).and_return('agg_1')
    asset_aggregator.should_receive(:aggregated_subpath_for).with(:foo, ref3.fragment_source_position).and_return('agg_2')
    asset_aggregator.should_receive(:aggregated_subpath_for).with(:foo, ref4.fragment_source_position).and_return('agg_1')
    
    output = [ ]
    @reference_set.each_aggregate_reference(:foo, asset_aggregator) do |subpath, references|
      output << [ subpath, references ]
    end
    
    output.length.should == 2

    output[0][0].should == 'agg_1'
    references = output[0][1]
    references.length.should == 2
    references[0].reference_source_position.file.should == File.canonical_path('baz')
    references[1].reference_source_position.file.should == File.canonical_path('baz')
    
    output[1][0].should == 'agg_2'
    references = output[1][1]
    references.length.should == 1
    references[0].reference_source_position.file.should == File.canonical_path('bonk')
  end
  
  it "should just not yield anything for subpaths with no data" do
    asset_aggregator = mock(:asset_aggregator)
    
    output = [ ]
    @reference_set.each_aggregate_reference(:foo, asset_aggregator) do |subpath, references|
      output << [ subpath, references ]
    end
    
    output.should be_empty
  end
end
