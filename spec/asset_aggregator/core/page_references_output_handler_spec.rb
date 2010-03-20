require 'spec/spec_helper'

describe AssetAggregator::Core::PageReferencesOutputHandler do
  def prepare(verbose)
    @integration = mock(:integration, :include_dependency_tag_comments? => verbose, :include_fragment_dependencies_instead_of_aggregates? => false)
    class << @integration
      def html_escape(s)
        s
      end
    end
    
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
  end
  
  def make(options = { })
    @output_handler = AssetAggregator::Core::PageReferencesOutputHandler.new(@asset_aggregator, options)
  end
  
  def prep_fragment(num)
    sp = mock("source_position_#{num}".to_sym, :file => "sp#{num}file", :line => "100#{num}".to_i)
    ref = mock("ref#{num}".to_sym, :to_s => "ref#{num}string", :source_position => sp)
    f = mock("fragment#{num}".to_sym, :source_position => sp)
    
    ref.should_receive(:fragment_source_position).any_number_of_times.and_return(sp)
    @asset_aggregator.should_receive(:fragment_for).once.with(:javascript, sp).and_return(f)
    @integration.should_receive(:base_relative_path).once.with("sp#{num}file").and_return("sp#{num}filerel.js")
    @asset_aggregator.should_receive(:fragment_url).once.with(:javascript, sp).and_return("f#{num}url")
    @asset_aggregator.should_receive(:fragment_mtime_for).once.with(:javascript, sp).and_return("12345#{num}".to_i)
    @integration.should_receive(:javascript_include_tag).once.with("f#{num}url?12345#{num}").and_return("jsincludetag#{num}yo")
    
    ref
  end
  
  describe "when verbose" do
    before :each do
      prepare(true)
    end
    
    it "should output a brief comment on #start_all" do
      make
      @output_handler.start_all
      @output_handler.text.should match(/begin.*includes/i)
    end
    
    it "should output an explanatory comment on #start_all when :include_fragment_dependencies_instead_of_aggregates is set" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)
      @output_handler.start_all
      @output_handler.text.should match(/direct fragment references/mi)
      @output_handler.text.should match(/begin AssetAggregator includes/i)
    end
    
    it "should output a brief comment on #start_aggregate_type" do
      make
      @output_handler.start_aggregate_type(:javascript, [ [ 'foo', [ mock(:one), mock(:two) ] ] ])
      @output_handler.text.should match(/begin javascript includes/i)
    end
    
    it "should output a long hack comment on #start_aggregate_type for CSS with too many tags" do
      make
      array = (0..35).map { |x| [ "path#{x}", [ mock("ref#{x}".to_sym) ] ] }
      @output_handler.start_aggregate_type(:css, array)
      @output_handler.text.should match(/hack.*@import/mi)
      @output_handler.text.should match(/style media="all" type="text\/css".*<!--/mi)
    end
    
    it "should output a long hack comment on #start_aggregate_type for CSS with too many tags, when it's only too many because of fragment output" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)
      refs1 = (0..20).map { |x| mock("ref#{x}".to_sym) }
      refs2 = (21..40).map { |x| mock("ref#{x}".to_sym) }
      
      @output_handler.start_aggregate_type(:css, [ [ "foo", refs1 ], [ "bar", refs2 ] ])
      @output_handler.text.should match(/hack.*@import/mi)
      @output_handler.text.should match(/style media="all" type="text\/css".*<!--/mi)
    end
    
    it "should output aggregate tags on #aggregate" do
      make
      refs = [ mock(:ref1, :to_s => 'ref1string'), mock(:ref2, :to_s => 'ref2string') ]
      
      @asset_aggregator.should_receive(:aggregate_url).once.with(:javascript, 'foobar').and_return("AGGURL")
      @asset_aggregator.should_receive(:mtime_for).once.with(:javascript, 'foobar').and_return(1234567)
      @integration.should_receive(:javascript_include_tag).once.with("AGGURL?1234567").and_return("jsincludetagyo")
      @output_handler.aggregate(:javascript, 'foobar', refs)
      @output_handler.text.should match(/<!--.*Aggregate.*foobar.*ref1string.*ref2string/mi)
      @output_handler.text.should match(/jsincludetagyo/mi)
    end

    it "should output fragment tags on #aggregate when requested" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)

      refs = [ prep_fragment(1), prep_fragment(2) ]
      
      @output_handler.aggregate(:javascript, 'foobar', refs)
      @output_handler.text.should match(/ref1string.*jsincludetag1yo/mi)
      @output_handler.text.should match(/ref2string.*jsincludetag2yo/mi)
    end
    
    it "should output @import tags for stylesheets when there are too many of them"
    it "should generate URLs with line numbers to direct fragments, when they have line numbers"
    it "should cache-bust URLs that already have query strings correctly"
    it "should fall back to including aggregates when there's a direct aggregate reference present"
    it "should close the style tag in #end_aggregate_type when importing CSS stylesheets instead of linking them"
    it "should add a comment on #end_all"
  end
  
  describe "when not verbose" do
    before :each do
      prepare(false)
    end
    
    it "should output nothing on #start_all" do
      make
      @output_handler.start_all
      @output_handler.text.length.should == 0
    end
    
    it "should output nothing on #start_aggregate_type" do
      make
      @output_handler.start_aggregate_type(:javascript, [ [ 'foo', [ mock(:one), mock(:two) ] ] ])
      @output_handler.text.length.should == 0
    end
    
    it "should output nothing on #start_aggregate_type when :include_fragment_dependencies_instead_of_aggregates is set" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)
      @output_handler.start_aggregate_type(:javascript, [ [ 'foo', [ mock(:one), mock(:two) ] ] ])
      @output_handler.text.length.should == 0
    end
    
    it "should output a CSS start tag on #start_aggregate_type for CSS with too many tags" do
      make
      array = (0..35).map { |x| [ "path#{x}", [ mock("ref#{x}".to_sym) ] ] }
      @output_handler.start_aggregate_type(:css, array)
      @output_handler.text.should_not match(/hack.*@import/mi)
      @output_handler.text.should match(/style media="all" type="text\/css".*<!--/mi)
    end
    
    it "should output a CSS start tag on #start_aggregate_type for CSS with too many tags, when it's only too many because of fragment output" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)
      refs1 = (0..20).map { |x| mock("ref#{x}".to_sym) }
      refs2 = (21..40).map { |x| mock("ref#{x}".to_sym) }
      
      @output_handler.start_aggregate_type(:css, [ [ "foo", refs1 ], [ "bar", refs2 ] ])
      @output_handler.text.should match(/style media="all" type="text\/css".*<!--/mi)
    end
    
    it "should output aggregate tags on #aggregate" do
      make
      refs = [ mock(:ref1, :to_s => 'ref1string'), mock(:ref2, :to_s => 'ref2string') ]
      @asset_aggregator.should_receive(:aggregate_url).once.with(:javascript, 'foobar').and_return("AGGURL")
      @asset_aggregator.should_receive(:mtime_for).once.with(:javascript, 'foobar').and_return(1234567)
      @integration.should_receive(:javascript_include_tag).once.with("AGGURL?1234567").and_return("jsincludetagyo")
      @output_handler.aggregate(:javascript, 'foobar', refs)
      @output_handler.text.should_not match(/<!--.*Aggregate.*foobar.*ref1string.*ref2string/mi)
      @output_handler.text.should match(/jsincludetagyo/mi)
    end
    
    it "should output fragment tags on #aggregate when requested" do
      make(:include_fragment_dependencies_instead_of_aggregates => true)

      refs = [ prep_fragment(1), prep_fragment(2) ]
      
      @output_handler.aggregate(:javascript, 'foobar', refs)
      @output_handler.text.should match(/jsincludetag1yo/mi)
      @output_handler.text.should match(/jsincludetag2yo/mi)
      @output_handler.text.should_not match(/ref1string/mi)
      @output_handler.text.should_not match(/ref2string/mi)
    end
  end
end