module AssetAggregator
  module Core
    class PageReferenceSet
      def initialize(asset_aggregator)
        @asset_aggregator = asset_aggregator
        @reference_set = AssetAggregator::Core::FreezableReferenceSet.new(integration)
      end
      
      def require_fragment(aggregate_type, fragment_file, source_position = nil, descrip = nil)
        descrip ||= "explicit reference"
        source_position ||= AssetAggregator::Core::SourcePosition.levels_up_stack(2)
        
        if fragment_file.kind_of?(String)
          fragment_line = nil
          if fragment_file =~ /^(.*?)\s*:\s*(\d+)\s*$/
            fragment_file = $1
            fragment_line = $2.to_i
          end
          fragment_file = AssetAggregator::Core::SourcePosition.new(integration.path_from_base(fragment_file), fragment_line)
        end
        
        @reference_set.add(AssetAggregator::Core::FragmentReference.new(aggregate_type, fragment_file, source_position, descrip))
      end
      
      def require_aggregate(aggregate_type, aggregate_subpath, source_position = nil, descrip = nil)
        descrip ||= "explicit reference"
        source_position ||= AssetAggregator::Core::SourcePosition.levels_up_stack(2)

        @reference_set.add(AssetAggregator::Core::AggregateReference.new(aggregate_type, aggregate_subpath, source_position, descrip))
      end
      
      def include_text(options = { })
        options = options.dup
        
        types = options.delete(:types) || @reference_set.aggregate_types
        output_handler_class = options.delete(:output_handler_class) || AssetAggregator::Core::PageReferencesOutputHandler
        
        output_handler = output_handler_class.new(asset_aggregator, options)
        output_handler.start_all
        
        types.each do |type_symbol|
          aggregate_type = asset_aggregator.aggregate_type(type_symbol)
          
          subpath_references_pairs_this_type = [ ]
          @reference_set.each_aggregate_reference(type_symbol, asset_aggregator) do |subpath, references|
            subpath_references_pairs_this_type << [ subpath, references ]
          end
          
          output_handler.start_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
          subpath_references_pairs_this_type.each do |(subpath, references)|
            output_handler.aggregate(aggregate_type, subpath, references)
          end
          output_handler.end_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
        end
        
        output_handler.end_all
        output_handler.text
      end
      
      private
      def asset_aggregator
        @asset_aggregator
      end
      
      def integration
        @asset_aggregator.integration
      end
    end
  end
end
