require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'
require File.dirname(__FILE__) + '/aggregator_spec_helper_methods'

describe AssetAggregator::Aggregators::ClassInlinesAggregator do
  include AssetAggregator::Aggregators::AggregatorSpecHelperMethods

  before :each do
    @base_dir = File.expand_path("this_should_not_exist")
    @root = File.join(@base_dir, "app", "views")

    @filesystem_impl = AssetAggregator::TestFilesystemImpl.new
    @mtime = 1.hour.ago.to_i
    @filesystem_impl.set_default_mtime(@mtime)

    @integration = mock(:integration)
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
    @aggregate_type = mock(:aggregate_type, :asset_aggregator => @asset_aggregator)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @methods_for_file_proc = mock('methods_for_file_proc')
    @file_to_class_proc = mock('file_to_class_proc')
    
    @subpath_definitions = [ ]
    @subpath_definition_proc = Proc.new { |file, content| @subpath_definitions << [ file, content ]; [ content[0..2], content[-3..-1] ] }
  end
  
  def make(root, options = { })
    options = options.dup
    
    options[:methods_for_file_proc] = @methods_for_file_proc unless options.has_key?(:methods_for_file_proc)
    options[:file_to_class_proc] = @file_to_class_proc unless options.has_key?(:file_to_class_proc)
    
    subpath_definition_proc = if options.has_key?(:subpath_definition_proc)
      options.delete(:subpath_definition_proc)
    else
      @subpath_definition_proc
    end
    
    out = AssetAggregator::Aggregators::ClassInlinesAggregator.new(@aggregate_type, @file_cache, @filters, root, options, &subpath_definition_proc)
    out.filesystem_impl = @filesystem_impl if @filesystem_impl
    out
  end
  
  it "should turn itself into a string reasonably" do
    aggregator = make(@root)
    @integration.should_receive(:base_relative_path).once.with(@root).and_return("funky")
    aggregator.to_s.should match(/class_inlines.*funky/)
  end
  
  def check_aggregator(options)
    input_paths = Array(options[:input_paths] || raise("Must supply :input_paths"))
    processed_paths = Array(options[:processed_paths] || input_paths)
    processed_path_to_method_map = options[:processed_path_to_method_map] || { }
    processed_path_to_class_map = options[:processed_path_to_class_map] || { }
    processed_path_and_method_to_content_map = options[:processed_path_and_method_to_content_map] || { }
    processed_path_to_respond_to_map = options[:processed_path_to_respond_to_map] || { }
    processed_path_to_content_map = options[:processed_path_to_content_map] || { }
    allow_default_content = if options.has_key?(:allow_default_content) then options[:allow_default_content] else true end
    
    path_to_full_path_map = { }
    input_paths.each { |p| path_to_full_path_map[p] = (if p =~ %r{^/} then p else File.join(@base_dir, p) end) }
    processed_paths.each { |p| path_to_full_path_map[p] = (if p =~ %r{^/} then p else File.join(@base_dir, p) end) }
    # processed_paths.each { |p| path_to_full_path_map[p] = File.join(@base_dir, p) }
    
    default_target_class = mock('default_target_class')
    
    expected_content_for_subpaths = { }
    
    @file_cache.should_receive(:changed_files_since).once.with(@root, options[:file_cache_mtime]).and_return(input_paths.map { |x| path_to_full_path_map[x] })
    processed_paths.each do |short_processed_path|
      processed_path = path_to_full_path_map[short_processed_path]
      methods = processed_path_to_method_map[short_processed_path] || :test_aggregate_method
      @methods_for_file_proc.should_receive(:call).any_number_of_times.with(processed_path).and_return(methods) if @methods_for_file_proc
      
      target_class = processed_path_to_class_map[short_processed_path] || default_target_class
      @file_to_class_proc.should_receive(:call).once.ordered.with(processed_path).and_return(target_class)
      Array(methods).each do |method|
        responds = true
        if processed_path_to_respond_to_map[short_processed_path]
          responds = processed_path_to_respond_to_map[short_processed_path].include?(method)
        end
          
        target_class.should_receive(:respond_to?).once.ordered.with(method).and_return(responds)
        
        if responds
          content_array = if processed_path_and_method_to_content_map.has_key?([ short_processed_path, method ])
            processed_path_and_method_to_content_map[ [ short_processed_path, method ] ]
          elsif processed_path_to_content_map.has_key?(short_processed_path)
            processed_path_to_content_map[short_processed_path]
          elsif allow_default_content
            [ [ "abc_#{processed_path}_def", 12345 ] ]
          else
            raise "No content for #{processed_path.inspect}/#{method.inspect}"
          end
          target_class.should_receive(method).once.ordered.and_return(content_array)

          (content_array || [ ]).each do |(content, line_number)|
            subpaths = @subpath_definition_proc.call(processed_path, content)
            subpaths.each do |subpath|
              expected_content_for_subpaths[subpath] ||= [ ]
              expected_content_for_subpaths[subpath] << [ processed_path, content, line_number, subpaths ]
            end
          end
        end
      end
    end
    
    aggregator = options[:aggregator]
    if aggregator
      aggregator.refresh!
    else
      aggregator = make(@root)
    end
    
    expected_content_for_subpaths.each do |subpath, expected_content|
      expected_results = expected_content.map do |(processed_path, content, line_number, subpaths)|
        { :target_subpaths => subpaths, :file => processed_path, :line => line_number, :content => content, :mtime => @mtime }
      end
      
      check_fragments(aggregator, subpath, expected_results)
    end
    
    aggregator
  end
  
  it "should map classes using a custom methods_for_file_proc and file_to_class_proc" do
    check_aggregator(:input_paths => 'foo/bar/baz')
  end
  
  it "should skip dotfiles and directories" do
    @filesystem_impl.set_directory(File.join(@base_dir, 'a/b/c'))
    check_aggregator(:input_paths => [ 'foo/bar/baz', '.foobar', 'a/b/c' ], :processed_paths => [ 'foo/bar/baz' ])
  end
  
  it "should aggregate data from all methods on a class" do
    check_aggregator(:input_paths => 'foo/bar/baz', :processed_path_to_method_map => { 'foo/bar/baz' => [ :one, :two ] },
      :processed_path_and_method_to_content_map => {
        [ 'foo/bar/baz', :one ] => [ [ 'quux', 12345 ] ],
        [ 'foo/bar/baz', :two ] => [ [ 'marph', 23456 ] ]
      })
  end

  it "should not call methods that the class doesn't #respond_to" do
    check_aggregator(:input_paths => 'foo/bar/baz', :processed_path_to_method_map => { 'foo/bar/baz' => [ :one, :two ] },
      :processed_path_to_respond_to_map => { 'foo/bar/baz' => [ :two ] })
  end
  
  it "should allow methods to return nil" do
    check_aggregator(:input_paths => 'foo/bar/baz', :processed_path_to_method_map => { 'foo/bar/baz' => [ :one, :two ] },
      :processed_path_and_method_to_content_map => {
        [ 'foo/bar/baz', :one ] => [ [ 'quux', 12345 ] ],
        [ 'foo/bar/baz', :two ] => nil
      })
  end
  
  it "should allow files to vanish" do
    aggregator = check_aggregator(:input_paths => 'foo/bar/baz')
    @filesystem_impl.set_does_not_exist(File.join(@base_dir, 'foo/bar/baz'), true)
    check_aggregator(:aggregator => aggregator, :file_cache_mtime => anything(), :input_paths => 'foo/bar/baz', :processed_paths => [ ])
  end
  
  it "should prohibit non-numeric line numbers" do
    lambda do
      check_aggregator(:input_paths => 'foo/bar/baz', :processed_path_to_content_map => {
      'foo/bar/baz' => [ [ 'foo', 'bar' ] ]
      })
    end.should raise_error
  end
  
  it "should update data from a changed class" do
    aggregator = check_aggregator(:input_paths => 'foo/bar/baz',
      :processed_path_to_method_map => { 'foo/bar/baz' => [ :one, :two ] },
      :processed_path_and_method_to_content_map => {
        [ 'foo/bar/baz', :one ] => [ [ 'quux', 12345 ] ],
        [ 'foo/bar/baz', :two ] => [ [ 'marph', 23456 ] ]
      })
    
    check_aggregator(:aggregator => aggregator,
      :file_cache_mtime => anything(),
      :input_paths => 'foo/bar/baz',
      :processed_path_to_method_map => { 'foo/bar/baz' => [ :one, :two ] },
      :processed_path_and_method_to_content_map => {
        [ 'foo/bar/baz', :one ] => [ [ 'quux', 12345 ] ],
        [ 'foo/bar/baz', :two ] => nil
      })
  end
  
  { :javascript => :aggregated_javascript, :css => :aggregated_css }.each do |type, method_name|
    it "should use the correct default method for #{type}" do
      @methods_for_file_proc = nil
      @aggregate_type = mock(:aggregate_type, :type => type)
      check_aggregator(:input_paths => 'foo/bar/baz.rb',
        :processed_path_to_method_map => { 'foo/bar/baz.rb' => method_name },
        :processed_path_and_method_to_content_map => { [ 'foo/bar/baz.rb', method_name ] => [ [ 'hello', 12345 ]] },
        :allow_default_content => false)
    end
  end
  
  context "when loading classes from the filesystem" do
    def with_temp_dir(name)
      tempfile = Tempfile.new("class_inlines_aggregator_spec_#{name}")
      temp_dir = File.expand_path(tempfile.path)
      begin
        File.delete(temp_dir) if File.exist?(temp_dir)
        FileUtils.mkdir_p(temp_dir)
        
        @root = File.canonical_path(File.join(temp_dir, 'foo'))
        FileUtils.mkdir_p(@root)
        @file_to_class_proc = nil
        @filesystem_impl = nil
        
        yield temp_dir
      ensure
        FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
      end
    end
    
    def splat(path, content)
      path = File.expand_path(path)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir)
      File.open(path, 'w') { |f| f << content }
    end
    
    def with_files(temp_dir, name_to_content_map)
      name_to_content_map.each do |path, content|
        path = File.canonical_path(path)
        splat(path, content)
        
        @methods_for_file_proc.should_receive(:call).once.with(path).and_return(:the_data)
      end
      
      @file_cache.should_receive(:changed_files_since).once.with(@root, nil).and_return(name_to_content_map.keys.map { |p| File.canonical_path(p) })
      
      aggregator = make(@root)
      
      yield aggregator
    end
    
    it "should load non-prefixed classes fine" do
      with_temp_dir("non_prefixed_classes") do |dir|
        path = File.join(@root, 'foo', 'bar.rb')
        with_files(dir, path => "module Foo\nclass Bar\ndef self.the_data\n[ [ 'foobar', 12345 ] ]\nend\nend\nend\n") do |aggregator|
          check_fragments(aggregator, 'foo',
            [ { :target_subpaths => [ 'foo', 'bar' ], :file => path, :line => 12345, :content => 'foobar' } ])
        end
      end
    end
    
    it "should allow it to be a module named the same as the dirname of the root" do
      with_temp_dir("root_dirname_prefix") do |dir|
        path = File.join(@root, 'foo', 'bara.rb')
        with_files(dir, path => "module Foo\nmodule Foo\nclass Bara\ndef self.the_data\n[ [ 'foobar', 34567 ] ]\nend\nend\nend\nend\n") do |aggregator|
          check_fragments(aggregator, 'foo',
            [ { :target_subpaths => [ 'foo', 'bar' ], :file => path, :line => 34567, :content => 'foobar' } ])
        end
      end
    end
    
    it "should deal with syntax errors fine" do
      with_temp_dir("syntax_errors") do |dir|
        path = File.join(@root, 'foo', 'barb.rb')
        with_files(dir, path => "this is unquestionably not Ruby code") do |aggregator|
          lambda do
            check_fragments(aggregator, 'foo', [ ])
          end.should raise_error(StandardError, /SyntaxError/)
        end
      end
    end
    
    it "should deal other exceptions fine" do
      with_temp_dir("other_exceptions") do |dir|
        path = File.join(@root, 'foo', 'barc.rb')
        with_files(dir, path => "module Foo\nclass Barc\nraise 'baboomba'\nend\nend\n") do |aggregator|
          lambda do
            check_fragments(aggregator, 'foo', [ ])
          end.should raise_error(StandardError, /baboomba/)
        end
      end
    end
  end
end
