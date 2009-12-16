module AssetAggregator
  module Core
    # A #FragmentReference represents, well, a reference to a fragment: the fact that
    # a particular source line of code (+reference_source_position+, below) requires
    # a particular #Fragment to be included on the page (or otherwise referenced).
    # The #Fragment is identified by its #SourcePosition (+fragment_source_position+,
    # below). The +aggregate_type+ (a #Symbol) is also included, to disambiguate
    # references to different types of #Fragments.
    #
    # The +descrip+ is informational only; it lets you say things like "implicit
    # reference" (in cases where views implicitly pick up JS or CSS), or whatever
    # else you want.
    #
    # Instances of this class are #Comparable; they compare first on the aggregate type
    # (treated as a String), then the +fragment_source_position+, then the
    # +reference_source_position+. +descrip+ is not taken into account.
    class FragmentReference
      include Comparable
      
      attr_reader :aggregate_type, :fragment_source_position, :reference_source_position, :descrip
      
      # Creates a new reference for an asset of type +aggregate_type+, located at
      # +fragment_source_position+, referred to by code at +reference_source_position+,
      # with the given informational +descrip+ of how the reference came to be.
      def initialize(aggregate_type, fragment_source_position, reference_source_position, descrip)
        @aggregate_type = aggregate_type
        @fragment_source_position = fragment_source_position
        @reference_source_position = reference_source_position
        @descrip = descrip
      end
      
      # Used in conjunction with #Comparable to implement ==, >, <=, etc.
      def <=>(other)
        out = (aggregate_type.to_s <=> other.aggregate_type.to_s)
        out = (fragment_source_position <=> other.fragment_source_position) if out == 0
        out = (reference_source_position <=> other.reference_source_position) if out == 0
        out
      end
      
      # Make a nice #String for this object.
      def to_s
        "#{@aggregate_type} reference: #{@reference_source_position} refers to #{@fragment_source_position} (#{descrip})"
      end
    end
  end
end
