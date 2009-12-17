require 'spec/spec_helper'

describe AssetAggregator::Core::Aggregator do
  before :each do
    @file_cache = mock(:file_cache)
    @filter1 = mock(:filter1)
    @filter2 = mock(:filter2)
    @filters = [ @filter1, @filter2 ]
    @aggregate_type = mock(:aggregate_type)
    @test_fragment_set = mock(:fragment_set)
    
    @aggregator = AssetAggregator::Core::Aggregator.new(@aggregate_type, @file_cache, @filters)
    
    class << @aggregator
      attr_accessor :refresh_fragments_since_calls
      
      def refresh_fragments_since(last_refresh_fragments_since_time)
        @refresh_fragments_since_calls ||= [ ]
        @refresh_fragments_since_calls << last_refresh_fragments_since_time
      end
      
      def fragment_set
        @test_fragment_set
      end
    end
    
    @aggregator.instance_variable_set(:@test_fragment_set, @test_fragment_set)
  end
  
  it "should populate the filters correctly in its fragment set" do
    @aggregator = AssetAggregator::Core::Aggregator.new(@aggregate_type, @file_cache, @filters)
    @aggregator.instance_variable_get(:@fragment_set).instance_variable_get(:@filters).should == @filters
  end
  
  it "should return the set of all subpaths correctly" do
    subpaths = %w{foo bar baz}
    @test_fragment_set.should_receive(:all_subpaths).once.and_return(subpaths)
    @aggregator.all_subpaths.should == subpaths
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should pass through #fragment_for correctly" do
    fragment = mock(:fragment)
    source_position = mock(:source_position)
    @test_fragment_set.should_receive(:for_source_position).once.with(source_position).and_return(fragment)
    @aggregator.fragment_for(source_position).should == fragment
    
    source_position_2 = mock(:source_position_2)
    @test_fragment_set.should_receive(:for_source_position).once.with(source_position_2).and_return(nil)
    @aggregator.fragment_for(source_position_2).should be_nil
  end
  
  it "should return the right #aggregated_subpath_for, and make sure it's refreshed first (but only once)" do
    source_position = mock(:source_position)
    @test_fragment_set.should_receive(:aggregated_subpath_for).once.with(source_position).and_return("a/b/c/d/e")
    @aggregator.aggregated_subpath_for(source_position).should == "a/b/c/d/e"
    @aggregator.refresh_fragments_since_calls.should == [ nil ]

    @test_fragment_set.should_receive(:aggregated_subpath_for).once.with(source_position).and_return("a/b/c/d/e")
    @aggregator.aggregated_subpath_for(source_position).should == "a/b/c/d/e"
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should return the filtered content from a fragment correctly" do
    fragment = mock(:fragment)
    filtered_content = "filteredyo"
    @test_fragment_set.should_receive(:filtered_content_from).once.with(fragment).and_return(filtered_content)
    @aggregator.filtered_content_from(fragment).should == filtered_content
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should call #refresh_fragments_since with the right time on #refresh!" do
    start_time_1 = Time.now
    @aggregator.refresh!
    end_time_1 = Time.now
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
    
    sleep 1.1
    start_time_2 = Time.now
    @aggregator.refresh!
    end_time_2 = Time.now
    @aggregator.refresh_fragments_since_calls.length.should == 2
    @aggregator.refresh_fragments_since_calls[0].should be_nil
    @aggregator.refresh_fragments_since_calls[1].should >= start_time_1
    @aggregator.refresh_fragments_since_calls[1].should <= end_time_1

    @aggregator.refresh!
    @aggregator.refresh_fragments_since_calls.length.should == 3
    @aggregator.refresh_fragments_since_calls[2].should >= start_time_2
    @aggregator.refresh_fragments_since_calls[2].should <= end_time_2
  end
  
  it "should call through to the fragment set on #each_fragment_for" do
    subpath = 'foo/bar'
    fragments = [ mock(:fragment1), mock(:fragment2) ]
    @test_fragment_set.should_receive(:each_fragment_for).once.with(subpath).and_yield(fragments[0]).and_yield(fragments[1])
    actual_fragments = [ ]
    @aggregator.each_fragment_for(subpath) { |f| actual_fragments << f }
    actual_fragments.should == fragments
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should find the tagged subpath only when appropriate" do
    @aggregator.send(:tagged_subpath, 'foo/bar', "hi ho ho").should be_nil
    @aggregator.send(:tagged_subpath, 'foo/bar', %{hi ho ho
      bonk
      ASSET yo}).should be_nil
    @aggregator.send(:tagged_subpath, 'foo/bar', %{hi ho ho
      ASSET TARGET foobarbaz
      bonk}).should == 'foobarbaz'
  end
end
