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
      @output_handler.start_aggregate_type(:javascript, [ 'foo', [ mock(:one), mock(:two) ] ])
      @output_handler.text.should match(/begin javascript includes/i)
    end
    
    it "should output a long hack comment on #start_aggregate_type for CSS with too many tags" do
      make
      array = (0..35).map { |x| [ "path#{x}", [ mock("ref#{x}".to_sym) ] ] }
      @output_handler.start_aggregate_type(:css, array)
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

      sp1 = mock(:source_position_1, :file => 'sp1file', :line => 123)
      sp2 = mock(:source_position_1, :file => 'sp2file', :line => 456)

      refs = [
        mock(:ref1, :to_s => 'ref1string', :source_position => sp1),
        mock(:ref2, :to_s => 'ref2string', :source_position => sp2)
      ]
      
      f1 = mock(:fragment1, :source_position => sp1)
      f2 = mock(:fragment2, :source_position => sp2)
      
      refs[0].should_receive(:fragment_source_position).twice.and_return(sp1)
      @asset_aggregator.should_receive(:fragment_for).once.with(:javascript, sp1).and_return(f1)
      @integration.should_receive(:base_relative_path).once.with('sp1file').and_return('sp1filerel.js')
      @asset_aggregator.should_receive(:fragment_url).once.with(:javascript, sp1).and_return("f1url")
      @asset_aggregator.should_receive(:fragment_mtime_for).once.with(:javascript, sp1).and_return(1234567)
      @integration.should_receive(:javascript_include_tag).once.with("f1url?1234567").and_return("jsincludetag1yo")
      
      @output_handler.aggregate(:javascript, 'foobar', [ refs[0] ])
      @output_handler.text.should match(/ref1string.*jsincludetag1yo/mi)
    end
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
      @output_handler.start_aggregate_type(:javascript, [ 'foo', [ mock(:one), mock(:two) ] ])
      @output_handler.text.length.should == 0
    end
    
    it "should output a CSS start tag on #start_aggregate_type for CSS with too many tags" do
      make
      array = (0..35).map { |x| [ "path#{x}", [ mock("ref#{x}".to_sym) ] ] }
      @output_handler.start_aggregate_type(:css, array)
      @output_handler.text.should_not match(/hack.*@import/mi)
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
  end
end