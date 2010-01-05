module AssetAggregator
  module Rails
    module ControllerMethods
      class << self
        def included(other)
          other.send(:include, AssetAggregator::Rails::Requires)
          other.send(:helper_method, :asset_aggregator_page_reference_set)
        end
      end
      
      def create_asset_aggregator_page_reference_set
        AssetAggregator::Rails::PageReferenceSet.new
      end
      
      def asset_aggregator_page_reference_set
        @asset_aggregator_page_reference_set ||= create_asset_aggregator_page_reference_set
      end
    end
  end
end

ActionView::Base.send(:include, AssetAggregator::Rails::Requires)
ActionView::Base.send(:include, AssetAggregator::Rails::AssetPackagerCompatibilityHelper)
