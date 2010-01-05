module AssetAggregator
  module Rails
    module AssetPackagerCompatibilityHelper
      def javascript_include_merged(*sources)
        merged_tags(sources, method(:javascript_include_tag), :javascript, true)
      end
      
      def stylesheet_link_merged(*sources)
        merged_tags(sources, method(:stylesheet_link_tag), :css, false)
      end
      
      private
      def merged_tags(sources, tag_method, asset_type, expand_sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
        sources = sources.map { |source| expand_source(source) } if expand_sources
        sources = sources.flatten
        
        sources.map do |source|
          mtime = AssetAggregator.mtime_for(asset_type, source.to_s)
          url = AssetAggregator.aggregate_url(method(:url_for), asset_type, source.to_s)
          if url =~ /\?/
            url += "&_aamt=#{mtime.to_i}"
          else
            url += "?#{mtime.to_i}"
          end
          
          tag_method.call(url, options)
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
