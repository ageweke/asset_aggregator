require 'spec/spec_helper'

describe AssetAggregator::Files::SourcePosition do
  describe "with a line" do
    before(:each) do
      @file = File.join(File.dirname(__FILE__), 'sample.txt')
      @terse_file = @file
      
      if @terse_file[0..(Rails.root.length - 1)] == Rails.root
        @terse_file = @terse_file[(Rails.root.length + 1)..-1]
      end
      
      @position = AssetAggregator::Files::SourcePosition.new(@file, 77)
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
  
  describe "not under Rails.root" do
    before(:each) do
      @file = "/foo/bar/baz/quux"
      @terse_file = @file
      @position = AssetAggregator::Files::SourcePosition.new(@file, 77)
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
      @file = File.join(File.dirname(__FILE__), 'sample.txt')
      @terse_file = @file
      
      if @terse_file[0..(Rails.root.length - 1)] == Rails.root
        @terse_file = @terse_file[(Rails.root.length + 1)..-1]
      end
      
      @position = AssetAggregator::Files::SourcePosition.new(@file, nil)
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
      expected_file = __FILE__
      expected_line = __LINE__ + 2
      
      position = AssetAggregator::Files::SourcePosition.for_here
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
      AssetAggregator::Files::SourcePosition.levels_up_stack(n)
    end
    
    it "should return the requested number of levels up the stack" do
      pos = foo(0)
      pos.file.should == __FILE__
      pos.line.should == BAZ_LINE
      
      pos = foo(1)
      pos.file.should == __FILE__
      pos.line.should == BAR_LINE
      
      pos = foo(2)
      pos.file.should == __FILE__
      pos.line.should == FOO_LINE
    end
  end
end
