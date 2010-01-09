module AssetAggregator
  module Aggregators
    class AssetPackagerCompatibilityAggregator < AssetAggregator::Core::Aggregator
      require 'yaml'

      def initialize(aggregate_type, file_cache, filters, asset_packager_yml_file = nil)
        super(aggregate_type, file_cache, filters)
        @asset_packager_yml_file = asset_packager_yml_file || File.join(::Rails.root, 'config', 'asset_packages.yml')
        raise "No asset-packager YML file found at '#{@asset_packager_yml_file}'" unless File.exist?(@asset_packager_yml_file)
      end

      def to_s
        ":asset_packager_compatibility, '#{AssetAggregator::Core::SourcePosition.trim_rails_root(@asset_packager_yml_file)}'"
      end

      def max_mtime_for(subpath)
        times = [ super(subpath) ]
        times << @asset_packager_yml_file_mtime.to_i if @asset_packager_yml_file_mtime
        times.compact.max
      end
      
      private
      def fragment_sorting_proc(subpath)
        Proc.new do |fragments|
          fragments.sort_by { |f| @subpath_to_fragment_order_map[subpath].index(f.source_position.file) }
        end
      end
      
      AGGREGATE_TYPE_TO_EXTENSION_MAP = { :javascript => 'js', :css => 'css' }
      AGGREGATE_TYPE_TO_YAML_KEY_MAP  = { :javascript => 'javascripts', :css => 'stylesheets' }

      def extension
        AGGREGATE_TYPE_TO_EXTENSION_MAP[aggregate_type_symbol] || raise("#{self.class.name} doesn't know about aggregate type #{aggregate_type_symbol.inspect} yet; it only knows about #{AGGREGATE_TYPE_TO_EXTENSION_MAP.keys.inspect}")
      end

      def yaml_key
        AGGREGATE_TYPE_TO_YAML_KEY_MAP[aggregate_type_symbol] || raise("#{self.class.name} doesn't know about aggregate type #{aggregate_type_symbol.inspect} yet; it only knows about #{AGGREGATE_TYPE_TO_YAML_KEY_MAP.keys.inspect}")
      end
      
      def refresh_fragments_since(last_refresh_fragments_since_time)
        complete_refresh = false
        
        @asset_packager_yml_file_mtime = File.mtime(@asset_packager_yml_file)
        if (! @fragment_source_file_to_subpaths_map) || (File.exist?(@asset_packager_yml_file) && @asset_packager_yml_file_mtime >= Time.at(last_refresh_fragments_since_time.to_i))
          fragment_set.remove_all!
          complete_refresh = true
          read_fragment_source_file_to_subpaths_map
        end

        @fragment_source_file_to_subpaths_map.each do |fragment_source_file, subpaths|
          if complete_refresh || (! last_refresh_fragments_since_time) || (! File.exist?(fragment_source_file)) || (File.mtime(fragment_source_file) >= last_refresh_fragments_since_time)
            fragment_set.remove_all_for_file(fragment_source_file) unless complete_refresh
            if File.exist?(fragment_source_file)
              fragment_set.add(AssetAggregator::Core::Fragment.new(subpaths, AssetAggregator::Core::SourcePosition.new(fragment_source_file, nil), File.read(fragment_source_file), File.mtime(fragment_source_file)))
            end
          end
        end
      end

      def read_fragment_source_file_to_subpaths_map
        @fragment_source_file_to_subpaths_map = { }
        @subpath_to_fragment_order_map = { }

        yaml = read_yaml
        this_set = yaml[yaml_key]
        raise "No YAML for key #{yaml_key.inspect}? Keys: #{yaml.keys.inspect}" unless this_set
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

      def read_yaml
        YAML.load_file(@asset_packager_yml_file)
      end
    end
  end
end
