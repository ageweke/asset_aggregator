require 'spec/spec_helper'

def pop_file(dir, subpath, text)
  File.open(sub(dir, subpath), 'w') { |f| f.puts text }
end

def sub(dir, *subpath)
  File.canonical_path(File.join(dir, *subpath))
end

describe AssetAggregator::Aggregators::StaticFilesAggregator do
  before :each do
    @fragment_set = AssetAggregator::Fragments::FragmentSet.new
    @file_cache = AssetAggregator::Files::FileCache.new
    @filters = [ ]
    @subpath = 'foo/bar'
  end
  
  def create(*files)
    AssetAggregator::Aggregators::StaticFilesAggregator.new(@fragment_set, @file_cache, @filters, @subpath, *files)
  end
  
  it "should return a single file's fragment" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      
      aggregator = create(sub(tempdir, 'foo'))
      fragments = [ ]
      aggregator.each_fragment { |f| fragments << f }
      fragments.length.should == 1
      fragments[0].source_position.file.should == sub(tempdir, 'foo')
      fragments[0].source_position.line.should be_nil
      fragments[0].content.strip.should == 'test 1'
    end
  end
  
  it "should return fragments for multiple files" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      pop_file(tempdir, 'bar', 'test 2')
      
      aggregator = create(sub(tempdir, 'foo'))
      fragments = [ ]
      aggregator.each_fragment { |f| fragments << f }
      fragments.length.should == 1
      fragments[0].source_position.file.should == sub(tempdir, 'foo')
      fragments[0].source_position.line.should be_nil
    end
  end
end
