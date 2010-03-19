require 'spec/spec_helper'

describe AssetAggregator::Core::PageReferenceSet do
  before :each do
    @integration = mock(:integration)
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
    
    @javascript_type = mock(:javascript_type)
     @asset_aggregator.should_receive(:aggregate_type).any_number_of_times.with(:javascript).and_return(@javascript_type)
    
    @output_handler = mock(:output_handler)
    @output_handler_class = mock(:output_handler_class)
    
    @set = AssetAggregator::Core::PageReferenceSet.new(@asset_aggregator)
  end
  
  def add_fragment(type, path, new_path, descrip)
    @integration.should_receive(:path_from_base).once.with(path).and_return(new_path)
    source_position = mock(:source_position)
    @set.require_fragment(type, path, source_position, descrip)
    source_position
  end
  
  it "should output a single fragment correctly" do
    source_position_1 = add_fragment(:javascript, "foo/bar", "/foo2/bar2", "baz")
    
    @output_handler_class.should_receive(:new).once.ordered.with(@asset_aggregator, { }).and_return(@output_handler)
    
    @asset_aggregator.should_receive(:aggregated_subpaths_for).once do |type, sp|
      type.should == :javascript
      sp.file.should == File.expand_path("/foo2/bar2")
      [ "bonko" ]
    end
    
    @output_handler.should_receive(:start_all).once.ordered
    assert_reference_list_calls(@output_handler, @javascript_type, [
      'bonko', [
        { :descrip => "baz", :source_position => source_position_1, :file => "/foo2/bar2", :line => nil, :type => :javascript }
      ]
    ])
    @output_handler.should_receive(:end_all).once.ordered
    @output_handler.should_receive(:text).once.ordered.and_return("abcdef")
    
    text = @set.include_text(:output_handler_class => @output_handler_class)
    text.should == "abcdef"
  end
  
  def assert_reference_list_calls(object, expected_type, subpath_and_expected_references_array)
    assert_reference_list_call(object, :start_aggregate_type, expected_type, subpath_and_expected_references_array)
    subpath_and_expected_references_array.each_slice(2) do |(subpath, expected_references)|
      assert_reference_call(object, :aggregate, expected_type, subpath, expected_references)
    end
    assert_reference_list_call(object, :end_aggregate_type, expected_type, subpath_and_expected_references_array)
  end
  
  def assert_reference_list_call(object, method_name, expected_type, subpath_and_expected_references_array)
    object.should_receive(method_name).once.ordered do |actual_type, actual_subpath_array|
      begin
      actual_type.should == expected_type
      actual_subpath_array.each_with_index do |subpath_and_reference_array, index|
        (actual_subpath, actual_reference_array) = subpath_and_reference_array
        expected_subpath = subpath_and_expected_references_array[index * 2]
        actual_subpath.should == expected_subpath
        expected_reference_array = subpath_and_expected_references_array[index * 2 + 1]
        check_references(actual_reference_array, expected_reference_array)
      end
    rescue => e
      $stderr.puts "ERROR: #{e}"
      $stderr.puts e.backtrace.join("\n")
      $stderr.puts "***"
      raise
    end
    end
  end
  
  def assert_reference_call(object, method_name, expected_type, expected_subpath, expected_references)
    object.should_receive(method_name).once.ordered do |actual_type, actual_subpath, actual_references|
      actual_type.should == expected_type
      actual_subpath.should == expected_subpath
      check_references(actual_references, expected_references)
    end
  end
  
  def check_references(actual_references, expected_references)
    actual_references.length.should == expected_references.length
    
    actual_references.each_with_index do |actual_reference, index|
      expected_reference = expected_references[index]
      check_reference(actual_reference, expected_reference[:descrip], expected_reference[:source_position], expected_reference[:file], expected_reference[:line], expected_reference[:type])
    end
  end
  
  def check_reference(reference, descrip, source_position, file, line, type)
    reference.descrip.should == descrip
    reference.reference_source_position.should == source_position
    reference.fragment_source_position.file.should == file
    reference.fragment_source_position.line.should == line
    reference.aggregate_type.should == type
  end
end