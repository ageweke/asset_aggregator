require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'
require File.dirname(__FILE__) + '/aggregator_spec_helper_methods'

describe AssetAggregator::Aggregators::FilesAggregator do
  include AssetAggregator::Aggregators::AggregatorSpecHelperMethods
  
  before :each do
    @base_dir = File.expand_path("this_should_not_exist")
    @root = File.join(@base_dir, 'app', 'views')

    @integration = AssetAggregator::Core::Integration.new(@base_dir, nil)
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
    @aggregate_type = mock(:aggregate_type, :asset_aggregator => @asset_aggregator)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @filesystem_impl = AssetAggregator::TestFilesystemImpl.new
  end
  
  def make(root, include_proc = nil, options = nil, &subpath_definition_proc)
    out = AssetAggregator::Aggregators::FilesAggregator.new(@aggregate_type, @file_cache, @filters, root, include_proc, options, &subpath_definition_proc)
    out.filesystem_impl = @filesystem_impl
    out
  end
  
  it "should return a single file's fragment" do
    path = File.join(@root, 'foo', 'bar.css')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ ]).and_return([ path ])
    @filesystem_impl.set_content(path, 'hidey ho')
    mtime = 1262120245
    @filesystem_impl.set_mtime(path, mtime)
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => path, :line => nil, :content => 'hidey ho', :mtime => mtime }
    ])
    
    check_fragments(aggregator, 'bar', [ ])
  end
  
  it "should not return dotfiles" do
    path1 = File.join(@root, 'foo', 'bar.css')
    path2 = File.join(@root, 'foo', '.bonk.css')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ ]).and_return([ path1, path2 ])
    @filesystem_impl.set_content(path1, 'path1 content')
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => path1, :line => nil, :content => 'path1 content' }
    ])
  end
  
  it "should not return directories" do
    path1 = File.join(@root, 'foo', 'bar.css')
    path2 = File.join(@root, 'foo')
    path3 = File.join(@root, 'foo', 'baz')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ ]).and_return([ path1, path2, path3 ])
    @filesystem_impl.set_content(path1, 'path1 content')
    @filesystem_impl.set_directory(path2)
    @filesystem_impl.set_directory(path3)
    
    aggregator = make(@root)
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => path1, :line => nil, :content => 'path1 content' }
    ])
  end
  
  it "should pass along :exclude_directories to the file cache" do
    path1 = File.join(@root, 'foo', 'bar.css')
    path2 = File.join(@root, 'bar', 'baz.css')
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ 'bar' ]).and_return([ path1 ])
    @filesystem_impl.set_content(path1, 'path1 content')
    
    aggregator = make(@root, nil, { :exclude_directories => [ 'bar' ] })
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => path1, :line => nil, :content => 'path1 content' }
    ])
  end
  
  context "with three standard files" do
    before :each do
      @path1 = File.join(@root, 'foo', 'bar.one')
      @path2 = File.join(@root, 'foo', 'baz.two')
      @path3 = File.join(@root, 'quux', 'marph.three')
      @mtime1 = 1262120245
      @mtime2 = 1262120248
      @mtime3 = 1262120267
      @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ ]).and_return([ @path1, @path2, @path3 ])
      @filesystem_impl.set_content(@path1, 'path1 content')
      @filesystem_impl.set_content(@path2, 'path2 content')
      @filesystem_impl.set_content(@path3, 'path3 content')
      @filesystem_impl.set_mtime(@path1, @mtime1)
      @filesystem_impl.set_mtime(@path2, @mtime2)
      @filesystem_impl.set_mtime(@path3, @mtime3)
      
      @aggregator = make(@root)
    end

    it "should return multiple files' fragments" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content', :mtime => @mtime1 },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => 'path2 content', :mtime => @mtime2 }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content', :mtime => @mtime3 }
      ])
    end
    
    it "should not pull in content when asked not to" do
      @aggregator = make(@root, nil, { :delay_read => true })
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => nil, :mtime => @mtime1 },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => nil, :mtime => @mtime2 }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => nil, :mtime => @mtime3 }
      ])
    end
  
    it "should only detect changes on files on refresh!" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    
      @filesystem_impl.set_content(@path1, 'path1 content new')
      @filesystem_impl.set_content(@path3, 'path3 content new')
    
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    
      # We don't need to check the time passed to #changed_files_since; that's checked
      # by the spec for #Aggregator.
      @file_cache.should_receive(:changed_files_since).once.with(@root, anything(), [ ]).and_return([ @path1, @path3 ])
      @aggregator.refresh!
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content new' },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content new' }
      ])
    end
  
    it "should remove fragments from deleted files" do
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpaths => [ 'foo' ], :file => @path2, :line => nil, :content => 'path2 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
      
      @file_cache.should_receive(:changed_files_since).once.with(@root, anything(), [ ]).and_return([ @path2 ])
      @filesystem_impl.set_does_not_exist(@path2, true)
      @aggregator.refresh!
      
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end
    
    it "should obey the inclusion proc" do
      @aggregator = make(@root, Proc.new { |f| File.basename(f) =~ /bar/ || File.basename(f) =~ /marph/ })
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end

    it "should allow a single extension as the inclusion proc" do
      @aggregator = make(@root, 'one')
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [ ])
    end
    
    it "should allow several extensions as the inclusion proc" do
      @aggregator = make(@root, [ 'one', 'three' ])
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end
    
    it "should allow dots in the extensions, and be case-insensitive" do
      @aggregator = make(@root, [ '.one', '.ThRee' ])
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' }
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end

    it "should obey tagged subpaths" do
      new_content = "path2 content\n\nASSET TARGET: quux\nwhatever yo"
      @filesystem_impl.set_content(@path2, new_content)
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' },
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'quux' ], :file => @path2, :line => nil, :content => new_content },
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end

    it "should obey tagged subpaths with addition" do
      new_content = "path2 content\n\nASSET TARGET: add quux\nwhatever yo"
      @filesystem_impl.set_content(@path2, new_content)
      check_fragments(@aggregator, 'foo', [
        { :target_subpaths => [ 'foo' ], :file => @path1, :line => nil, :content => 'path1 content' },
        { :target_subpaths => [ 'foo', 'quux' ], :file => @path2, :line => nil, :content => new_content },
      ])
      check_fragments(@aggregator, 'quux', [
        { :target_subpaths => [ 'foo', 'quux' ], :file => @path2, :line => nil, :content => new_content },
        { :target_subpaths => [ 'quux' ], :file => @path3, :line => nil, :content => 'path3 content' }
      ])
    end
    
    context "with a complex subpath definition proc" do
      before :each do
        @aggregator = make(@root, nil) do |file, content|
          out = case File.basename(file)
          when /bar/ then 'one'
          when /baz/ then 'two'
          when /marph/ then 'one'
          else 'nonsense'
          end
          out = 'three' if content =~ /path3\s+content/
          out
        end
      end
      
      it "should obey the subpath definition proc, and pass filename and file content" do
        check_fragments(@aggregator, 'one', [
          { :target_subpaths => [ 'one' ], :file => @path1, :line => nil, :content => 'path1 content' },
        ])
        check_fragments(@aggregator, 'two', [
          { :target_subpaths => [ 'two' ], :file => @path2, :line => nil, :content => 'path2 content' }
        ])
        check_fragments(@aggregator, 'three', [
          { :target_subpaths => [ 'three' ], :file => @path3, :line => nil, :content => 'path3 content' },
        ])
      end
    
      it "should have tags override the subpath definition proc" do
        new_content = "path2 content\nASSET TARGET: one"
        @filesystem_impl.set_content(@path2, new_content)
        check_fragments(@aggregator, 'one', [
          { :target_subpaths => [ 'one' ], :file => @path1, :line => nil, :content => 'path1 content' },
          { :target_subpaths => [ 'one' ], :file => @path2, :line => nil, :content => new_content }
        ])
        check_fragments(@aggregator, 'two', [ ])
        check_fragments(@aggregator, 'three', [
          { :target_subpaths => [ 'three' ], :file => @path3, :line => nil, :content => 'path3 content' },
        ])
      end
    end
  end
  
  it "should use the file's name when outside base_dir/app" do
    @root = File.join(File.dirname(@base_dir), 'somewhere', 'else')
    path = File.join(@root, 'foo', 'bar.css')
    
    @file_cache.should_receive(:changed_files_since).once.with(@root, nil, [ ]).and_return([ path ])
    @filesystem_impl.set_content(path, 'hidey ho')
    
    aggregator = make(@root)
    check_fragments(aggregator, 'bar', [
      { :target_subpaths => [ 'bar' ], :file => path, :line => nil, :content => 'hidey ho' }
    ])
    
    check_fragments(aggregator, 'foo', [ ])
  end
end
