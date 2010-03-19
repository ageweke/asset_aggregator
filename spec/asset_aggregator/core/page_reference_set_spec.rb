require 'spec/spec_helper'

describe AssetAggregator::Core::PageReferenceSet do
  before :each do
    @integration = mock(:integration)
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
    
    @javascript_type = mock(:javascript_type)
    @css_type = mock(:css_type)
    @asset_aggregator.should_receive(:aggregate_type).any_number_of_times do |in_type|
      case in_type
      when :javascript then @javascript_type
      when :css then @css_type
      else raise("Unknown type #{in_type}")
      end
    end

    @output_handler = mock(:output_handler)
    @output_handler_class = mock(:output_handler_class)
    
    @set = AssetAggregator::Core::PageReferenceSet.new(@asset_aggregator)
  end
  
  def add_fragment(type, path, new_path, descrip, target_subpaths, source_position = nil, skip_aggregated_subpaths = false)
    passed_path = path
    passed_line = nil
    if passed_path =~ /^(.*):(\d+)$/i
      passed_path, passed_line = $1, $2.to_i
    end
    @integration.should_receive(:path_from_base).once.with(passed_path).and_return(new_path)
    source_position ||= mock(:source_position)
    @set.require_fragment(type, path, source_position, descrip)

    unless skip_aggregated_subpaths
      @asset_aggregator.should_receive(:aggregated_subpaths_for).once do |actual_type, actual_source_position|
        actual_type.should == type
        actual_source_position.file.should == File.expand_path(new_path)
        actual_source_position.line.should == passed_line
        target_subpaths
      end
    end

    source_position
  end
  
  def add_aggregate(type, subpath, source_position = nil, descrip = nil)
    source_position ||= mock(:source_position)
    @set.require_aggregate(type, subpath, source_position, descrip)
    source_position
  end
  
  it "should output a single fragment correctly" do
    source_position_1 = add_fragment(:javascript, "foo/bar", "/foo2/bar2", "baz", [ "bonko" ])
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'bonko', [
          { :descrip => "baz", :source_position => source_position_1, :file => "/foo2/bar2", :line => nil, :type => :javascript }
        ]
      ])
    end
  end
  
  it "should default 'descrip' to 'explicit reference', and parse out String source-positions" do
    source_position_1 = add_fragment(:javascript, "foo/bar:173", "/foo2/bar2", nil, [ "bonko" ])
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'bonko', [
          { :descrip => "explicit reference", :source_position => source_position_1, :file => "/foo2/bar2", :line => 173, :type => :javascript }
        ]
      ])
    end
  end
  
  it "should output two fragments in the same subpath correctly" do
    source_position_1 = add_fragment(:javascript, "foo/bar", "/foo2/bar2", "descrip1", [ "bonko" ])
    source_position_2 = add_fragment(:javascript, "bar/baz", "/bar2/baz2", "descrip2", [ "bonko" ])
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'bonko', [
          { :descrip => "descrip2", :source_position => source_position_2, :file => "/bar2/baz2", :line => nil, :type => :javascript },
          { :descrip => "descrip1", :source_position => source_position_1, :file => "/foo2/bar2", :line => nil, :type => :javascript }
        ]
      ])
    end
  end
  
  it "should output two fragments in the same subpath, and one in another, correctly" do
    source_position_1 = add_fragment(:javascript, "foo/bar", "/foo2/bar2", "descrip1", [ "bonko" ])
    source_position_2 = add_fragment(:javascript, "bar/baz", "/bar2/baz2", "descrip2", [ "bonko" ])
    source_position_3 = add_fragment(:javascript, "a/b", "/a2/b2", "descrip3", [ "other" ])
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'bonko', [
          { :descrip => "descrip2", :source_position => source_position_2, :file => "/bar2/baz2", :line => nil, :type => :javascript },
          { :descrip => "descrip1", :source_position => source_position_1, :file => "/foo2/bar2", :line => nil, :type => :javascript }
        ],
        'other', [
          { :descrip => "descrip3", :source_position => source_position_3, :file => "/a2/b2", :line => nil, :type => :javascript },
        ]
      ])
    end
  end
  
  it "should output direct aggregate references" do
    source_position_1 = add_aggregate(:javascript, 'foobar', "sp1", 'zzz')
    source_position_2 = add_aggregate(:javascript, 'foobar', "sp2", 'yyy')
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'foobar', [
          { :descrip => 'zzz', :source_position => "sp1", :file => 'foobar', :type => :javascript, :is_aggregate => true },
          { :descrip => 'yyy', :source_position => "sp2", :file => 'foobar', :type => :javascript, :is_aggregate => true }
        ]
      ])
    end
  end
  
  it "should allow mixing fragment and direct aggregate references" do
    source_position_1 = add_aggregate(:javascript, 'foobar', "sp1", 'zzz')
    source_position_2 = add_fragment(:javascript, 'foo/bar', '/foo2/bar2', 'descrip2', [ 'foobar' ])
    source_position_3 = add_fragment(:javascript, 'a/b', '/a3/b3', 'descrip3', [ 'barfoo' ])
    source_position_4 = add_aggregate(:javascript, 'barbar', "sp4", 'xxx')
    
    call_include_text do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'barbar', [
          { :descrip => 'xxx', :source_position => "sp4", :file => 'barbar', :type => :javascript, :is_aggregate => true }
        ],
        'barfoo', [
          { :descrip => 'descrip3', :source_position => source_position_3, :file => '/a3/b3', :line => nil, :type => :javascript }
        ],
        'foobar', [
          { :descrip => "descrip2", :source_position => source_position_2, :file => "/foo2/bar2", :line => nil, :type => :javascript },
          { :descrip => 'zzz', :source_position => "sp1", :file => 'foobar', :type => :javascript, :is_aggregate => true }
        ]
      ])
    end
  end
  
  describe "with multiple types, but selecting just one" do
    before :each do
      @source_position_1 = add_fragment(:javascript, 'foo/bar', '/foo1/bar1', 'descrip1', [ 'path1' ], nil, true)
      @source_position_2 = add_fragment(:css, 'bar/baz', '/bar2/baz2', 'descrip2', [ 'path1' ], nil, true)
    
      @asset_aggregator.should_receive(:aggregated_subpaths_for).any_number_of_times.with(any_args).and_return([ 'path1' ])
    end
    
    it "should allow selecting just CSS" do
      call_include_text(:types => [ :css ]) do
        assert_reference_list_calls(@output_handler, @css_type, [
          'path1', [
            { :descrip => "descrip2", :source_position => @source_position_2, :file => "/bar2/baz2", :line => nil, :type => :css }
          ]
        ])
      end
    end

    it "should allow selecting just Javascript" do
      call_include_text(:types => [ :javascript ]) do
        assert_reference_list_calls(@output_handler, @javascript_type, [
          'path1', [
            { :descrip => "descrip1", :source_position => @source_position_1, :file => "/foo1/bar1", :line => nil, :type => :javascript }
          ]
        ])
      end
    end
  end
  
  it "should output nothing, but still give callbacks, for explicitly-selected types with no content" do
    source_position_1 = add_fragment(:javascript, 'foo/bar', '/foo1/bar1', 'descrip1', [ 'path1' ], nil, true)
    
    call_include_text(:types => [ :css ]) do
      assert_reference_list_calls(@output_handler, @css_type, [ ])
    end
  end
  
  it "should pass arbitrary options through to the PageReferencesOutputHandler constructor" do
    source_position_1 = add_fragment(:javascript, "foo/bar", "/foo2/bar2", "baz", [ "bonko" ])
    
    call_include_text(:foo => :bar, :baz => [ :quux ]) do
      assert_reference_list_calls(@output_handler, @javascript_type, [
        'bonko', [
          { :descrip => "baz", :source_position => source_position_1, :file => "/foo2/bar2", :line => nil, :type => :javascript }
        ]
      ])
    end
  end
  
  def call_include_text(options = { })
    @output_handler_class.should_receive(:new).once.ordered.with(@asset_aggregator, options.reject { |k,v| [ :types ].include?(k) }).and_return(@output_handler)
    @output_handler.should_receive(:start_all).once.ordered
    
    yield
    
    @output_handler.should_receive(:end_all).once.ordered
    output_text = "abcdef_#{rand(1_000_000)}"
    @output_handler.should_receive(:text).once.ordered.and_return(output_text)
    
    text = @set.include_text({ :output_handler_class => @output_handler_class }.merge(options))
    text.should == output_text
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
        # RSpec swallows the stack trace otherwise, making it incredibly hard to track
        # down failures...
        $stderr.puts "Expectation failure detail: #{e}\n#{e.backtrace.join("\n")}"
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
      check_reference(actual_reference, expected_reference[:descrip], expected_reference[:source_position], expected_reference[:file], expected_reference[:line], expected_reference[:type], expected_reference[:is_aggregate] ? :aggregate : :fragment)
    end
  end
  
  def check_reference(reference, descrip, source_position, file, line, type, reference_type)
    reference.descrip.should == descrip
    reference.reference_source_position.should == source_position
    
    if reference_type == :fragment
      reference.kind_of?(AssetAggregator::Core::FragmentReference).should be_true
      reference.fragment_source_position.file.should == file
      reference.fragment_source_position.line.should == line
    else
      reference.kind_of?(AssetAggregator::Core::AggregateReference).should be_true
      reference.subpath.should == file
    end
    
    reference.aggregate_type.should == type
  end
end