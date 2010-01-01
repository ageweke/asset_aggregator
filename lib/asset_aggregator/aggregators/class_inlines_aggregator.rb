module AssetAggregator
  module Aggregators
    class ClassInlinesAggregator < AssetAggregator::Core::Aggregator
      def initialize(aggregate_type, file_cache, filters, root, extension_to_method_names_map = nil, file_to_class_proc = nil, &subpath_definition_proc)
        super(aggregate_type, file_cache, filters)
        @extension_to_method_names_map = extension_to_method_names_map
        @extension_to_method_names_map ||= begin
          method_name = case aggregate_type.type
          when :javascript then :aggregated_javascript
          when :css then :aggregated_css
          else
            raise "Unknown method name for type #{aggregate_type.type.inspect}"
          end
          { 'rb' => [ method_name ] }
        end
        @root = File.expand_path(root)
        @filesystem_impl = AssetAggregator::Core::FilesystemImpl.new
        @subpath_definition_proc = subpath_definition_proc || method(:default_subpath_definition)
        @file_to_class_proc = file_to_class_proc || method(:default_file_to_class)
      end

      def to_s
        ":class_inlines, \'#{AssetAggregator::Core::SourcePosition.trim_rails_root(@root)}\', ..."
      end

      private
      def default_subpath_definition(file, content)
        file = @filesystem_impl.canonical_path(file)
        rails_root_canonical = @filesystem_impl.canonical_path(::Rails.root)
        
        out = File.basename(file)
        out = $1 if out =~ /^([^\.]+)\./
        
        if file[0..(::Rails.root.length - 1)] == rails_root_canonical
          file = file[(::Rails.root.length + 1)..-1] 
          components = file.split(File::SEPARATOR).map { |c| c.strip.downcase }
          out = components[2] if components.length > 3 && components[0] == 'app'
        end
        
        out
      end
      
      def default_file_to_class(file_path)
        file_path = file_path[(@root.length + 1)..-1] if file_path[0..(@root.length - 1)].downcase == @root.downcase
        file_path = $1 if file_path =~ /^(.*)\.[^\/]+/
        
        tries = [ file_path, File.join(File.basename(@root), file_path) ].map { |f| f.camelize }
        tries.each do |try|
          klass = begin
            try.constantize
          rescue LoadError => le
            nil
          end
          
          return klass if klass
        end
        
        raise "Can't find class that '#{file_path}' maps to; tried: #{tries.inspect}"
      end
      
      def refresh_fragments_since(last_refresh_fragments_since_time)
        @file_cache.changed_files_since(@root, last_refresh_fragments_since_time).each do |changed_file|
          next if File.basename(changed_file) =~ /^\./ || @filesystem_impl.directory?(changed_file)
          extension = File.extname(changed_file)
          extension = $1 if extension =~ /\.+([^\.]+)$/i
          extension = extension.strip.downcase
          mtime = @filesystem_impl.mtime(changed_file)
          
          methods = @extension_to_method_names_map[extension]
          if methods
            methods = Array(methods)
            fragment_set.remove_all_for_file(changed_file)
            
            if @filesystem_impl.exist?(changed_file)
              klass = default_file_to_class(changed_file)
              methods.each do |method|
                next unless klass.respond_to?(method)
                (klass.send(method) || [ ]).each do |(content, line_number)|
                  target_subpaths = @subpath_definition_proc.call(changed_file, content)
                  source_position = AssetAggregator::Core::SourcePosition.new(changed_file, line_number)
                  fragment = AssetAggregator::Core::Fragment.new(target_subpaths, source_position, content, mtime)
                  fragment_set.add(fragment)
                end
              end
            end
          end
        end
      end
    end
  end
end
