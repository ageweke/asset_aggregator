require 'spec/spec_helper'

# In an attempt to avoid being fragile, this does NOT test every last byte of
# output from the #CommonOutputHandler. Rather, it uses regular expressions
# to make sure that certain key properties are satisfied.
describe AssetAggregator::OutputHandlers::CommonOutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @aggregators = [ ]
  end
  
  def make(options)
    out = AssetAggregator::OutputHandlers::CommonOutputHandler.new(@aggregate_type, @subpath, options)
    class << out
      def extension
        "xyz"
      end
    end
    
    out.start_all
    out
  end
  
  def add(output_handler, aggregator, fragments)
    output_handler.separate_aggregators(@aggregators[-1], aggregator) unless @aggregators.empty?
    @aggregators << aggregator
    output_handler.start_aggregator(aggregator)
    fragments.each_with_index do |fragment, index|
      output_handler.separate_fragments(aggregator, fragments[index - 1], fragment) unless index == 0
      output_handler.start_fragment(aggregator, fragment)
      output_handler.fragment_content(aggregator, fragment, fragment.content)
      output_handler.end_fragment(aggregator, fragment)
    end
    output_handler.end_aggregator(aggregator)
  end
  
  def text(output_handler)
    output_handler.end_all
    output_handler.text
  end
  
  def normalized_text(output_handler)
    text(output_handler).gsub(/\s+/, ' ')
  end
  
  it "should put headers overall, per-aggregator, and per-fragment, when requested" do
    output_handler = make(:header_comment => :full, :aggregator_comment => :full, :fragment_comment => :full)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    add(output_handler, aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'sp1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'sp2') ])
    add(output_handler, aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'sp3') ])
    
    normalized_text(output_handler).should match(%r{foo/bar.xyz.*aggregator1yo.*sp1.*yo ho ho.*sp2.*and a bottle of rum.*aggregator2yo.*sp3.*a pirate's life for me})
  end
  
  it "should include brief headers overall, per-aggregator, and per-fragment, when requested" do
    output_handler = make(:header_comment => :brief, :aggregator_comment => :brief, :fragment_comment => :brief)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    add(output_handler, aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'sp1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'sp2') ])
    add(output_handler, aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'sp3') ])
    
    normalized_text(output_handler).should match(%r{foo/bar.xyz.*aggregator1yo.*sp1.*yo ho ho.*sp2.*and a bottle of rum.*aggregator2yo.*sp3.*a pirate's life for me})
  end
  
  it "should omit headers, when requested" do
    output_handler = make(:header_comment => :none, :aggregator_comment => :none, :fragment_comment => :none)
    
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    add(output_handler, aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'sp1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'sp2') ])
    add(output_handler, aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'sp3') ])
    
    normalized = normalized_text(output_handler)
    [ %r{foo/bar.xyz}, %r{aggregator1yo}, %r{aggregator2yo}, %r{sp1}, %r{sp2}, %r{sp3} ].each do |bad_regex|
      normalized.should_not match(bad_regex)
    end
  end
end
