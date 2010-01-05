require 'spec/spec_helper'

describe AssetAggregator::Core::AggregateType do
  class TestAggregatorClass
    attr_reader :aggregate_type, :file_cache, :filters, :name, :extra, :block
    
    def initialize(aggregate_type, file_cache, filters, name, extra = nil, &block)
      @aggregate_type = aggregate_type
      @file_cache = file_cache
      @filters = filters
      @name = name
      @extra = extra
      @block = block
    end
    
    def filtered_content_from(fragment)
      fragment.filtered_content
    end
  end
  
  before :each do
    @type = 'foobar'
    @file_cache = mock(:file_cache)
    @output_handler_creator = mock(:output_handler_creator)
    
    definition_proc = Proc.new do
      add TestAggregatorClass, :foo
      add TestAggregatorClass, :bar, :baz
    end
    
    @aggregate_type = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_creator, definition_proc)
  end
  
  it "should return its components correctly" do
    @aggregate_type.type.should == @type
  end
  
  it "should add the right aggregators" do
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators.length.should == 2
    
    aggregators.each do |a|
      a.class.should == TestAggregatorClass
      a.aggregate_type.should == @aggregate_type
      a.file_cache.should == @file_cache
      a.filters.should == [ ]
    end
    
    aggregators[0].name.should == :foo
    aggregators[0].extra.should be_nil
    aggregators[1].name.should == :bar
    aggregators[1].extra.should == :baz
  end
  
  def filters_from(aggregator)
    aggregator.instance_variable_get(:@fragment_set).instance_variable_get(:@filters)
  end
  
  it "should pass blocks through to aggregators" do
    proc_1 = Proc.new { |f| 'ha' }
    proc_2 = Proc.new { |f| 'yo' }
    
    definition_proc = Proc.new do
      add(TestAggregatorClass, :foo, &proc_1)
      add(TestAggregatorClass, :bar, :baz, &proc_2)
    end
    
    @aggregate_type = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_creator, definition_proc)
    
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators.length.should == 2
    
    aggregators[0].block.should == proc_1
    aggregators[1].block.should == proc_2
  end
  
  it "should add predefined aggregators" do
    definition_proc = Proc.new do
      add :files, 'bonk'
    end
    type_with_predefined = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_creator, definition_proc)
    
    aggregators = type_with_predefined.instance_variable_get(:@aggregators)
    aggregators.length.should == 1
    
    aggregator = aggregators[0]
    aggregator.instance_variable_get(:@file_cache).should == @file_cache
    filters_from(aggregator).should == [ ]
    aggregator.instance_variable_get(:@aggregate_type).should == type_with_predefined
  end
  
  it "should add filters on #filter_if, but only if requested" do
    filter1 = mock(:filter1, :filter => nil)
    filter2 = mock(:filter2, :filter => nil)
    
    definition_proc = Proc.new do
      filter_with_if true, filter1 do
        filter_with_if false, filter2 do
          add TestAggregatorClass, :foo
        end
      end
    end
    
    type_with_filters = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_creator, definition_proc)
    aggregators = type_with_filters.instance_variable_get(:@aggregators)
    aggregators.length.should == 1
    
    aggregators[0].name.should == :foo
    aggregators[0].filters.should == [ filter1 ]
  end
  
  it "should add filters to its aggregators, in order" do
    filter1 = mock(:filter1, :filter => nil)
    filter2 = mock(:filter2, :filter => nil)
    
    definition_proc = Proc.new do
      add TestAggregatorClass, :foo
      filter_with filter1 do
        add TestAggregatorClass, :bar
        filter_with filter2 do
          add TestAggregatorClass, :baz
        end
        add TestAggregatorClass, :quux
      end
      add TestAggregatorClass, :marph
    end
    
    type_with_filters = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_creator, definition_proc)
    aggregators = type_with_filters.instance_variable_get(:@aggregators)
    aggregators.length.should == 5
    
    aggregators[0].name.should == :foo
    aggregators[0].filters.should == [ ]
    aggregators[1].name.should == :bar
    aggregators[1].filters.should == [ filter1 ]
    aggregators[2].name.should == :baz
    aggregators[2].filters.should == [ filter2, filter1 ]
    aggregators[3].name.should == :quux
    aggregators[3].filters.should == [ filter1 ]
    aggregators[4].name.should == :marph
    aggregators[4].filters.should == [ ]
  end
  
  it "should call through to its aggregators on #refresh!" do
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators.each { |a| a.should_receive(:refresh!).once }
    @aggregate_type.refresh!
    aggregators.each { |a| a.should_receive(:refresh!).once }
    @aggregate_type.refresh!
  end
  
  it "should get the set of all subpaths on #all_subpaths" do
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators[0].should_receive(:all_subpaths).once.and_return(%w{foo bar foo foo})
    aggregators[1].should_receive(:all_subpaths).once.and_return(%w{bar baz baz bonk})
    @aggregate_type.all_subpaths.should == %w{bar baz bonk foo}
  end
  
  it "should return a matching fragment with #fragment_for" do
    source_position = mock(:source_position)
    fragment = mock(:fragment)
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators[0].should_receive(:fragment_for).once.with(source_position).and_return(nil)
    aggregators[1].should_receive(:fragment_for).once.with(source_position).and_return(fragment)
    @aggregate_type.fragment_for(source_position).should == fragment
  end
  
  it "should return the first matching fragment with #fragment_for" do
    source_position = mock(:source_position)
    fragment = mock(:fragment)
    fragment2 = mock(:fragment2)
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators[0].should_receive(:fragment_for).once.with(source_position).and_return(fragment)
    @aggregate_type.fragment_for(source_position).should == fragment
  end
  
  context "when calculating #mtime_for" do
    it "should return the max" do
      mtime = Time.now.to_i
    
      aggregators = @aggregate_type.instance_variable_get(:@aggregators)
      aggregators[0].should_receive(:max_mtime_for).once.with('foo/bar').and_return(mtime + 1000)
      aggregators[1].should_receive(:max_mtime_for).once.with('foo/bar').and_return(mtime)
      @aggregate_type.max_mtime_for('foo/bar').should == mtime + 1000
    end
    
    it "should skip aggregators that have no mtime for the given subpath" do
      mtime = Time.now.to_i
    
      aggregators = @aggregate_type.instance_variable_get(:@aggregators)
      aggregators[0].should_receive(:max_mtime_for).once.with('foo/bar').and_return(nil)
      aggregators[1].should_receive(:max_mtime_for).once.with('foo/bar').and_return(mtime - 1000)
      @aggregate_type.max_mtime_for('foo/bar').should == mtime - 1000
    end
    
    it "should return nil if there is no data at all" do
      aggregators = @aggregate_type.instance_variable_get(:@aggregators)
      aggregators[0].should_receive(:max_mtime_for).once.with('foo/bar').and_return(nil)
      aggregators[1].should_receive(:max_mtime_for).once.with('foo/bar').and_return(nil)
      @aggregate_type.max_mtime_for('foo/bar').should be_nil
    end
  end
  
  it "should return the sorted union of aggregators' #aggregated_subpaths_for for its own #aggregated_subpaths_for" do
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)

    source_position = mock(:source_position)
    aggregators[0].should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ "foo/bar", "bar/baz" ])
    aggregators[1].should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ "bar/quux", "bar/baz" ])
    @aggregate_type.aggregated_subpaths_for(source_position).should == [ "bar/baz", "bar/quux", "foo/bar" ]

    aggregators[0].should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ ])
    aggregators[1].should_receive(:aggregated_subpaths_for).once.with(source_position).and_return([ "foo/bar" ])
    @aggregate_type.aggregated_subpaths_for(source_position).should == [ "foo/bar" ]
  end
  
  it "should return no fragment for #fragment_for if none matches" do
    source_position = mock(:source_position)
    fragment = mock(:fragment)
    fragment2 = mock(:fragment2)
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    aggregators[0].should_receive(:fragment_for).once.with(source_position).and_return(nil)
    aggregators[1].should_receive(:fragment_for).once.with(source_position).and_return(nil)
    @aggregate_type.fragment_for(source_position).should be_nil
  end
  
  it "should call the output handler class in the right order" do
    base_mtime = Time.now.to_i - 1000
    fragment1 = mock(:fragment1, :mtime => base_mtime)
    fragment1.should_receive(:filtered_content).and_return("foo")
    fragment2 = mock(:fragment2, :mtime => base_mtime + 100)
    fragment2.should_receive(:filtered_content).and_return("bar")
    fragment3 = mock(:fragment3, :mtime => base_mtime + 200)
    fragment3.should_receive(:filtered_content).and_return("baz")
    
    subpath = 'foo/bar'
    
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    (aggregator1, aggregator2) = aggregators
    
    aggregator1.should_receive(:max_mtime_for).with(subpath).and_return(base_mtime + 300)
    aggregator1.should_receive(:each_fragment_for).with(subpath).and_yield(fragment1).and_yield(fragment2)
    aggregator2.should_receive(:max_mtime_for).with(subpath).and_return(base_mtime + 400)
    aggregator2.should_receive(:each_fragment_for).with(subpath).and_yield(fragment3)
    

    output_handler = mock(:output_handler)
    @output_handler_creator.should_receive(:call).with(@aggregate_type, subpath, base_mtime + 400).and_return(output_handler)
    
    output_handler.should_receive(:start_all).ordered
    
    output_handler.should_receive(:start_aggregator).with(aggregator1).ordered
    output_handler.should_receive(:start_fragment).with(aggregator1, fragment1).ordered
    output_handler.should_receive(:fragment_content).with(aggregator1, fragment1, "foo").ordered
    output_handler.should_receive(:end_fragment).with(aggregator1, fragment1).ordered
    output_handler.should_receive(:separate_fragments).with(aggregator1, fragment1, fragment2).ordered
    output_handler.should_receive(:start_fragment).with(aggregator1, fragment2).ordered
    output_handler.should_receive(:fragment_content).with(aggregator1, fragment2, "bar").ordered
    output_handler.should_receive(:end_fragment).with(aggregator1, fragment2).ordered
    output_handler.should_receive(:end_aggregator).with(aggregator1).ordered

    output_handler.should_receive(:separate_aggregators).with(aggregator1, aggregator2).ordered

    output_handler.should_receive(:start_aggregator).with(aggregator2).ordered
    output_handler.should_receive(:start_fragment).with(aggregator2, fragment3).ordered
    output_handler.should_receive(:fragment_content).with(aggregator2, fragment3, "baz").ordered
    output_handler.should_receive(:end_fragment).with(aggregator2, fragment3).ordered
    output_handler.should_receive(:end_aggregator).with(aggregator2).ordered
    
    output_handler.should_receive(:end_all).ordered
    
    output_handler.should_receive(:text).ordered.and_return("output text")
    
    @aggregate_type.content_for(subpath).should == "output text"
  end
  
  it "should return no output if asked for a subpath with no content" do
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    (aggregator1, aggregator2) = aggregators
    
    subpath = 'bonk/whatever'
    
    output_handler = mock(:output_handler)
    @output_handler_creator.should_receive(:call).with(@aggregate_type, subpath, nil).and_return(output_handler)
    
    output_handler.should_receive(:start_all).ordered
    output_handler.should_receive(:start_aggregator).with(aggregator1).ordered
    output_handler.should_receive(:end_aggregator).with(aggregator1).ordered
    output_handler.should_receive(:separate_aggregators).with(aggregator1, aggregator2).ordered
    output_handler.should_receive(:start_aggregator).with(aggregator2).ordered
    output_handler.should_receive(:end_aggregator).with(aggregator2).ordered
    output_handler.should_receive(:end_all).ordered
    
    aggregator1.should_receive(:max_mtime_for).with(subpath).and_return(nil)
    aggregator1.should_receive(:each_fragment_for).with(subpath)
    aggregator2.should_receive(:max_mtime_for).with(subpath).and_return(nil)
    aggregator2.should_receive(:each_fragment_for).with(subpath)
    
    @aggregate_type.content_for(subpath).should be_nil
  end
  
  it "should call the output handler class in the right order when getting content for a single fragment" do
    source_position = mock(:source_position, :terse_file => 'foo/bar')
    
    fragment = mock(:fragment, :source_position => source_position)
    fragment.should_receive(:filtered_content).and_return("foo")
    
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    (aggregator1, aggregator2) = aggregators
    
    aggregator1.should_receive(:fragment_for).once.with(source_position).and_return(fragment)

    output_handler = mock(:output_handler)
    @output_handler_creator.should_receive(:call).with(@aggregate_type, source_position.terse_file).and_return(output_handler)
    
    output_handler.should_receive(:start_all).ordered
    
    output_handler.should_receive(:start_aggregator).with(aggregator1).ordered
    output_handler.should_receive(:start_fragment).with(aggregator1, fragment).ordered
    output_handler.should_receive(:fragment_content).with(aggregator1, fragment, "foo").ordered
    output_handler.should_receive(:end_fragment).with(aggregator1, fragment).ordered
    output_handler.should_receive(:end_aggregator).with(aggregator1).ordered
    output_handler.should_receive(:end_all).ordered
    
    output_handler.should_receive(:text).ordered.and_return("output text")
    
    @aggregate_type.fragment_content_for(source_position).should == "output text"
  end
  
  it "should return no output if #fragment_content_for is called with a SourcePosition that's not found" do
    source_position = mock(:source_position, :terse_file => 'foo/bar')
    
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    (aggregator1, aggregator2) = aggregators
    
    aggregator1.should_receive(:fragment_for).once.with(source_position).and_return(nil)
    aggregator2.should_receive(:fragment_for).once.with(source_position).and_return(nil)

    @aggregate_type.fragment_content_for(source_position).should be_nil
  end
end
