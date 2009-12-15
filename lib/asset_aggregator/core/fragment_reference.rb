module AssetAggregator
  module Core
    class FragmentReference
      include Comparable
      
      attr_reader :aggregate_type, :fragment_source_position, :reference_source_position, :descrip
      
      def initialize(aggregate_type, fragment_source_position, reference_source_position, descrip)
        @aggregate_type = aggregate_type
        @fragment_source_position = fragment_source_position
        @reference_source_position = reference_source_position
        @descrip = descrip
      end
      
      def <=>(other)
        out = (aggregate_type.to_s <=> other.aggregate_type.to_s)
        out = (fragment_source_position <=> other.fragment_source_position) if out == 0
        out = (reference_source_position <=> other.reference_source_position) if out == 0
        out
      end
      
      def to_s
        "#{@aggregate_type} reference: #{@reference_source_position} refers to #{@fragment_source_position} (#{descrip})"
      end
    end
  end
end
