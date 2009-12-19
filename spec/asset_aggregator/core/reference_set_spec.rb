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
  
  context "when computing subpaths" do
    before :each do
      @ref_name_number = 0
    end
    
    def ref(subpaths, aggregate_type = :foo)
      @ref_name_number += 1
      out = make_ref(aggregate_type, "fsp_#{@ref_name_number}", "rsp_#{@ref_name_number}", "descrip_#{@ref_name_number}")
      out.instance_variable_set(:@returned_subpaths, subpaths)
      
      class << out
        def aggregate_subpaths(asset_aggregator)
          Array(@returned_subpaths)
        end
      end
      
      out
    end
    
    def check_ref_map(refs, expected_map)
      Array(refs).each { |r| @reference_set.add(r) }
      
      actual_map = { }
      @reference_set.each_aggregate_reference(:foo, mock(:asset_aggregator)) do |subpath, references|
        actual_map[subpath] = references
      end
      
      actual_map.keys.sort.should == expected_map.keys.sort
      actual_map.each do |actual_key, actual_value|
        expected_value = expected_map[actual_key].sort
        
        unless actual_value == expected_value
          raise "Mismatch: for key #{actual_key}, expected:\n  #{expected_value.join(", ")}\nbut got:\n  #{actual_value.join(", ")}"
        end
      end
    end
    
    it "should compute a single subpath for a single reference" do
      r1 = ref('aaa')
      check_ref_map(r1, 'aaa' => [ r1 ])
    end
    
    it "should return the alphabetically-first subpath for a single reference" do
      r1 = ref(%w{bbb aaa})
      check_ref_map(r1, 'aaa' => [ r1 ])
    end
    
    it "should return the alphabetically-first subset when they're equivalent" do
      r1 = ref(%w{bbb aaa ddd})
      r2 = ref(%w{bbb aaa ccc})
      
      check_ref_map([ r1, r2 ], 'aaa' => [ r1, r2 ])
    end
    
    it "should find the smallest subset that covers the references" do
      # This is set up so that if you grab the biggest, or alphabetically-first,
      # subset first -- aaa -- you end up with a suboptimal solution
      # (e.g., aaa ccc bbb, aaa zzz qqq xxx, or something like that).
      # But bbb ccc covers it all, which is what we need it to find.
      r1 = ref(%w{aaa bbb ccc})
      r2 = ref(%w{aaa bbb ddd})
      r3 = ref(%w{aaa bbb eee})
      r4 = ref(%w{aaa ccc fff})
      r5 = ref(%w{aaa ccc ggg})
      r6 = ref(%w{aaa ccc hhh})
      r7 = ref(%w{zzz ccc iii})
      r8 = ref(%w{qqq ccc jjj})
      r9 = ref(%w{xxx bbb kkk})
      
      # Note that r1 is in both sets below, as it should be.
      check_ref_map([ r1, r2, r3, r4, r5, r6, r7, r8, r9 ],
        'bbb' => [ r1, r2, r3, r9 ],
        'ccc' => [ r1, r4, r5, r6, r7, r8 ]
      )
    end
  end
  
  it "should return the set of aggregate types correctly" do
    @reference_set.add(@ref1)
    @reference_set.add(make_ref(:foo, 'bar', 'bonk', 'whatever'))
    @reference_set.add(make_ref(:bar, 'bar', 'haha', 'yo'))
    
    @reference_set.aggregate_types.should == [ :bar, :foo ]
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
