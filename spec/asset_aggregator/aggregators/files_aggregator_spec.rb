require 'spec/spec_helper'

describe AssetAggregator::Aggregators::FilesAggregator do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @test_fragment_set = mock(:fragment_set)
    
    @root = File.join(Rails.root, 'app', 'views')
    @files_aggregator = make(@root)
  end
  
  def make(root, include_proc = nil, &subpath_definition_proc)
    out = AssetAggregator::Aggregators::FilesAggregator.new(@aggregate_type, @file_cache, @filters, root, include_proc, &subpath_definition_proc)
    out.instance_variable_set(:@fragment_set, @test_fragment_set)
    out
  end
  
  it "should return a single file's fragment" do
    path = File.join(@root, 'foo', 'bar.css')
    @file_cache.should_receive(:changed_files_since).with(@root, nil).and_yield(path)
    
  end
end
