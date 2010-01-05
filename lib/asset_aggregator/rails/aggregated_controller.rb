module AssetAggregator
  module Rails
    module AggregatedController
      def self.included(other)
        AssetAggregator.all_types.each do |asset_type|
          other.send(:define_method, asset_type) do
            serve(asset_type, params)
          end
          
          other.send(:define_method, "#{asset_type}_fragment") do
            serve_fragment(asset_type, params)
          end
        end
        
        other.send(:before_filter, :refresh_if_necessary)
      end
      
      private
      def refresh_if_necessary
        AssetAggregator.refresh! if AssetAggregator.refresh_on_each_request
      end
      
      def mime_type_for_asset_type(asset_type)
        case asset_type
        when :javascript then 'text/javascript'
        when :css then 'text/css'
        else 'text/plain'
        end
      end
      
      def serve_fragment(asset_type, params)
        source_file = subpath
        source_line = nil
        
        if source_file =~ /^(.*):\s*(\d+)\s*$/i
          source_file = $1
          source_line = $2.to_i
        end
        
        source_file = [ source_file, "#{source_file}.#{params[:format]}", File.join(::Rails.root, source_file),
          "#{File.join(::Rails.root, source_file)}.#{params[:format]}" ].detect { |f| File.exist?(f) }
        
        content = nil
        if source_file
          source_position = AssetAggregator::Core::SourcePosition.new(source_file, source_line)
          content = AssetAggregator.fragment_content_for(asset_type, source_position)
        end
        
        if content
          render :text => content, :content_type => mime_type_for_asset_type(asset_type)
        else
          fragment_not_found(asset_type, source_position)
        end
      end
      
      def fragment_not_found(asset_type, source_position)
        if ::Rails.env.development?
          message = "No content found for asset type #{asset_type.inspect}, fragment source position #{source_position}"
        else
          message = "No content found."
        end
        
        render :text => message, :status => :not_found
      end
      
      def subpath_not_found(asset_type, subpath)
        if ::Rails.env.development?
          message = "No content found for asset type #{asset_type.inspect}, subpath #{subpath.inspect}; I have the following subpaths for this type: #{AssetAggregator.all_subpaths(asset_type).inspect}"
        else
          message = "No content found."
        end
        
        render :text => message, :status => :not_found
      end
      
      def subpath
        @subpath ||= begin
          out = params[:path]
          out = out.join("/") if out.kind_of?(Array)
          raise "No path specified (with :path)" if out.blank?
          out
        end
      end
      
      def serve(asset_type, params)
        content = AssetAggregator.content_for(asset_type, subpath) unless subpath.blank?
        if content
          render :text => content, :content_type => mime_type_for_asset_type(asset_type)
        else
          subpath_not_found(asset_type, subpath)
        end
      end
    end
  end
end
