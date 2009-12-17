module AssetAggregator
  module Rails
    module PerRequestReferenceSet
      class << self
        def included(other)
          other.send(:helper_method, :asset_aggregator_page_reference_set)
          other.send(:helper_method, :asset_aggregator_page_references_text)
        end
      end
      
      def create_asset_aggregator_page_reference_set
        AssetAggregator::Rails::PageReferenceSet.new
      end
      
      def asset_aggregator_page_reference_set
        @asset_aggregator_page_reference_set ||= create_asset_aggregator_page_reference_set
      end
      
      def asset_aggregator_page_references_text(view, options = { })
        asset_aggregator_page_reference_set.include_text(view, options)
      end
    end
  end
end
