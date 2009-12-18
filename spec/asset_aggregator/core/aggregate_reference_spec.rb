require 'spec/spec_helper'

describe AssetAggregator::Core::AggregateReference do
  before :each do
    @aggregate_type = :foo
    @subpath = "foo/bar"
    @reference_source_position = mock(:reference_source_position)
    @descrip = "whatever"
    
    @aggregate_reference = AssetAggregator::Core::AggregateReference.new(@aggregate_type, @subpath, @reference_source_position, @descrip)
  end
  
  it "should return its components correctly" do
    @aggregate_reference.aggregate_type.should == @aggregate_type
    @aggregate_reference.subpath.should == @subpath
    @aggregate_reference.reference_source_position.should == @reference_source_position
    @aggregate_reference.descrip.should == @descrip
  end
  
  it "should return its own subpath for #aggregate_subpaths" do
    asset_aggregator = mock(:asset_aggregator)
    @aggregate_reference.aggregate_subpaths(asset_aggregator).should == [ @subpath ]
  end
  
  def make(type, subpath, reference_source_position, descrip)
    AssetAggregator::Core::AggregateReference.new(type, subpath, reference_source_position, descrip)
  end
  
  context "when comparing" do
    it "should compare types against FragmentReference objects" do
      (@aggregate_reference <=> AssetAggregator::Core::FragmentReference.new(:zzz, mock(:fragment_source_position), @reference_source_position, "whatever")).should < 0
    end
    
    it "should order itself after any FragmentReference objects with the same type" do
      (@aggregate_reference <=> AssetAggregator::Core::FragmentReference.new(@aggregate_type, mock(:fragment_source_position), @reference_source_position, "whatever")).should > 0
    end
    
    it "should compare types first" do
      (@aggregate_reference <=> make(:bar, @subpath, @reference_source_position, @descrip)).should > 0
      (@aggregate_reference <=> make(:zzz, @subpath, @reference_source_position, @descrip)).should < 0
    end
    
    it "should compare subpaths next" do
      (@aggregate_reference <=> make(@aggregate_type, "foo/baz", @reference_source_position, @descrip)).should < 0
      (@aggregate_reference <=> make(@aggregate_type, "foo/baa", @reference_source_position, @descrip)).should > 0
    end
    
    it "should compare reference_source_positions next" do
      reference_source_position_2 = mock(:reference_source_position_2)
      @reference_source_position.should_receive(:'<=>').with(reference_source_position_2).and_return(1)
      (@aggregate_reference <=> make(@aggregate_type, @subpath, reference_source_position_2, @descrip)).should > 0
      
      reference_source_position_3 = mock(:reference_source_position_3)
      @reference_source_position.should_receive(:'<=>').with(reference_source_position_3).and_return(-1)
      (@aggregate_reference <=> make(@aggregate_type, @subpath, reference_source_position_3, @descrip)).should < 0
    end
    
    it "should ignore descrip" do
      @reference_source_position.should_receive(:'<=>').with(@reference_source_position).once.and_return 0
      (@aggregate_reference <=> make(@aggregate_type, @subpath, @reference_source_position, "something else")).should == 0
    end
  end
  
  it "should turn itself into a string correctly" do
    @reference_source_position.should_receive(:to_s).and_return("hoohah")
    @aggregate_reference.to_s.should == "foo reference: hoohah explicitly refers to aggregate 'foo/bar' (whatever)"
  end
end
