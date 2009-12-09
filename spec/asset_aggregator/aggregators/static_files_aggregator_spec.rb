require 'spec/spec_helper'

def with_temporary_directory
  require 'tempfile'
  require 'fileutils'
  
  tempfile = Tempfile.new(File.basename(__FILE__))
  tempfile_path = tempfile.path
  tempfile.close!
  File.delete(tempfile_path) if File.exist?(tempfile_path)
  begin
    FileUtils.mkdir_p(tempfile_path)
    yield tempfile_path
  ensure
    FileUtils.rm_rf(tempfile_path) if File.exist?(tempfile_path)
  end
end

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
    with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      
      aggregator = create(sub(tempdir, 'foo'))
      fragments = [ ]
      aggregator.each_fragment { |f| fragments << f }
      fragments.length.should == 1
      fragments[0].source_position.file.should == sub(tempdir, 'foo')
      fragments[0].source_position.line.should be_nil
    end
  end
end
