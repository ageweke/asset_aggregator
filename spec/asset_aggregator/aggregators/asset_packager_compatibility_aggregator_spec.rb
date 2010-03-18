require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'
require File.dirname(__FILE__) + '/aggregator_spec_helper_methods'

describe AssetAggregator::Aggregators::AssetPackagerCompatibilityAggregator do
  include AssetAggregator::Aggregators::AggregatorSpecHelperMethods
  
  before :each do
    @base_dir = File.expand_path("this_dir_should_never_exist")
    @integration = AssetAggregator::Core::Integration.new(@base_dir, nil)
    @asset_aggregator = mock(:asset_aggregator, :integration => @integration)
    
    @aggregate_type = mock(:aggregate_type, :type => :javascript, :asset_aggregator => @asset_aggregator)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @filesystem_impl = AssetAggregator::TestFilesystemImpl.new
    
    @yaml_file = default_yaml_file
  end

  def make(asset_packager_yml_file = nil, component_source_proc = nil, &subpath_definition_proc)
    out = AssetAggregator::Aggregators::AssetPackagerCompatibilityAggregator.new(@aggregate_type, @file_cache, @filters, asset_packager_yml_file, component_source_proc, &subpath_definition_proc)
    out.filesystem_impl = @filesystem_impl
    out
  end
  
  def default_yaml_file
    File.join(@base_dir, "config", "asset_packages.yml")
  end
  
  def set_files(yaml_content, file_map)
    @filesystem_impl.set_content(@yaml_file, yaml_content)
    file_map.each do |file, content|
      @filesystem_impl.set_content(content_file(file), content)
    end
  end
  
  def content_file(subpath)
    if subpath =~ %r{^/}
      subpath
    else
      File.join(@base_dir, 'public', 'javascripts', *subpath)
    end
  end
  
  it "should aggregate a simple set of files" do
    set_files(<<-EOM, { 'bar.js' => 'barjscontent', 'baz.js' => 'bazjscontent' })
javascripts:
- foo:
  - bar
  - baz
EOM
    
    aggregator = make
    
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => content_file('bar.js'), :line => nil, :content => 'barjscontent' },
      { :target_subpaths => [ 'foo' ], :file => content_file('baz.js'), :line => nil, :content => 'bazjscontent' }
    ])
  end
  
  it "should aggregate files into multiple subpaths" do
    set_files(<<-EOM, { 'bar.js' => 'barjscontent', 'baz.js' => 'bazjscontent' })
javascripts:
- foo:
  - bar
  - baz
- quux:
  - bar
EOM

    aggregator = make

    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo', 'quux' ], :file => content_file('bar.js'), :line => nil, :content => 'barjscontent' },
      { :target_subpaths => [ 'foo' ], :file => content_file('baz.js'), :line => nil, :content => 'bazjscontent' }
    ])
    check_fragments(aggregator, 'quux', [
      { :target_subpaths => [ 'foo', 'quux' ], :file => content_file('bar.js'), :line => nil, :content => 'barjscontent' }
    ])
  end
  
  it "should add no data if the file doesn't exist" do
    @filesystem_impl.set_does_not_exist("/foo/bar/nonexistent.yo", true)
    aggregator = make("/foo/bar/nonexistent.yo")
    fragments_from(aggregator, 'foo').should be_empty
    fragments_from(aggregator, 'bar').should be_empty
  end
  
  it "should add data if the file suddenly exists, and remove it if it gets deleted again" do
    @yaml_file = File.join(@base_dir, "nonexistent.yaml")
    @filesystem_impl.set_does_not_exist(@yaml_file, true)
    aggregator = make(@yaml_file)
    fragments_from(aggregator, 'foo').should be_empty
    fragments_from(aggregator, 'bar').should be_empty
    
    set_files(<<-EOM, { 'bar.js' => 'barjscontent', 'baz.js' => 'bazjscontent' })
javascripts:
- foo:
  - bar
  - baz
