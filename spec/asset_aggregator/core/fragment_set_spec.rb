require 'spec/spec_helper'

describe AssetAggregator::Core::FragmentSet do
  before :each do
    @filter1 = mock(:filter1)
    @filter2 = mock(:filter2)
    @filters = [ @filter1, @filter2 ]
    
    @source_position_1 = AssetAggregator::Core::SourcePosition.new('foo', 12)
    @fragment_1 = AssetAggregator::Core::Fragment.new('bar/baz', @source_position_1, 'some content here', Time.now)
    
    @fragment_set = AssetAggregator::Core::FragmentSet.new(@filters)
  end
  
  def all_fragments(subpath)
    out = [ ]
    @fragment_set.each_fragment_for(subpath) { |f| out << f }
    out
  end
  
  def all_fragments_object_ids(subpath)
    all_fragments(subpath).map { |f| f.object_id }
  end
  
  def make(subpath, file, line, content, mtime = Time.now)
    AssetAggregator::Core::Fragment.new(subpath, AssetAggregator::Core::SourcePosition.new(file, line), content, mtime)
  end
  
  it "should replace fragments on #add" do
    @fragment_set.add(@fragment_1)
    all_fragments_object_ids('bar/baz').should == [ @fragment_1.object_id ]
    all_fragments_object_ids('bonk/marph').should be_empty
    all_fragments_object_ids('bar').should be_empty
    all_fragments_object_ids('bar/').should be_empty
    all_fragments_object_ids('bar/bap').should be_empty
    
    fragment_2 = make('bar/baz', @source_position_1.file, @source_position_1.line, 'different content here')
    @fragment_set.add(fragment_2)
    all_fragments_object_ids('bar/baz').should == [ fragment_2.object_id ]
    all_fragments_object_ids('bonk/marph').should be_empty
    
    fragment_3 = make('bonk/marph', @source_position_1.file, @source_position_1.line, 'yet different content here')
    @fragment_set.add(fragment_3)
    all_fragments_object_ids('bar/baz').should be_empty
    all_fragments_object_ids('bonk/marph').should == [ fragment_3.object_id ]
  end
  
  it "should remove fragments as requested" do
    fragment_2 = make('bar/baz', 'baz', 34, 'bonko')
    fragment_3 = make('foo/bar', 'baz', 72, 'honk')
    
    [ @fragment_1, fragment_2, fragment_3 ].each { |f| @fragment_set.add(f) }
    
    @fragment_set.remove { |f| f.source_position.line > 30 }
    all_fragments_object_ids('bar/baz').should == [ @fragment_1.object_id ]
    all_fragments_object_ids('foo/bar').should == [ ]
  end
  
  it "should return #for_source_position correctly" do
    fragment_2 = make('bar/baz', 'baz', 34, 'bonko')
    fragment_3 = make('foo/bar', 'baz', 72, 'honk')
    
    [ @fragment_1, fragment_2, fragment_3 ].each { |f| @fragment_set.add(f) }
    
    @fragment_set.for_source_position(@fragment_1.source_position).should == @fragment_1
    @fragment_set.for_source_position(fragment_2.source_position).should == fragment_2
    @fragment_set.for_source_position(AssetAggregator::Core::SourcePosition.new('baz', 72)).should == fragment_3
    @fragment_set.for_source_position(AssetAggregator::Core::SourcePosition.new('baz', 73)).should be_nil
    @fragment_set.for_source_position(AssetAggregator::Core::SourcePosition.new('bax', 72)).should be_nil
  end
  
  it "should return #all_subpaths correctly" do
    @fragment_set.add(@fragment_1)
    @fragment_set.add(make('aaa/bar', 'baz', 12345, 'whatever'))
    @fragment_set.add(make('bar/baz', 'marph', 9999, 'yo'))
    
    @fragment_set.all_subpaths.should == %w{aaa/bar bar/baz}
  end
  
  it "should return #aggregated_subpaths_for correctly" do
    @fragment_set.add(@fragment_1)
    @fragment_set.add(make('aaa/bar', 'baz', 12345, 'whatever'))
    @fragment_set.add(make([ 'a/b', 'bar/baz' ], 'marph', 9999, 'yo'))
    
    @fragment_set.aggregated_subpaths_for(AssetAggregator::Core::SourcePosition.new("marph", 9999)).should == [ 'a/b', "bar/baz" ]
    @fragment_set.aggregated_subpaths_for(AssetAggregator::Core::SourcePosition.new("foo", 12)).should == [ "bar/baz" ]
  end
  
  it "should #remove_all correctly" do
    fragment_2 = make('bar/baz', 'baz', 34, 'bonko')
    fragment_3 = make('foo/bar', 'baz', 72, 'honk')
    
    [ @fragment_1, fragment_2, fragment_3 ].each { |f| @fragment_set.add(f) }
    
    @fragment_set.remove_all!
    all_fragments_object_ids('foo/bar').should be_empty
    all_fragments_object_ids('bar/baz').should be_empty
  end
  
  it "should #remove_all_for_file correctly" do
    fragment_2 = make('bar/baz', 'baz', 34, 'bonko')
    fragment_3 = make('foo/bar', 'baz', 72, 'honk')
    
    [ @fragment_1, fragment_2, fragment_3 ].each { |f| @fragment_set.add(f) }
    
    @fragment_set.remove_all_for_file('baz')
    all_fragments_object_ids('foo/bar').should be_empty
    all_fragments_object_ids('bar/baz').should == [ @fragment_1.object_id ]
  end
  
  it "should yield all fragments in #each_fragment_for, in order" do
    fragments = [
      make('aaa/bbb', 'mmm', 123, 'yo'),
      make('aaa/bbb', 'mmm', 456, 'yo'),
      make('aaa/bbb', 'zzz', 1,   'yo'),
      make('foo/bar', 'bbb', 234, 'hi'),
      make('zzz/aaa', 'qqq', 945, 'zz')
    ]
    
    shuffled = fragments.shuffle
    shuffled.each { |f| @fragment_set.add(f) }
    shuffled_fragments = shuffled.select { |f| fragments[0..2].include?(f) }
    
    sorting_proc = mock(:sorting_proc)
    sorting_proc.should_receive(:call).once.with(shuffled_fragments).and_return([ fragments[1], fragments[2], fragments[0] ])
    
    out = [ ]
    @fragment_set.each_fragment_for('aaa/bbb', sorting_proc) { |f| out << f.object_id }
    out.should == [ fragments[1].object_id, fragments[2].object_id, fragments[0].object_id ]
  end
  
  it "should pass the correct fragments into the sorting proc on #each_fragment_for, and yield them in whatever order it returns them in" do
    fragments = [
      make('aaa/bbb', 'mmm', 123, 'yo'),
      make('aaa/bbb', 'mmm', 456, 'yo'),
      make('aaa/bbb', 'zzz', 1,   'yo'),
      make('foo/bar', 'bbb', 234, 'hi'),
      make('zzz/aaa', 'qqq', 945, 'zz')
    ]
    
    fragments.shuffle.each { |f| @fragment_set.add(f) }
    
    all_fragments_object_ids('aaa/bbb').should == fragments[0..2].map { |f| f.object_id }
  end
  
  it "should raise an error on #filtered_content_from if the fragment is not in the set" do
    lambda { @fragment_set.filtered_content_from(@fragment_1) }.should raise_error
  end
  
  it "should yield the right content from #filtered_content_from" do
    @fragment_set.add(@fragment_1)
    
    @filter1.should_receive(:filter).with("some content here").and_return("filter1 output")
    @filter2.should_receive(:filter).with("filter1 output").and_return("filter2 output")
    @fragment_set.filtered_content_from(@fragment_1).should == "filter2 output"
  end
  
  it "should not incorrectly cache #filtered_content_from" do
    @fragment_set.add(@fragment_1)
    
    @filter1.should_receive(:filter).with("some content here").and_return("filter1 output")
    @filter2.should_receive(:filter).with("filter1 output").and_return("filter2 output")
    @fragment_set.filtered_content_from(@fragment_1).should == "filter2 output"
    
    @fragment_set.remove { |f| true }
    @fragment_set.add(@fragment_1)
    
    @filter1.should_receive(:filter).with("some content here").and_return("filter1 new output")
    @filter2.should_receive(:filter).with("filter1 new output").and_return("filter2 new output")
    
    @fragment_set.filtered_content_from(@fragment_1).should == "filter2 new output"
  end
end
