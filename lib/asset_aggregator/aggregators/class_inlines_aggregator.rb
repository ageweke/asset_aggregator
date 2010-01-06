module AssetAggregator
  module Aggregators
    class ClassInlinesAggregator < AssetAggregator::Core::Aggregator
      def initialize(aggregate_type, file_cache, filters, root, options = { }, &subpath_definition_proc)
        super(aggregate_type, file_cache, filters)
        
        @extension_to_method_names_map = options[:extension_to_method_names_map] || default_extension_to_method_names_map(aggregate_type)
        @file_to_class_proc = options[:file_to_class_proc] || method(:default_file_to_class)
        @class_prefix = options[:class_prefix] || ""
        
        @root = File.expand_path(root)
        @subpath_definition_proc = subpath_definition_proc || method(:default_subpath_definition)
      end

      def to_s
        ":class_inlines, \'#{AssetAggregator::Core::SourcePosition.trim_rails_root(@root)}\', ..."
      end

      private
      def default_extension_to_method_names_map(aggregate_type)
        method_name = case aggregate_type.type
        when :javascript then :aggregated_javascript
        when :css then :aggregated_css
        else
          raise "Unknown default method name for type #{aggregate_type.type.inspect}; you must pass an extension_to_method_names_map"
        end
        
        { 'rb' => [ method_name ] }
      end
      
      def default_file_to_class(file_path)
        full_file_path = file_path.dup
        file_path = file_path[(@root.length + 1)..-1] if file_path[0..(@root.length - 1)].downcase == @root.downcase
        file_path = $1 if file_path =~ /^(.*)\.[^\/]+/
        
        tries = [ file_path, File.join(File.basename(@root), file_path) ].map { |f| @class_prefix + f.camelize }
        tries.each do |try|
          klass = begin
            try.constantize
          rescue LoadError => le
            nil
          rescue Exception => e
            raise %{The AssetAggregator is trying to load the class in the file
'#{full_file_path}',
in order to see if it has assets (e.g., CSS, Javascript, etc.) inline in its code
that need to be aggregated.

We loaded the file, and then tried to load the class named #{try}.
However, this failed. Does the class have a syntax error, is it named wrong,
or some other issue? The exception we got was:

#{e}
#{e.backtrace.join("\n")}

}
          end
          
          return klass if klass
        end
        
        raise "Can't find class that '#{file_path}' maps to; tried: #{tries.inspect}"
      end
      
      def extract_fragments_from_file(file, methods)
        klass = @file_to_class_proc.call(file)
        mtime = @filesystem_impl.mtime(file)
        
        methods.each do |method|
          next unless klass.respond_to?(method)
          (klass.send(method) || [ ]).each do |(content, line_number)|
            raise "You must supply a numeric line number, not #{line_number.inspect}" if line_number && (! line_number.kind_of?(Integer))
            
            target_subpaths = @subpath_definition_proc.call(file, content)
            source_position = AssetAggregator::Core::SourcePosition.new(file, line_number)
            fragment = AssetAggregator::Core::Fragment.new(target_subpaths, source_position, content, mtime)
            fragment_set.add(fragment)
          end
        end
      end
      
      def refresh_fragments_since(last_refresh_fragments_since_time)
        @file_cache.changed_files_since(@root, last_refresh_fragments_since_time).each do |changed_file|
          next if File.basename(changed_file) =~ /^\./ || @filesystem_impl.directory?(changed_file)
          extension = File.extname(changed_file)
          extension = $1 if extension =~ /\.+([^\.]+)$/i
          extension = extension.strip.downcase
          
          methods = @extension_to_method_names_map[extension]
          if methods
            fragment_set.remove_all_for_file(changed_file)
            extract_fragments_from_file(changed_file, Array(methods)) if @filesystem_impl.exist?(changed_file)
          end
        end
      end
    end
  end
end
