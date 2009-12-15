module AssetAggregator
  module Rails
    module AggregatedController
      def self.included(other)
        AssetAggregator.all_types.each do |asset_type|
          other.send(:define_method, asset_type) do
            serve(asset_type, params)
          end
        end
        
        other.send(:before_filter, :refresh_if_in_development)
      end
      
      private
      def refresh_if_in_development
        AssetAggregator.refresh! if ::Rails.env.development?
      end
      
      def mime_type_for_asset_type(asset_type)
        case asset_type
        when :javascript then 'text/javascript'
        when :css then 'text/css'
        else 'text/plain'
        end
      end
      
      def serve(asset_type, params)
        subpath = params[:path]
        
        content = AssetAggregator.content_for(asset_type, subpath) unless subpath.blank?
        if content
          render :text => content, :content_type => mime_type_for_asset_type(asset_type)
        else
          if ::Rails.env.development?
            message = "No content found for asset type #{asset_type.inspect}, subpath #{subpath.inspect}; I have the following subpaths for this type: #{AssetAggregator.all_subpaths(asset_type).inspect}"
          else
            message = "No content found."
          end
          
          render :text => message, :status => :not_found
        end
      end
    end
  end
end
