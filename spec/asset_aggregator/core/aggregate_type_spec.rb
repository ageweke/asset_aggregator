require 'spec/spec_helper'

describe AssetAggregator::Core::AggregateType do
  class TestAggregatorClass
    attr_reader :aggregate_type, :file_cache, :filters, :name, :extra
    
    def initialize(aggregate_type, file_cache, filters, name, extra = nil)
      @aggregate_type = aggregate_type
      @file_cache = file_cache
      @filters = filters
      @name = name
      @extra = extra
    end
    
    def filtered_content_from(fragment)
      fragment.filtered_content
    end
  end
  
  before :each do
    @type = 'foobar'
    @file_cache = mock(:file_cache)
    @output_handler_class = mock(:output_handler_class)
    
    definition_proc = Proc.new do
      add TestAggregatorClass, :foo
      add TestAggregatorClass, :bar, :baz
    end
    
    @aggregate_type = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_class, definition_proc)
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
  
  it "should add predefined aggregators" do
    definition_proc = Proc.new do
      add :files, 'bonk'
    end
    type_with_predefined = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_class, definition_proc)
    
    aggregators = type_with_predefined.instance_variable_get(:@aggregators)
    aggregators.length.should == 1
    
    aggregator = aggregators[0]
    aggregator.instance_variable_get(:@file_cache).should == @file_cache
    filters_from(aggregator).should == [ ]
    aggregator.instance_variable_get(:@aggregate_type).should == type_with_predefined
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
    
    type_with_filters = AssetAggregator::Core::AggregateType.new(@type, @file_cache, @output_handler_class, definition_proc)
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
  
  it "should call the output handler class in the right order" do
    fragment1 = mock(:fragment1)
    fragment1.should_receive(:filtered_content).and_return("foo")
    fragment2 = mock(:fragment2)
    fragment2.should_receive(:filtered_content).and_return("bar")
    fragment3 = mock(:fragment3)
    fragment3.should_receive(:filtered_content).and_return("baz")
    
    subpath = 'foo/bar'
    
    aggregators = @aggregate_type.instance_variable_get(:@aggregators)
    (aggregator1, aggregator2) = aggregators
    
    aggregator1.should_receive(:each_fragment_for).with(subpath).and_yield(fragment1).and_yield(fragment2)
    aggregator2.should_receive(:each_fragment_for).with(subpath).and_yield(fragment3)
    

    output_handler = mock(:output_handler)
    @output_handler_class.should_receive(:new).and_return(output_handler)
    
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
end
