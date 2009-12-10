require 'spec/spec_helper'

describe AssetAggregator::Core::SourcePosition do
  def make(file, line)
    AssetAggregator::Core::SourcePosition.new(file, line)
  end
  
  def this_file
    File.canonical_path(__FILE__)
  end
  
  describe "with a line" do
    before(:each) do
      @file = File.join(File.dirname(this_file), 'sample.txt')
      @terse_file = @file
      rails_root = File.canonical_path(Rails.root)
      
      if @terse_file[0..(rails_root.length - 1)] == rails_root
        @terse_file = @terse_file[(Rails.root.length + 1)..-1]
      end
      
      @position = make(@file, 77)
    end
    
    it "should return the file and line" do
      @position.file.should == @file
      @position.line.should == 77
    end
    
    it "should return a terse file" do
      @position.terse_file.should == @terse_file
      @position.terse_file.should_not == @file
    end
    
    it "should make a nice string" do
      @position.to_s.should == "#{@terse_file}:77"
    end
  end
  
  it "should hash correctly" do
    spec1 = make("/foo/bar/baz", 123)
    spec2 = make("/foo/bar/baz", 123)
    
    spec1.hash.should == spec2.hash
  end
  
  describe "should compare correctly" do
    it "based on file only, when that's all that's available" do
      spec1 = make("/foo/bar/bam", nil)
      spec2 = make("/foo/bar/bam", nil)
      spec3 = make("/foo/bar/bal", nil)
      spec4 = make("/foo/bar/ban", nil)
    
      spec1.should == spec2
      spec1.should > spec3
      spec1.should < spec4
    end
    
    it "based on file, and then line" do
      spec1 = make("/foo/bar/bam", 100)
      spec2 = make("/foo/bar/bam", 100)
      
      spec3 = make("/foo/bar/bam", 80)
      spec4 = make("/foo/bar/bal", 900)
      
      spec5 = make("/foo/bar/bam", 120)
      spec6 = make("/foo/bar/ban", 20)
      
      spec1.should == spec2
      spec1.should > spec3
      spec1.should > spec4
      spec1.should < spec5
      spec1.should < spec6
    end
    
    it "making positions with a line greater than those with the same file, but without a line" do
      spec1 = make("/foo/bar/bam", 100)
      
      spec2 = make("/foo/bar/bam", nil)
      spec3 = make("/foo/bar/bal", nil)
      spec4 = make("/foo/bar/ban", nil)
      spec5 = make("/foo/bar/ban", 20)
      
      spec1.should > spec2
      spec1.should > spec3
      spec1.should < spec4
      spec1.should < spec5
    end
  end
  
  describe "not under Rails.root" do
    before(:each) do
      @file = "/foo/bar/baz/quux"
      @terse_file = @file
      @position = make(@file, 77)
    end
    
    it "should return the file and line" do
      @position.file.should == @file
      @position.line.should == 77
    end
    
    it "should return a terse file" do
      @position.terse_file.should == @terse_file
    end
    
    it "should make a nice string" do
      @position.to_s.should == "#{@terse_file}:77"
    end
  end
  
  describe "without a line" do
    before(:each) do
      @file = File.join(File.dirname(this_file), 'sample.txt')
      @terse_file = @file
      
      if @terse_file[0..(Rails.root.length - 1)] == Rails.root
        @terse_file = @terse_file[(Rails.root.length + 1)..-1]
      end
      
      @position = make(@file, nil)
    end
    
    it "should return the file, but no line" do
      @position.file.should == @file
      @position.line.should be_nil
    end
    
    it "should return a terse file" do
      @position.terse_file.should == @terse_file
    end
    
    it "should make a nice string" do
      @position.to_s.should == @terse_file
    end
  end
  
  describe "#for_here" do
    it "should return the current position" do
      expected_file = this_file
      expected_line = __LINE__ + 2
      
      position = AssetAggregator::Core::SourcePosition.for_here
      position.file.should == expected_file
      position.line.should == expected_line
    end
  end
  
  describe "#levels_up_stack" do
    FOO_LINE = __LINE__ + 2
    def foo(n)
      bar(n)
    end
    
    BAR_LINE = __LINE__ + 2
    def bar(n)
      baz(n)
    end
    
    BAZ_LINE = __LINE__ + 2
    def baz(n)
      AssetAggregator::Core::SourcePosition.levels_up_stack(n)
    end
    
    it "should return the requested number of levels up the stack" do
      pos = foo(0)
      pos.file.should == this_file
      pos.line.should == BAZ_LINE
      
      pos = foo(1)
      pos.file.should == this_file
      pos.line.should == BAR_LINE
      
      pos = foo(2)
      pos.file.should == this_file
      pos.line.should == FOO_LINE
    end
  end
end
