require 'spec/spec_helper'

def pop_file(dir, subpath, text)
  net_file = sub(dir, subpath)
  FileUtils.mkdir_p(File.dirname(net_file))
  File.open(net_file, 'w') { |f| f.puts text }
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
  
  def create(include_proc, *files)
    AssetAggregator::Aggregators::StaticFilesAggregator.new(@fragment_set, @file_cache, @filters, @subpath, include_proc, *files)
  end
  
  def check_fragments(aggregator, *specs)
    fragments = [ ]
    aggregator.each_fragment { |f| fragments << f }
    
    fragments.length.should == specs.length
    fragments.each_with_index do |fragment, index|
      spec = specs[index]
      fragment.source_position.file.should == spec[:file]
      fragment.source_position.line.should == spec[:line]
      fragment.content.strip.should == spec[:content]
    end
  end
  
  it "should return a single file's fragment" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      
      aggregator = create(nil, sub(tempdir, 'foo'))
      check_fragments(aggregator, { :file => sub(tempdir, 'foo'), :content => 'test 1' })
    end
  end
  
  it "should return fragments for multiple files" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      pop_file(tempdir, 'bar', 'test 2')
      
      aggregator = create(nil, sub(tempdir, 'foo'), sub(tempdir, 'bar'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'bar'), :content => 'test 2' },
        { :file => sub(tempdir, 'foo'), :content => 'test 1' }
      )
    end
  end
  
  it "should return a directory full of files" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo/bar', 'test 1')
      pop_file(tempdir, 'foo/baz', 'test 2')
      
      aggregator = create(nil, sub(tempdir, 'foo'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'foo/bar'), :content => 'test 1' },
        { :file => sub(tempdir, 'foo/baz'), :content => 'test 2' }
      )
    end
  end
  
  it "should re-read files if their mtime has changed" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo', 'test 1')
      pop_file(tempdir, 'bar', 'test 2')
      
      aggregator = create(nil, sub(tempdir, 'foo'), sub(tempdir, 'bar'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'bar'), :content => 'test 2' },
        { :file => sub(tempdir, 'foo'), :content => 'test 1' }
      )
      
      sleep 1.1
      pop_file(tempdir, 'foo', 'test 3')
      @file_cache.refresh!
      aggregator.refresh!
      check_fragments(aggregator,
        { :file => sub(tempdir, 'bar'), :content => 'test 2' },
        { :file => sub(tempdir, 'foo'), :content => 'test 3' }
      )
    end
  end
  
  it "should only include files with the specified extension" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo.js', 'test 1')
      pop_file(tempdir, 'bar.txt', 'test 2')
      
      aggregator = create('js', sub(tempdir, 'foo.js'), sub(tempdir, 'bar.txt'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'foo.js'), :content => 'test 1' }
      )
    end
  end
  
  it "should only include files with the specified extension, in a directory" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo/one.js', 'test 1')
      pop_file(tempdir, 'foo/two.txt', 'test 2')
      
      aggregator = create('js', sub(tempdir, 'foo'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'foo/one.js'), :content => 'test 1' }
      )
    end
  end
  
  it "should only include files with one of the specified extensions" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo/one.js', 'test 1')
      pop_file(tempdir, 'foo/two.txt', 'test 2')
      pop_file(tempdir, 'foo/three.css', 'test 3')
      
      aggregator = create(%w{js css}, sub(tempdir, 'foo'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'foo/one.js'), :content => 'test 1' },
        { :file => sub(tempdir, 'foo/three.css'), :content => 'test 3' }
      )
    end
  end
  
  it "should only include files that match the specified include_proc" do
    File.with_temporary_directory do |tempdir|
      pop_file(tempdir, 'foo/one_include_one.js', 'test 1')
      pop_file(tempdir, 'foo/two_dont_two.js', 'test 2')
      pop_file(tempdir, 'foo/three_include_three.js', 'test 3')
      
      aggregator = create(Proc.new { |f| f =~ /_include_/}, sub(tempdir, 'foo'))
      check_fragments(aggregator,
        { :file => sub(tempdir, 'foo/one_include_one.js'), :content => 'test 1' },
        { :file => sub(tempdir, 'foo/three_include_three.js'), :content => 'test 3' }
      )
    end
  end
end
