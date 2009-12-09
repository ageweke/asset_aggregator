require 'spec/spec_helper'

describe AssetAggregator::Aggregates::Aggregator do
  before :each do
    @fragment_set = mock(:fragment_set)
    @file_cache = mock(:file_cache)
    @subpath = "foo/bar"
    
    @filter1 = mock(:filter1)
    @filter2 = mock(:filter2)
    @filters = [ @filter1, @filter2 ]
    
    @aggregator = AssetAggregator::Aggregates::Aggregator.new(@fragment_set, @file_cache, @filters, @subpath)
  end
  
  it "should return components correctly" do
    @aggregator.fragment_set.should == @fragment_set
    @aggregator.file_cache.should == @file_cache
    @aggregator.subpath.should == @subpath
  end
  
  it "should return no implicit references, by default" do
    @aggregator.implicit_references_for(__FILE__).should be_empty
  end
  
  context "when filtering content" do
    before :each do
      @content = "foobarbazwhatever"
      @fragment = mock(:fragment, :content => @content)

      @intermediate_content = "abcdefghijklmnop"
      @end_content = "aaabbbccc"
    end
    
    it "should return filtered content appropriately" do
      @filter1.should_receive(:filter).with(@content).and_return(@intermediate_content)
      @filter2.should_receive(:filter).with(@intermediate_content).and_return(@end_content)

      @aggregator.filtered_content_from(@fragment).should == @end_content
    end
    
    it "should cache filtered results, rather than calling :filter multiple times" do
      @filter1.should_receive(:filter).with(@content).and_return(@intermediate_content)
      @filter2.should_receive(:filter).with(@intermediate_content).and_return(@end_content)

      @aggregator.filtered_content_from(@fragment).should == @end_content
      @aggregator.filtered_content_from(@fragment).should == @end_content
    end
    
    it "should refresh when requested" do
      @filter1.should_receive(:filter).twice.with(@content).and_return(@intermediate_content)
      @filter2.should_receive(:filter).once.with(@intermediate_content).and_return(@end_content)

      @aggregator.filtered_content_from(@fragment).should == @end_content
      
      @fragment_set.should_receive(:remove).and_return([ @fragment ])
      removal_proc = Proc.new { |f| true }
      @aggregator.send(:remove_fragments_if, &removal_proc)
      
      @filter2.should_receive(:filter).once.with(@intermediate_content).and_return(@end_content + "foofoo")
      @aggregator.filtered_content_from(@fragment).should == @end_content + "foofoo"
    end
  end
  
  context "using refresh!" do
    before :each do
      class << @aggregator
        attr_accessor :refresh_fragments_since_calls
      
        def refresh_fragments_since(last_refresh_fragments_since_time)
          @refresh_fragments_since_calls ||= [ ]
          @refresh_fragments_since_calls << last_refresh_fragments_since_time
        end
      end
    end
    
    it "should call through to #refresh_fragments_since with the correct time when #refresh! is called" do
      start_time_1 = Time.now
      @aggregator.refresh!
      end_time_1 = Time.now
    
      @aggregator.refresh_fragments_since_calls.length.should == 1
      @aggregator.refresh_fragments_since_calls[0].should be_nil
    
      start_time_2 = Time.now
      @aggregator.refresh!
      end_time_2 = Time.now
    
      @aggregator.refresh_fragments_since_calls.length.should == 2
      @aggregator.refresh_fragments_since_calls[1].should >= start_time_1
      @aggregator.refresh_fragments_since_calls[1].should <= end_time_1
    end
  
    it "should yield fragments, in order, via #each_fragment" do
      fragments = [ mock(:fragment1), mock(:fragment2), mock(:fragment3) ]
      @fragment_set.should_receive(:fragments).and_return(fragments)
      
      actual_fragments = [ ]
      @aggregator.each_fragment { |f| actual_fragments << f }
      actual_fragments.should == fragments
      @aggregator.refresh_fragments_since_calls.should == [ nil ]
    end
    
    it "should not call refresh! unnecessarily in #each_fragment" do
      fragments = [ mock(:fragment1), mock(:fragment2), mock(:fragment3) ]
      @fragment_set.should_receive(:fragments).twice.and_return(fragments)
      
      actual_fragments = [ ]
      @aggregator.each_fragment { |f| actual_fragments << f }
      actual_fragments.should == fragments
      @aggregator.refresh_fragments_since_calls.should == [ nil ]

      actual_fragments = [ ]
      @aggregator.each_fragment { |f| actual_fragments << f }
      actual_fragments.should == fragments
      @aggregator.refresh_fragments_since_calls.should == [ nil ]
    end
  end
  
  context "using #remove_fragments_if" do
    before :each do
      class << @fragment_set
        attr_accessor :remove_procs
        def remove(&proc)
          @remove_procs ||= [ ]
          @remove_procs << proc
          [ ]
        end
      end
    end
    
    it "should call through on #remove_fragments_if" do
      proc = Proc.new { |x| x.object_id % 2 == 0 }
      @aggregator.send(:remove_fragments_if, &proc)
      @fragment_set.remove_procs.should == [ proc ]
    end
  
    it "should remove fragments for a single file on #remove_all_fragments_for_file" do
      path = 'a/b/c'
      expected_proc = Proc.new { |f| f.source_position.file == path }
      @aggregator.send(:remove_all_fragments_for_file, path)
      
      actual_proc = @fragment_set.remove_procs[0]
      # Make sure it does the same thing as what we expect
      fake_fragment_1 = mock(:fragment, :source_position => AssetAggregator::Files::SourcePosition.new('a/b/c', nil))
      fake_fragment_2 = mock(:fragment, :source_position => AssetAggregator::Files::SourcePosition.new('a/b/d', nil))
      fake_fragment_3 = mock(:fragment, :source_position => AssetAggregator::Files::SourcePosition.new('a/b/c', nil))
      actual_proc.call(fake_fragment_1).should be_true
      actual_proc.call(fake_fragment_2).should be_false
      actual_proc.call(fake_fragment_3).should be_true
    end
  end
  
  it "should return the implicit target subpath correctly" do
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'views', 'one', 'two', 'three.html.erb'), "hoohah").should == 'one'
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'views', 'one', 'three.html.erb'), "hoohah").should == 'one'
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'views', 'two', 'three.html.erb'), "hoohah").should == 'two'
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'models', 'one', 'three.html.erb'), "hoohah").should == 'one'
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'views', 'three.html.erb'), "hoohah").should == 'three'
    @aggregator.send(:target_subpath, File.join(File.dirname(__FILE__), "hoohah"), "hoohah").should == File.dirname(__FILE__)
  end
  
  it "should return an explicit target subpath correctly" do
    @aggregator.send(:target_subpath, File.join(Rails.root, 'app', 'views', 'one', 'two', 'three.html.erb'), %{hoohah
      ASSET TARGET bonk
      more stuffs}).should == 'bonk'
  end
end
