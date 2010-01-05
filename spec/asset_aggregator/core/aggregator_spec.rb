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
  
  it "should return its components correctly" do
    @aggregator.send(:fragment_set).should == @test_fragment_set
    @aggregator.send(:aggregate_type).should == @aggregate_type
    
    @aggregate_type.should_receive(:type).and_return(:foobar)
    @aggregator.send(:aggregate_type_symbol).should == :foobar
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
  
  it "should return the right #aggregated_subpaths_for, and make sure it's refreshed first (but only once)" do
    source_position = mock(:source_position)
    @test_fragment_set.should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ "a/b/c/d/e", "q/r/s" ])
    @aggregator.aggregated_subpaths_for(source_position).should == [ "a/b/c/d/e", "q/r/s" ]
    @aggregator.refresh_fragments_since_calls.should == [ nil ]

    @test_fragment_set.should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ "a/b/c/d/e", "q/r/s" ])
    @aggregator.aggregated_subpaths_for(source_position).should == [ "a/b/c/d/e", "q/r/s" ]
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should return an empty Array for #aggregated_subpaths_for, rather than nil, if none are found" do
    source_position = mock(:source_position)
    @test_fragment_set.should_receive(:aggregated_subpaths_for).once.with(source_position).and_return(nil)
    @aggregator.aggregated_subpaths_for(source_position).should == [ ]
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
    @test_fragment_set.should_receive(:each_fragment_for).once.with(subpath, nil).and_yield(fragments[0]).and_yield(fragments[1])
    actual_fragments = [ ]
    @aggregator.each_fragment_for(subpath) { |f| actual_fragments << f }
    actual_fragments.should == fragments
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  it "should call through to the fragment set on #max_mtime_for" do
    mtime = Time.now.to_i - 123456
    @test_fragment_set.should_receive(:max_mtime_for).once.with('foo/bar').and_return(mtime)
    @aggregator.max_mtime_for('foo/bar').should == mtime
  end
  
  it "should return a nil mtime if that's what the fragment set returns" do
    @test_fragment_set.should_receive(:max_mtime_for).once.with('foo/bar').and_return(nil)
    @aggregator.max_mtime_for('foo/bar').should be_nil
  end
  
  it "should pass its #fragment_sorting_proc through on #each_fragment_for" do
    subpath = 'foo/bar'
    sorting_proc = mock(:sorting_proc)
    @aggregator.should_receive(:fragment_sorting_proc).once.with(subpath).and_return(sorting_proc)
    
    fragments = [ mock(:fragment1), mock(:fragment2) ]
    @test_fragment_set.should_receive(:each_fragment_for).once.with(subpath, sorting_proc).and_yield(fragments[0]).and_yield(fragments[1])
    actual_fragments = [ ]
    @aggregator.each_fragment_for(subpath) { |f| actual_fragments << f }
    actual_fragments.should == fragments
    @aggregator.refresh_fragments_since_calls.should == [ nil ]
  end
  
  describe "#default_subpath_definition" do
    it "should return subdirectories under Rails.root correctly" do
      @aggregator.send(:default_subpath_definition, File.join(Rails.root, "app", "foo", "bar", "baz", "quux.html.erb"), "whatever").should == 'bar'
      @aggregator.send(:default_subpath_definition, File.join(Rails.root, "app", "foo.html.erb"), "whatever").should == 'foo'
      @aggregator.send(:default_subpath_definition, File.join(Rails.root, "bonk.html.erb"), "whatever").should == 'bonk'
    end

    it "should return other files correctly" do
      @aggregator.send(:default_subpath_definition, "/foo/bar/baz.x.y.z", "whatever").should == 'baz'
      @aggregator.send(:default_subpath_definition, "foo/bar/baz.x.y.z", "whatever").should == 'baz'
    end
  end
  
  context "when looking at tagged subpaths" do
    before :each do
      @subpaths = %w{foo/bar bar/baz}
    end
    
    def check(content)
      @aggregator.send(:update_with_tagged_subpaths, "a/b", content, @subpaths)
    end
    
    it "should not change subpaths if nothing is specified" do
      check("hi ho ho").should == %w{bar/baz foo/bar}
    end
    
    it "should add subpaths if requested" do
      check("hi ho ho\n foo ASSET TARGET add foo/bar bonk/baz  \nmonkeyshines").should == %w{bar/baz bonk/baz foo/bar}
    end
    
    it "should remove subpaths if requested" do
      check("hi ho ho\n foo ASSET TARGET: remove bonk/baz foo/bar  \nmonkeyshines").should == %w{bar/baz}
    end
    
    it "should set subpaths if requested" do
      check("hi ho ho\n foo ASSET TARGET : exactly a/b foo/bar a/y  \nmonkeyshines").should == %w{a/b a/y foo/bar}
    end
    
    it "should set subpaths by default" do
      check("hi ho ho\n foo ASSET TARGET : a/b foo/bar a/y  \nmonkeyshines").should == %w{a/b a/y foo/bar}
    end
  end
end
