module AssetAggregator
  module References
    class AggregateReference
      include Comparable
      
      attr_reader :referring_source_position, :target_fragment_source_position
      
      def initialize(referring_source_position, target_fragment_source_position)
        @referring_source_position = referring_source_position
        @target_fragment_source_position = target_fragment_source_position
      end
      
      def <=>(other)
        out = (referring_source_position <=> other.referring_source_position)
        out = (target_fragment_source_position <=> other.target_fragment_source_position) if out == 0
        out
      end
    end
  end
end
