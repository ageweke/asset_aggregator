require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'

describe AssetAggregator::Core::FileCache do
  BASE_TIME = Time.at(Time.now.to_i)
  
  before :each do
    @fsimpl = AssetAggregator::TestFilesystemImpl.new
    @cache = AssetAggregator::Core::FileCache.new
    @cache.filesystem_impl = @fsimpl
    
    @fsimpl.set_find_yields([ '/root1/foo', '/root1/bar', '/root1/baz/quux' ])
    @fsimpl.set_mtime('/root1/foo', BASE_TIME - 10)
    @fsimpl.set_mtime('/root1/bar', BASE_TIME + 10)
    @fsimpl.set_mtime('/root1/baz/quux', BASE_TIME + 20)
  end
  
  context "when files are not modified" do
    it "should refresh times on a clean run" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
    
    it "should report all files when passed nil" do
      @cache.changed_files_since('/root1', nil).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/foo' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
    
    it "should prune any directories specified" do
      @fsimpl.set_find_yields([ '/root1/foo', '/root1/bar', '/root1/baz/quux' ])
      @cache.changed_files_since('/root1', nil, [ '/root1/bar' ]).sort.should == [ '/root1/baz/quux', '/root1/foo' ]
      @fsimpl.prune_calls.should == [ '/root1/bar' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
    
    it "should not hit the filesystem again if #refresh has not been called" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  
    it "should not hit the filesystem again for a different time if #refresh has not been called" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    
      @cache.changed_files_since('/root1', BASE_TIME + 15).sort.should == [ '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    
      @cache.changed_files_since('/root1', BASE_TIME - 15).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/foo' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end

    it "should hit the filesystem again if #refresh has been called" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]

      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root1/foo', '/root1/bar', '/root1/baz/quux' ])

      @cache.refresh!
      
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  end
  
  context "when files are modified" do
    it "should report the times after calling #refresh" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root1/foo', '/root1/bar', '/root1/baz/quux' ])
      @fsimpl.set_mtime('/root1/foo', BASE_TIME + 30)

      @cache.refresh!
      
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/foo' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  end
  
  context "when files are added" do
    it "should report the times after calling #refresh" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root1/foo', '/root1/bar', '/root1/baz/quux', '/root1/marph' ])
      @fsimpl.set_mtime('/root1/marph', BASE_TIME + 35)

      @cache.refresh!
      
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/marph' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux', '/root1/marph' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @cache.changed_files_since('/root1', BASE_TIME + 32).sort.should == [ '/root1/marph' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux', '/root1/marph' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  end
  
  context "when files are deleted" do
    it "should report files that are deleted as being modified when we noticed they were deleted" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root1/bar', '/root1/baz/quux' ])
      @fsimpl.set_mtime('/root1/foo', nil)
      
      @cache.refresh!
      
      start_time = Time.now
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/foo' ]
      end_time = Time.now
      @fsimpl.mtime_calls.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @cache.refresh!
      @fsimpl.clear_calls!
      
      @fsimpl.set_find_yields([ '/root1/bar', '/root1/baz/quux' ])
      @cache.changed_files_since('/root1', end_time + 1).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]

      @fsimpl.set_find_yields([ '/root1/bar', '/root1/baz/quux' ])
      @cache.changed_files_since('/root1', start_time - 1).sort.should == [ '/root1/bar', '/root1/baz/quux', '/root1/foo' ]
      @fsimpl.mtime_calls.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  end
  
  context "with close timing" do
    it "should pick up the right files as having been modified in all circumstances" do
      start_time = Time.now
      @fsimpl.set_mtime('/root1/foo', Time.at(start_time.to_i))
      @fsimpl.set_mtime('/root1/bar', start_time - 20)
      @fsimpl.set_mtime('/root1/baz/quux', start_time - 20)
      
      @cache.changed_files_since('/root1', start_time).sort.should == [ '/root1/foo' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
    end
  end
  
  context "with two roots" do
    it "should keep the roots entirely separate" do
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/foo', '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      
      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root2/aaa', '/root2/bbb', '/root2/ccc' ])
      @fsimpl.set_mtime('/root2/aaa', BASE_TIME)
      @fsimpl.set_mtime('/root2/bbb', BASE_TIME + 10)
      @fsimpl.set_mtime('/root2/ccc', BASE_TIME - 200)

      @cache.changed_files_since('/root2', BASE_TIME - 100).sort.should == [ '/root2/aaa', '/root2/bbb' ]
      @fsimpl.mtime_calls.should == [ '/root2/aaa', '/root2/bbb', '/root2/ccc' ]
      @fsimpl.find_calls.should == [ '/root2' ]
      
      @fsimpl.clear_calls!
      @cache.changed_files_since('/root1', BASE_TIME).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ ]
      @fsimpl.find_calls.should == [ ]
    end

    it "should keep a root and the same root, pruned, entirely separate" do
      @cache.changed_files_since('/root1', nil, [ '/root1/foo' ]).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      @fsimpl.prune_calls.should == [ '/root1/foo' ]
      
      @fsimpl.clear_calls!
      @fsimpl.set_find_yields([ '/root1/aaa', '/root1/bbb', '/root1/ccc' ])
      @cache.changed_files_since('/root1', nil, [ '/root1/bbb' ]).sort.should == [ '/root1/aaa', '/root1/ccc' ]
      @fsimpl.mtime_calls.should == [ '/root1/aaa', '/root1/ccc' ]
      @fsimpl.find_calls.should == [ '/root1' ]
      @fsimpl.prune_calls.should == [ '/root1/bbb' ]
      
      @fsimpl.clear_calls!
      @cache.changed_files_since('/root1', nil, [ '/root1/foo' ]).sort.should == [ '/root1/bar', '/root1/baz/quux' ]
      @fsimpl.mtime_calls.should == [ ]
      @fsimpl.find_calls.should == [ ]
      @fsimpl.prune_calls.should == [ ]

      @fsimpl.clear_calls!
      @cache.changed_files_since('/root1', nil, [ '/root1/bbb' ]).sort.should == [ '/root1/aaa', '/root1/ccc' ]
      @fsimpl.mtime_calls.should == [ ]
      @fsimpl.find_calls.should == [ ]
      @fsimpl.prune_calls.should == [ ]
    end
  end
end
