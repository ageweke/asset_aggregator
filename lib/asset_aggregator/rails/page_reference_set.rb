module AssetAggregator
  module Rails
    class PageReferenceSet
      def initialize
        @reference_set = AssetAggregator::Core::FreezableReferenceSet.new
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
          fragment_file = AssetAggregator::Core::SourcePosition.new(normalize_file(fragment_file), fragment_line)
        end
        
        @reference_set.add(AssetAggregator::Core::FragmentReference.new(aggregate_type, fragment_file, source_position, descrip || "#require_fragment call"))
      end
      
      def require_aggregate(aggregate_type, aggregate_subpath, source_position = nil, descrip = nil)
        descrip ||= "explicit reference"
        source_position ||= AssetAggregator::Core::SourcePosition.levels_up_stack(2)

        @reference_set.add(AssetAggregator::Core::AggregateReference.new(aggregate_type, aggregate_subpath, source_position, descrip || "#require_aggregate call"))
      end
      
      def each_aggregate_reference(type_symbol, &block)
        AssetAggregator.each_aggregate_reference_in_set(@reference_set, type_symbol, &block)
      end
      
      def include_text(object_to_call_helper_methods_on, options = { })
        output_handler_class = options[:output_handler_class] || AssetAggregator::Rails::PageReferencesOutputHandler
        output_handler = output_handler_class.new(AssetAggregator.standard_instance, object_to_call_helper_methods_on, options)
        
        output_handler.start_all
        
        @reference_set.aggregate_types.each do |aggregate_type|
          subpath_references_pairs_this_type = [ ]
          AssetAggregator.each_aggregate_reference_in_set(@reference_set, aggregate_type) do |subpath, references|
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
      def normalize_file(file)
        file = File.join(::Rails.root, file) unless file =~ %r{\s*/}
        File.canonical_path(file)
      end
    end
  end
end
