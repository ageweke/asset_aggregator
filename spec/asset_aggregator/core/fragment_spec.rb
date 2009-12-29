require 'spec/spec_helper'

describe AssetAggregator::Core::Fragment do
  before :each do
    @target_subpath = 'foo/bar'
    @source_position = AssetAggregator::Core::SourcePosition.new('foo', 12)
    @content = "content content yo"
    @mtime = Time.now
    
    @fragment = AssetAggregator::Core::Fragment.new(@target_subpath, @source_position, @content, @mtime)
  end
  
  it "should return the right components" do
    @fragment.target_subpaths.should == [ @target_subpath ]
    @fragment.source_position.should == @source_position
    @fragment.content.should == @content
    @fragment.mtime.should == @mtime.to_i
  end
  
  it "should return the array of target subpaths, if supplied" do
    AssetAggregator::Core::Fragment.new([ "a/b", "b/c" ], @source_position, @content, @mtime).target_subpaths.should == [ "a/b", "b/c" ]
  end
  
  it "should hash and compare correctly" do
    fragment2 = AssetAggregator::Core::Fragment.new('bar/baz', AssetAggregator::Core::SourcePosition.new('foo', 12), 'whatever man', @mtime + 100)
    fragment2.hash.should == @fragment.hash
    (fragment2 <=> @fragment).should == 0
    
    fragment3 = AssetAggregator::Core::Fragment.new('foo/bar', AssetAggregator::Core::SourcePosition.new('foo', 11), 'content content yo', @mtime)
    (fragment3 <=> @fragment).should < 0
  end
end
