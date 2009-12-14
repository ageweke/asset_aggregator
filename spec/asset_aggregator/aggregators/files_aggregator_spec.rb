require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'

describe AssetAggregator::Aggregators::FilesAggregator do
  before :each do
    @aggregate_type = mock(:aggregate_type)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @filesystem_impl = AssetAggregator::TestFilesystemImpl.new
    
    @root = File.join(Rails.root, 'app', 'views')
    @files_aggregator = make(@root)
  end
  
  def make(root, include_proc = nil, &subpath_definition_proc)
    out = AssetAggregator::Aggregators::FilesAggregator.new(@aggregate_type, @file_cache, @filters, root, include_proc, &subpath_definition_proc)
    # out.instance_variable_set(:@fragment_set, @test_fragment_set)
    out.filesystem_impl = @filesystem_impl
    out
  end
  
  def fragments_from(aggregator, subpath)
    fragments = [ ]
    aggregator.each_fragment_for(subpath) { |f| fragments << f }
    fragments
  end
  
  def check_fragments(aggregator, subpath, expected_fragments)
    actual_fragments = fragments_from(aggregator, subpath)
    actual_fragments.length.should == expected_fragments.length
    actual_fragments.each_with_index do |actual_fragment, index|
      expected_fragment = expected_fragments[index]
      
      actual_fragment.target_subpath.should == expected_fragment[:target_subpath]
      actual_fragment.source_position.file.should == expected_fragment[:file]
      actual_fragment.source_position.line.should == expected_fragment[:line]
      actual_fragment.content.should == expected_fragment[:content]
    end
  end
  
  it "should return a single file's fragment" do
    path = File.join(@root, 'foo', 'bar.css')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil).and_yield(path)
    @filesystem_impl.set_content(path, 'hidey ho')
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpath => 'foo', :file => path, :line => nil, :content => 'hidey ho' }
    ])
    
    check_fragments(aggregator, 'bar', [ ])
  end
  
  it "should not return dotfiles" do
    path1 = File.join(@root, 'foo', 'bar.css')
    path2 = File.join(@root, 'foo', '.bonk.css')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil).and_yield(path1).and_yield(path2)
    @filesystem_impl.set_content(path1, 'path1 content')
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpath => 'foo', :file => path1, :line => nil, :content => 'path1 content' }
    ])
  end
  
  it "should not return directories" do
    path1 = File.join(@root, 'foo', 'bar.css')
    path2 = File.join(@root, 'foo')
    path3 = File.join(@root, 'foo', 'baz')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil).and_yield(path1).and_yield(path2).and_yield(path3)
    @filesystem_impl.set_content(path1, 'path1 content')
    @filesystem_impl.set_directory(path2)
    @filesystem_impl.set_directory(path3)
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpath => 'foo', :file => path1, :line => nil, :content => 'path1 content' }
    ])
  end
  
  context "with three standard files" do
    before :each do
      @path1 = File.join(@root, 'foo', 'bar.css')
      @path2 = File.join(@root, 'foo', 'baz.css')
      @path3 = File.join(@root, 'quux', 'marph.css')
      @file_cache.should_receive(:changed_files_since).once.with(@root, nil).and_yield(@path1).and_yield(@path2).and_yield(@path3)
      @filesystem_impl.set_content(@path1, 'path1 content')
      @filesystem_impl.set_content(@path2, 'path2 content')
      @filesystem_impl.set_content(@path3, 'path3 content')
      
      @aggregator = make(@root)
    end

    it "should return multiple files' fragments" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpath => 'foo', :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end
  
    it "should only detect changes on files on refresh!" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpath => 'foo', :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    
      @filesystem_impl.set_content(@path1, 'path1 content new')
      @filesystem_impl.set_content(@path3, 'path3 content new')
    
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpath => 'foo', :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    
      # We don't need to check the time passed to #changed_files_since; that's checked
      # by the spec for #Aggregator.
      @file_cache.should_receive(:changed_files_since).once.with(@root, anything()).and_yield(@path1).and_yield(@path3)
      @aggregator.refresh!
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content new' },
        { :target_subpath => 'foo', :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content new' }
      ])
    end
  
    it "should remove fragments from deleted files" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpath => 'foo', :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content' }
      ])
      
      @file_cache.should_receive(:changed_files_since).once.with(@root, anything()).and_yield(@path2)
      @filesystem_impl.set_does_not_exist(@path2, true)
      @aggregator.refresh!
      
      check_fragments(@aggregator, 'foo', [
        { :target_subpath => 'foo', :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpath => 'quux', :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end
  end
  
  it "should obey the inclusion proc"
  it "should allow a single extension as the inclusion proc"
  it "should allow several extensions as the inclusion proc"
  
  it "should obey tagged subpaths"
  it "should obey the subpath definition proc"
  it "should use the file's name when outside Rails.root/app"
end
