module AssetAggregator
  module Rails
    module ControllerMethods
      class << self
        def included(other)
          other.send(:include, AssetAggregator::Rails::Requires)
          other.send(:helper_method, :asset_aggregator_page_reference_set)
          other.send(:before_filter, :asset_aggregator_per_request_refresh)
        end
      end
      
      def create_asset_aggregator_page_reference_set
        AssetAggregator::Rails::PageReferenceSet.new(AssetAggregator.standard_instance)
      end
      
      def asset_aggregator_page_reference_set
        @asset_aggregator_page_reference_set ||= create_asset_aggregator_page_reference_set
      end
      
      def asset_aggregator_per_request_refresh
        AssetAggregator.refresh! if AssetAggregator.refresh_on_each_request
        AssetAggregator.write_aggregated_files if AssetAggregator.keep_aggregates_on_disk_up_to_date?
      end
    end
  end
end

ActionView::Base.send(:include, AssetAggregator::Rails::Requires)
ActionView::Base.send(:include, AssetAggregator::Rails::AssetPackagerCompatibilityHelper)
