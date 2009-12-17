require 'spec/spec_helper'

describe AssetAggregator::Core::FragmentReference do
  before :each do
    @aggregate_type = :foo
    @fragment_source_position = mock(:fragment_source_position)
    @reference_source_position = mock(:reference_source_position)
    @descrip = "hooha"
    
    @reference = AssetAggregator::Core::FragmentReference.new(@aggregate_type, @fragment_source_position, @reference_source_position, @descrip)
  end
  
  it "should return its components correctly" do
    @reference.aggregate_type.should == @aggregate_type
    @reference.fragment_source_position.should == @fragment_source_position
    @reference.reference_source_position.should == @reference_source_position
    @reference.descrip.should == @descrip
  end
  
  it "should pass #aggregate_subpath through to the AssetAggregator passed in" do
    subpath = 'foo/bar/baz'
    asset_aggregator = mock(:asset_aggregator)
    asset_aggregator.should_receive(:aggregated_subpath_for).once.with(@aggregate_type, @fragment_source_position).and_return(subpath)
    @reference.aggregate_subpath(asset_aggregator).should == subpath
  end
  
  it "should raise an error if there is no #aggregate_subpath for this fragment" do
    asset_aggregator = mock(:asset_aggregator)
    asset_aggregator.should_receive(:aggregated_subpath_for).once.with(@aggregate_type, @fragment_source_position).and_return(nil)
    lambda { @reference.aggregate_subpath(asset_aggregator) }.should raise_error
  end
  
  context "when comparing" do
    it "should compare types against AggregateReference objects" do
      (@reference <=> AssetAggregator::Core::AggregateReference.new(:bar, 'foo/bar', @reference_source_position, 'whatever')).should > 0
    end
    
    it "should order itself before any AggregateReference objects with the same type" do
      (@reference <=> AssetAggregator::Core::AggregateReference.new(:foo, 'foo/bar', @reference_source_position, 'whatever')).should < 0
    end

    it "should first compare on aggregate_type" do
      (@reference <=> AssetAggregator::Core::FragmentReference.new(:bar, @fragment_source_position, @reference_source_position, @descrip)).should > 0
      (@reference <=> AssetAggregator::Core::FragmentReference.new(:moo, @fragment_source_position, @reference_source_position, @descrip)).should < 0
    end

    it "should compare on fragment_source_position first" do
      other_fragment_source_position = mock(:other_fragment_source_position)
      @fragment_source_position.should_receive(:'<=>').with(other_fragment_source_position).once.and_return -1
      (@reference <=> AssetAggregator::Core::FragmentReference.new(@aggregate_type, other_fragment_source_position, mock(:reference_source_position), "whatever")).should < 0
    end

    it "should compare on reference_source_position next" do
      other_reference_source_position = mock(:other_reference_source_position)
      @fragment_source_position.should_receive(:'<=>').with(@fragment_source_position).once.and_return 0
      @reference_source_position.should_receive(:'<=>').with(other_reference_source_position).once.and_return -1
      (@reference <=> AssetAggregator::Core::FragmentReference.new(@aggregate_type, @fragment_source_position, other_reference_source_position, "whatever")).should < 0
    end
    
    it "should ignore descrip" do
      @fragment_source_position.should_receive(:'<=>').with(@fragment_source_position).once.and_return 0
      @reference_source_position.should_receive(:'<=>').with(@reference_source_position).once.and_return 0
      (@reference <=> AssetAggregator::Core::FragmentReference.new(@aggregate_type, @fragment_source_position, @reference_source_position, "blablah")).should == 0
    end
  end
  
  it "should turn itself into a string correctly" do
    @fragment_source_position.should_receive(:to_s).and_return "foo"
    @reference_source_position.should_receive(:to_s).and_return "bonk"
    @reference.to_s.should == "foo reference: bonk refers to foo (hooha)"
  end
end
