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
      
      @position = make(@file, 77)
    end
    
    it "should return the file and line" do
      @position.file.should == @file
      @position.line.should == 77
    end
    
    it "should use the integration object to make a terse file, when appropriate" do
      integration = mock(:integration)
      integration.should_receive(:base_relative_path).once.with(@file).and_return("foobarbaz/quux")
      
      @position.terse_file(integration).should == "foobarbaz/quux"
    end
    
    it "should return the full file, when no integration object is supplied to #terse_file" do
      @position.terse_file.should == @file
      @position.terse_file(nil).should == @file
    end
    
    it "should make a nice string" do
      @position.to_s.should == "#{@file}:77"
    end
    
    it "should use the integrator to make a terse file in #to_s" do
      integration = mock(:integration)
      integration.should_receive(:base_relative_path).once.with(@file).and_return("foobarbaz/quux")
      
      @position.to_s(integration).should == "foobarbaz/quux:77"
    end

    it "should allow a nil integrator to be passed for #to_s" do
      @position.to_s(nil).should == "#{@file}:77"
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
  
  describe "not under the base dir" do
    before(:each) do
      @file = "/foo/bar/baz/quux"
      @position = make(@file, 77)
    end
    
    it "should return the file and line" do
      @position.file.should == @file
      @position.line.should == 77
    end
    
    it "should make a nice string" do
      @position.to_s.should == "#{@file}:77"
    end
  end
  
  describe "without a line" do
    before(:each) do
      @file = File.join(File.dirname(this_file), 'sample.txt')
      @position = make(@file, nil)
    end
    
    it "should return the file, but no line" do
      @position.file.should == @file
      @position.line.should be_nil
    end
    
    it "should make a nice string" do
      @position.to_s.should == @file
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
