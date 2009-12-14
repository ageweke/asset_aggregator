require 'spec/spec_helper'

# In an attempt to avoid being fragile, this does NOT test every last byte of
# output from the #CssOutputHandler. Rather, it uses regular expressions
# to make sure that certain key properties are satisfied.
describe AssetAggregator::OutputHandlers::CssOutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @output_handler = AssetAggregator::OutputHandlers::CssOutputHandler.new(@aggregate_type, @subpath)
    
    @aggregators = [ ]
    
    @output_handler.start_all
  end
  
  def add(aggregator, fragments)
    @output_handler.separate_aggregators(@aggregators[-1], aggregator) unless @aggregators.empty?
    @aggregators << aggregator
    @output_handler.start_aggregator(aggregator)
    fragments.each_with_index do |fragment, index|
      @output_handler.separate_fragments(aggregator, fragments[index - 1], fragment) unless index == 0
      @output_handler.start_fragment(aggregator, fragment)
      @output_handler.fragment_content(aggregator, fragment, fragment.content)
      @output_handler.end_fragment(aggregator, fragment)
    end
    @output_handler.end_aggregator(aggregator)
  end
  
  def text
    @output_handler.end_all
    @output_handler.text
  end
  
  def normalized_text
    text.gsub(/\s+/, ' ')
  end
  
  it "should put headers overall, per-aggregator, and per-fragment" do
    aggregators = [ mock(:aggregator1, :to_s => 'aggregator1yo'), mock(:aggregator2, :to_s => 'aggregator2yo') ]
    add(aggregators[0], [ mock(:fragment1, :content => 'yo ho ho', :source_position => 'sp1'), mock(:fragment2, :content => 'and a bottle of rum', :source_position => 'sp2') ])
    add(aggregators[1], [ mock(:fragment3, :content => 'a pirate\'s life for me', :source_position => 'sp3') ])
    
    normalized_text.should match(%r{foo/bar.css.*aggregator1yo.*sp1.*yo ho ho.*sp2.*and a bottle of rum.*aggregator2yo.*sp3.*a pirate's life for me})
  end
end
