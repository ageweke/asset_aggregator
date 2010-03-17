require 'spec/spec_helper'
require File.dirname(__FILE__) + '/../test_filesystem_impl'
require File.dirname(__FILE__) + '/aggregator_spec_helper_methods'

describe AssetAggregator::Aggregators::AssetPackagerCompatibilityAggregator do
  include AssetAggregator::Aggregators::AggregatorSpecHelperMethods
  
  before :each do
    @aggregate_type = mock(:aggregate_type, :type => :javascript)
    @file_cache = mock(:file_cache)
    @filters = [ ]
    @filesystem_impl = AssetAggregator::TestFilesystemImpl.new
    
    @root = File.join(::Rails.root, 'app', 'views')
  end

  def make(asset_packager_yml_file = nil, &subpath_definition_proc)
    out = AssetAggregator::Aggregators::AssetPackagerCompatibilityAggregator.new(@aggregate_type, @file_cache, @filters, asset_packager_yml_file, &subpath_definition_proc)
    out.filesystem_impl = @filesystem_impl
    out
  end
  
  def default_packages_file
    File.join(::Rails.root, "config", "asset_packages.yml")
  end
  
  def set_files(yaml_content, file_map)
    @filesystem_impl.set_content(default_packages_file, yaml_content)
    file_map.each do |file, content|
      @filesystem_impl.set_content(content_file(file), content)
    end
  end
  
  def content_file(subpath)
    File.join(::Rails.root, 'public', 'javascripts', *subpath)
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
  
  it "should fail if the file doesn't exist" do
    lambda { make("/foo/bar/nonexistent.yo") }.should raise_error(Errno::ENOENT)
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
    @filesystem_impl.set_mtime(File.join(::Rails.root, *%w{public javascripts bar.js}), Time.at(base - 10_000))
    @filesystem_impl.set_mtime(File.join(::Rails.root, *%w{public javascripts baz.js}), Time.at(base - 12_000))
    @filesystem_impl.set_mtime(File.join(::Rails.root, *%w{config asset_packages.yml}), Time.at(base - 11_000))
    aggregator.max_mtime_for('foo').to_i.should == base - 10_000

    @filesystem_impl.set_mtime(File.join(::Rails.root, *%w{config asset_packages.yml}), Time.at(base - 9_000))
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
