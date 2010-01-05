module AssetAggregator
  module Rails
    module AssetPackagerCompatibilityHelper
      def javascript_include_aggregate(*sources)
        merged_tags(sources, method(:javascript_include_tag), :javascript, true)
      end
      
      alias_method :javascript_include_merged, :javascript_include_aggregate
      
      def stylesheet_link_aggregate(*sources)
        merged_tags(sources, method(:stylesheet_link_tag), :css, false)
      end
      
      alias_method :stylesheet_link_merged, :stylesheet_link_aggregate
      
      private
      def public_directory_for(aggregate_type)
        case aggregate_type
        when :javascript then 'javascripts'
        when :css then 'stylesheets'
        else raise("Don't know what directory under public/ contains data for type #{aggregate_type.inspect}")
        end
      end
      
      def with_extension(aggregate_type, filename)
        extension = case aggregate_type
        when :javascript then 'js'
        when :css then 'css'
        else raise("Don't know what extension data of type #{aggregate_type.inspect} has")
        end
        
        filename += ".#{extension}" unless filename =~ /\.#{extension}$/i
        filename
      end
      
      def merged_tags(sources, tag_method, aggregate_type, expand_sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
        sources = sources.map { |source| expand_source(source) } if expand_sources
        sources = sources.flatten
        
        available_subpaths = AssetAggregator.all_subpaths(aggregate_type)
        
        sources.map do |source|
          mtime = nil
          mtime = AssetAggregator.mtime_for(aggregate_type, source.to_s) if available_subpaths.include?(source.to_s)
          
          if mtime && mtime > 0
            url = AssetAggregator.aggregate_url(method(:url_for), aggregate_type, source.to_s)
            if url =~ /\?/
              url += "&_aamt=#{mtime.to_i}"
            else
              url += "?#{mtime.to_i}"
            end
          
            tag_method.call(url, options)
          else
            target_file = File.join(::Rails.root, 'public', public_directory_for(aggregate_type), with_extension(aggregate_type, source.to_s))
            if File.exist?(target_file)
              tag_method.call(source.to_s, options)
            else
              raise "You asked to link to #{source.inspect}, but we found neither an aggregate nor a single file under public/ with that name. (We looked for: '#{target_file}')"
            end
          end
        end.join("\n")
      end
      
      def expand_source(source)
        if source == :defaults
          out = %w{prototype effects dragdrop controls}
          application_js = File.join(Rails.root, *%w{public javascripts application.js})
          out << application_js if File.exist?(application_js)
          out
        else
          source
        end
      end
    end
  end
end
