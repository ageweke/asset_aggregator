require 'spec/spec_helper'

describe AssetAggregator::Core::OutputHandler do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @subpath = "foo/bar"
    @options = mock(:options)
    
    @output_handler = AssetAggregator::Core::OutputHandler.new(@aggregate_type, @subpath, @options)
  end
  
  it "should return components correctly" do
    @output_handler.send(:aggregate_type).should == @aggregate_type
    @output_handler.send(:subpath).should == @subpath
    @output_handler.send(:options).should == @options
  end
  
  it "should return all #output calls on #text" do
    @output_handler.send(:output, "foo")
    @output_handler.send(:output, "bar\nbaz\n")
    @output_handler.send(:output, "quux")
    
    @output_handler.text.should == "foo\nbar\nbaz\nquux\n"
  end
  
  it "should separate fragments by two newlines by default" do
    @output_handler.send(:output, "foo")
    @output_handler.separate_fragments(mock(:aggregator), mock(:fragment1), mock(:fragment2))
    @output_handler.send(:output, "bar")
    @output_handler.text.should == "foo\n\n\nbar\n"
  end
  
  it "should separate aggregators by two newlines by default" do
    @output_handler.send(:output, "foo")
    @output_handler.separate_aggregators(mock(:aggregator1), mock(:aggregator2))
    @output_handler.send(:output, "bar")
    @output_handler.text.should == "foo\n\n\nbar\n"
  end
  
  it "should output fragment content verbatim, by default" do
    fragment = mock(:fragment)
    @output_handler.send(:output, "aaa")
    @output_handler.fragment_content(mock(:aggregator), fragment, "foo bar\nbaz\nquux")
    @output_handler.send(:output, "bbb")
    @output_handler.text.should == "aaa\nfoo bar\nbaz\nquux\nbbb\n"
  end
  
  [ :start_all, :start_aggregator, :start_fragment, :end_fragment, :end_aggregator, :end_all ].each do |method_name|
    it "should do nothing in ##{method_name}" do
      meth = @output_handler.method(method_name)
      arity = meth.arity
      args = (1..arity).map { |n| mock("arg#{n}".to_sym) }
      @output_handler.send(method_name, *args)
      @output_handler.text.should == ""
    end
  end
end
