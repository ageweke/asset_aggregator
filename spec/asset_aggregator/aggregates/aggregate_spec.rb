require 'spec/spec_helper'

describe AssetAggregator::Aggregates::Aggregate do
  class TestAggregator
    attr_reader :refresh_calls, :creation_args
    
    def initialize(*args)
      @refresh_calls = 0
      @creation_args = args
    end
    
    def refresh!
      @refresh_calls += 1
    end
  end
  
  class TestFilter
    attr_reader :val1, :val2
    
    def initialize(val1 = nil, val2 = nil)
      @val1 = val1
      @val2 = val2
    end
    
    def filter
    end
  end
  
  def get_aggregators(aggregate)
    aggregate.instance_variable_get(:@aggregators)
  end
  
  before :each do
    @type = mock(:aggregate_type)
    @file_cache = mock(:file_cache)
  end
  
  def make_new(subpath, &definition_proc)
    AssetAggregator::Aggregates::Aggregate.new(@type, @file_cache, subpath, definition_proc)
  end
  
  def check_creation_args(test_aggregator, subpath, filters, *args)
    ca = test_aggregator.creation_args
    ca[0].class.should == AssetAggregator::Fragments::FragmentSet
    ca[1].should == @file_cache
    ca[2].should == filters
    ca[3].should == subpath
    ca[4..-1].should == args
  end
  
  it "should add the aggregators specified by the definition proc" do
    aggregate = make_new('foo/bar') do
      add TestAggregator, :baz, :quux
      add TestAggregator, :aaa, :bbb
    end
    
    aggregate.subpath.should == 'foo/bar'
    aggregators = get_aggregators(aggregate)
    aggregators.length.should == 2
    aggregators.each { |a| a.class.should == TestAggregator }
    
    check_creation_args(aggregators[0], 'foo/bar', [ ], :baz, :quux)
    check_creation_args(aggregators[1], 'foo/bar', [ ], :aaa, :bbb)
  end
  
  it "should add filters to aggregators, in the right order, if requested" do
    filter1 = TestFilter.new
    filter2 = TestFilter.new
    filter3 = TestFilter.new
    
    aggregate = make_new('foo/bar') do
      filter_with filter1 do
        filter_with filter2 do
          filter_with filter3 do
            add TestAggregator, :baz, :quux
            add TestAggregator, :aaa, :bbb
          end
          add TestAggregator, :ccc
        end
        add TestAggregator, :ddd
      end
      add TestAggregator, :eee
    end
    
    aggregate.subpath.should == 'foo/bar'
    aggregators = get_aggregators(aggregate)
    aggregators.length.should == 5
    aggregators.each { |a| a.class.should == TestAggregator }
    
    check_creation_args(aggregators[0], 'foo/bar', [ filter3, filter2, filter1 ], :baz, :quux)
    check_creation_args(aggregators[1], 'foo/bar', [ filter3, filter2, filter1 ], :aaa, :bbb)
    check_creation_args(aggregators[2], 'foo/bar', [ filter2, filter1 ], :ccc)
    check_creation_args(aggregators[3], 'foo/bar', [ filter1 ], :ddd)
    check_creation_args(aggregators[4], 'foo/bar', [ ], :eee)
  end
  
  it "should allow passing a Class in as a filter, with arguments" do
    aggregate = make_new("foo/bar") do
      filter_with TestFilter, :aaa, :bbb do
        filter_with TestFilter, :ccc, :ddd do
          add TestAggregator, :foo, :bar
        end
      end
    end
    
    aggregators = get_aggregators(aggregate)
    aggregators.length.should == 1
    
    filters = aggregators[0].creation_args[2]
    filters.length.should == 2
    filters.each { |f| f.class.should == TestFilter }
    
    filters[0].val1.should == :ccc
    filters[0].val2.should == :ddd

    filters[1].val1.should == :aaa
    filters[1].val2.should == :bbb
  end
  
  it "should call refresh! on all its Aggregators when its own #refresh is called" do
    aggregate = make_new("foo/bar") do
      add TestAggregator, :one
      add TestAggregator, :two
      add TestAggregator, :three
    end
    
    aggregators = get_aggregators(aggregate)
    aggregators.length.should == 3
    
    aggregators.each { |a| a.refresh_calls.should == 0 }
    
    aggregate.refresh!
    aggregators.each { |a| a.refresh_calls.should == 1 }
    
    aggregate.refresh!
    aggregators.each { |a| a.refresh_calls.should == 2 }
  end
  
  it "should call through to #content_for on the AggregateType when its own #content is called" do
    aggregate = make_new("foo/bar") do
      add TestAggregator, :one
      add TestAggregator, :two
      add TestAggregator, :three
    end
    
    aggregators = get_aggregators(aggregate)
    
    @type.should_receive(:content_for).with(aggregate, aggregators).and_return("yo ho ho")
    aggregate.content.should == "yo ho ho"
  end
end
