module AssetAggregator
  module Rails
    module Requires
      def asset_aggregator_page_includes(object_to_call_helper_methods_on = self, options = { })
        # We need to do this to make sure our cache-busting URLs have up-to-date mtimes.
        AssetAggregator.refresh! if AssetAggregator.refresh_on_each_request
        asset_aggregator_page_reference_set.include_text(object_to_call_helper_methods_on, options)
      end
      
      def require_fragment(aggregate_type, fragment_file, source_position = nil, descrip = nil)
        asset_aggregator_page_reference_set.require_fragment(aggregate_type, fragment_file, source_position || AssetAggregator::Core::SourcePosition.levels_up_stack(2), descrip)
      end
      
      def require_aggregate(aggregate_type, aggregate_subpath, source_position = nil, descrip = nil)
        asset_aggregator_page_reference_set.require_fragment(aggregate_type, aggregate_subpath, source_position || AssetAggregator::Core::SourcePosition.levels_up_stack(2), descrip)
      end
      
      class << self
        def add_methods_for_type(aggregate_type)
          module_eval <<-END
            def require_#{aggregate_type}_fragment(fragment_file, source_position = nil, descrip = nil)
              require_fragment(:#{aggregate_type}, fragment_file, source_position || AssetAggregator::Core::SourcePosition.levels_up_stack(1), descrip)
            end

            def require_#{aggregate_type}_aggregate(aggregate_subpath, source_position = nil, descrip = nil)
              require_aggregate(:#{aggregate_type}, aggregate_subpath, source_position || AssetAggregator::Core::SourcePosition.levels_up_stack(1), descrip)
            end
          END
        end
      end
      
      [ :javascript, :css ].each { |predefined_type| add_methods_for_type(predefined_type) }
    end
  end
end