EOM
    
    @filesystem_impl.set_does_not_exist(@yaml_file, false)
    aggregator.refresh!
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => content_file('bar.js'), :line => nil, :content => 'barjscontent' },
      { :target_subpaths => [ 'foo' ], :file => content_file('baz.js'), :line => nil, :content => 'bazjscontent' }
    ])
    
    @filesystem_impl.set_does_not_exist(@yaml_file, true)
    aggregator.refresh!
    fragments_from(aggregator, 'foo').should be_empty
    fragments_from(aggregator, 'bar').should be_empty
  end
  
  it "should raise if given a subpath_definition_proc" do
    lambda { make { |foo| "bar" } }.should raise_error
  end
  
  it "should obey the component_source_proc" do
    component_source_proc = lambda { |yaml_key, filename| "/csp/y#{yaml_key}z/a#{filename}.qjsx" }
    aggregator = make(nil, component_source_proc)
    
    set_files(<<-EOM, { '/csp/yjavascriptsz/abar.qjsx' => 'barjscontent', '/csp/yjavascriptsz/abaz.qjsx' => 'bazjscontent' })
javascripts:
- foo:
  - bar
  - baz
EOM
    
    check_fragments(aggregator, 'foo', [
      { :target_subpaths => [ 'foo' ], :file => '/csp/yjavascriptsz/abar.qjsx', :line => nil, :content => 'barjscontent' },
      { :target_subpaths => [ 'foo' ], :file => '/csp/yjavascriptsz/abaz.qjsx', :line => nil, :content => 'bazjscontent' }
    ])
  end
  
  it "should turn itself into a reasonable string" do
    make.to_s.should match(/asset_packager_compatibility.*asset_packages.yml/i)
  end
  
  it "should include the mtime of the asset-package YML file in max_mtime_for, and change it on #refresh" do
    set_files(<<-EOM, { 'bar.js' => 'barjscontent', 'baz.js' => 'bazjscontent' })
javascripts:
- foo:
  - bar
  - baz
EOM
    aggregator = make
    base = Time.now.to_i
    @filesystem_impl.set_mtime(File.join(@base_dir, *%w{public javascripts bar.js}), Time.at(base - 10_000))
    @filesystem_impl.set_mtime(File.join(@base_dir, *%w{public javascripts baz.js}), Time.at(base - 12_000))
    @filesystem_impl.set_mtime(File.join(@base_dir, *%w{config asset_packages.yml}), Time.at(base - 11_000))
    aggregator.max_mtime_for('foo').to_i.should == base - 10_000

    @filesystem_impl.set_mtime(File.join(@base_dir, *%w{config asset_packages.yml}), Time.at(base - 9_000))
    aggregator.max_mtime_for('foo').to_i.should == base - 10_000
    aggregator.refresh!
    aggregator.max_mtime_for('foo').to_i.should == base - 9_000
  end
  
  it "should return fragments in the right order" do
    order = %w{bar baz quux}.shuffle
    
    descrip = "javascripts:\n- foo:\n"
    order.each { |o| descrip << "  - #{o}\n" }
    set_files(descrip, { 'bar.js' => 'barjscontent', 'baz.js' => 'bazjscontent', 'quux.js' => 'quuxjscontent' })
    aggregator = make
    
    fragments_array = [ ]
    order.each { |o| fragments_array << { :target_subpaths => [ 'foo' ], :file => content_file("#{o}.js"), :line => nil, :content => "#{o}jscontent" } }
    check_fragments(aggregator, 'foo', fragments_array)
  end
  
  it "should have no fragments if there's no match with the aggregate file" do
    set_files(<<-EOM, { })
somethingorother:
- foo:
  - bar
  - baz
EOM
    aggregator = make
    aggregator.all_subpaths.should be_empty
  end

  it "should blow up if there's a syntax error in the YAML file" do
    set_files(<<-EOM, { })
:::/ei9304i4$*()<<><F*
EOM
    lambda { make.all_subpaths }.should raise_error
  end
end
