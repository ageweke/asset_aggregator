module AssetAggregator
  module Aggregators
    # The #AssetPackagerCompatibilityAggregator is an #Aggregator that mimics quite
    # closely the behavior of the Asset Packager; see
    # http://synthesis.sbecker.net/pages/asset_packager for more details. Basically,
    # there's a YAML file at +config/asset_packages.yml+ that maps subpaths to 
    # sets of files under +public/+. It's the original inspiration for the
    # #AssetAggregator; it does some of the same things, but in a much less dynamic
    # fashion.
    #
    # This #Aggregator is smart enough to not only re-read packaged files when they
    # change, but also to re-read the actual asset-packager YAML file when it changes,
    # too.
    class AssetPackagerCompatibilityAggregator < AssetAggregator::Core::Aggregator
      require 'yaml'
      require 'stringio'
      
      # Creates a new instance. +asset_packager_yml_file+ specifies the YAML file of
      # assets to aggregate; it defaults to +config/asset_packages.yml+, as per the
      # asset packager.
      def initialize(aggregate_type, file_cache, filters, asset_packager_yml_file = nil)
        super(aggregate_type, file_cache, filters)
        @asset_packager_yml_file = asset_packager_yml_file || File.join(::Rails.root, 'config', 'asset_packages.yml')
        raise Errno::ENOENT, "No asset-packager YML file found at '#{@asset_packager_yml_file}'" unless @filesystem_impl.exist?(@asset_packager_yml_file)
      end
      
      # A nice human-readable string.
      def to_s
        ":asset_packager_compatibility, '#{AssetAggregator::Core::SourcePosition.trim_rails_root(@asset_packager_yml_file)}'"
      end
      
      # Overrides the superclass method, incorporating the modification time of the
      # asset-package YAML file itself. Used to generate cache-busting URLs -- if
      # the asset-package YAML file itself changes, we have to consider each subpath
      # changed, too.
      def max_mtime_for(subpath)
        times = [ super(subpath) ]
        times << @asset_packager_yml_file_mtime.to_i if @asset_packager_yml_file_mtime
        times.compact.max
      end
      
      private
      # The proc that lets us sort #Fragment objects for output. We use the 
      # @subpath_to_fragment_order_map that we maintain.
      def fragment_sorting_proc(subpath)
        Proc.new do |fragments|
          fragments.sort_by { |f| @subpath_to_fragment_order_map[subpath].index(f.source_position.file) }
        end
      end
      
      # The mapping from our own #AggregateType to the extensions of files we generate.
      AGGREGATE_TYPE_TO_EXTENSION_MAP = { :javascript => 'js', :css => 'css' }
      # The mapping from our own #AggregateType to the YAML key we look under in the asset-packager
      # YAML file.
      AGGREGATE_TYPE_TO_YAML_KEY_MAP  = { :javascript => 'javascripts', :css => 'stylesheets' }

      # Returns the extension we should use for aggregated files.
      def extension
        AGGREGATE_TYPE_TO_EXTENSION_MAP[aggregate_type_symbol] || raise("#{self.class.name} doesn't know about aggregate type #{aggregate_type_symbol.inspect} yet; it only knows about #{AGGREGATE_TYPE_TO_EXTENSION_MAP.keys.inspect}")
      end

      # Returns the YAML key we should look under in the asset-packager YAML file.
      def yaml_key
        AGGREGATE_TYPE_TO_YAML_KEY_MAP[aggregate_type_symbol] || raise("#{self.class.name} doesn't know about aggregate type #{aggregate_type_symbol.inspect} yet; it only knows about #{AGGREGATE_TYPE_TO_YAML_KEY_MAP.keys.inspect}")
      end
      
      # Looks at the asset-packager YAML file. If it's changed since the last time we 
      # refreshed, dumps absolutely everything, and rereads absolutely everything, from scratch.
      # If it hasn't, then rereads just the files we reference that have changed.
      #
      # Note that we don't use the file cache here, because it's typically much more efficient
      # to just call #mtime on the (relatively) few files we're aggregating, rather than
      # hitting an entire tree for just this reason.
      def refresh_fragments_since(last_refresh_fragments_since_time)
        complete_refresh = false
        
        @asset_packager_yml_file_mtime = @filesystem_impl.mtime(@asset_packager_yml_file)
        if (! @fragment_source_file_to_subpaths_map) || (@filesystem_impl.exist?(@asset_packager_yml_file) && @asset_packager_yml_file_mtime >= Time.at(last_refresh_fragments_since_time.to_i))
          fragment_set.remove_all!
          complete_refresh = true
          read_fragment_source_file_to_subpaths_map
        end

        @fragment_source_file_to_subpaths_map.each do |fragment_source_file, subpaths|
          if complete_refresh || (! last_refresh_fragments_since_time) || (! @filesystem_impl.exist?(fragment_source_file)) || (@filesystem_impl.mtime(fragment_source_file) >= last_refresh_fragments_since_time)
            fragment_set.remove_all_for_file(fragment_source_file) unless complete_refresh
            if @filesystem_impl.exist?(fragment_source_file)
              fragment_set.add(AssetAggregator::Core::Fragment.new(subpaths, AssetAggregator::Core::SourcePosition.new(fragment_source_file, nil), @filesystem_impl.read(fragment_source_file), @filesystem_impl.mtime(fragment_source_file)))
            end
          end
        end
      end
      
      # Reads or re-reads the asset-packager YAML file. Stashes its results into
      # +@fragment_source_file_to_subpaths_map+, which maps each source file to the set
      # of subpaths it appears in (since the asset-packager YAML file can make a given
      # #Fragment appear in multiple subpaths; it's structured as a hash of subpath
      # to #Fragment source file, not the other way around), and into
      # +@subpath_to_fragment_order_map+, which maps each subpath to an array of
      # fragments, in order, that make up that subpath; we use this in the #fragment_sorting_proc,
      # above.
      def read_fragment_source_file_to_subpaths_map
        @fragment_source_file_to_subpaths_map = { }
        @subpath_to_fragment_order_map = { }

        yaml = read_yaml
        this_set = yaml[yaml_key] || [ ]
        this_set.each do |subpath_to_aggregate_files_map|
          subpath_to_aggregate_files_map.each do |subpath, aggregate_files|
            @subpath_to_fragment_order_map[subpath] = [ ]
            
            aggregate_files.each do |aggregate_file|
              net_file = File.join(::Rails.root, 'public', yaml_key.to_s, "#{aggregate_file}.#{extension}")
              @fragment_source_file_to_subpaths_map[net_file] ||= [ ]
              @fragment_source_file_to_subpaths_map[net_file] << subpath
              @subpath_to_fragment_order_map[subpath] << net_file
            end
          end
        end
      end
      
      # Reads the YAML from the given +@asset_packager_yml_file+.
      def read_yaml
        YAML.load(StringIO.new(@filesystem_impl.read(@asset_packager_yml_file)))
      end
    end
  end
end
