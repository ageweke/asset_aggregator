module AssetAggregator
  module Core
    # An #AggregateReference represents a reference from somewhere in your code
    # to an *explicit* aggregate -- that is, rather than saying "I need to include
    # whatever aggregate fragment F would up in", you're saying "I need to include
    # aggregate foo/bar, period".
    #
    # In general, you don't want to do this -- part of the whole point of the
    # AssetAggregator is that you should tell it which fragments you need, and
    # let the aggregate definitions worry about where the fragments end up.
    # But, if you need it, it's there.
    class AggregateReference
      include Comparable
      
      attr_reader :aggregate_type, :subpath, :reference_source_position, :descrip
      
      # Creates a new instance. +aggregate_type+ is the aggregate type (a Symbol);
      # +subpath+ is the explicit subpath you're referring to, without extension
      # or prefix (e.g., +foo/bar+). +reference_source_position+ is the
      # #SourcePosition object that shows where in your code this reference is
      # coming from; +descrip+ is a textual description that can be emitted in
      # comments.
      def initialize(aggregate_type, subpath, reference_source_position, descrip)
        @aggregate_type = aggregate_type
        @subpath = subpath
        @reference_source_position = reference_source_position
        @descrip = descrip
      end
      
      # Compares two #AggregateReference objects. Also compares against
      # #FragmentReference objects; compares alphabetically by aggregate type
      # in that case, and then puts all #AggregateReference objects after all
      # #FragmentReference objects of the same +aggregate_type+. Among
      # #AggregateReference objects, they're compared by aggregate type, then
      # subpath, then reference source position. +descrip+ is intentionally
      # ignored.
      def <=>(other)
        out = (aggregate_type.to_s <=> other.aggregate_type.to_s)
        out = 1 if out == 0 && other.kind_of?(AssetAggregator::Core::FragmentReference)
        out = (subpath <=> other.subpath) if out == 0
        out = (reference_source_position <=> other.reference_source_position) if out == 0
        out
      end
      
      # Returns the subpath that this reference refers to. This is present to
      # make it compatible with #FragmentReference, which does considerably
      # more work to implement this method.
      def aggregate_subpath(asset_aggregator)
        subpath
      end
      
      # Returns a nice string, so that we can put this in comments, etc.
      def to_s
        "#{@aggregate_type} reference: #{@reference_source_position} explicitly refers to aggregate '#{@subpath}' (#{descrip})"
      end
    end
  end
end
