module AssetAggregator
  module Core
    # A #ReferenceSet is a collection of #FragmentReference or #AggregateReference
    # objects. It's used  to implement reference tracking on a per-page basis: a
    # single instance of this class (actually, #FreezableReferenceSet) is created
    # and used by the #PageReferenceSet on each request. As controller methods are
    # called and views are rendered, references can be added to this object -- 
    # either explicitly, or implicitly, in cases where +foo.html.erb+ is set to
    # automatically pick up, for example, +foo.js+ and +foo.css+. 
    #
    # When the page is complete, the layout calls +each_aggregate_reference+,
    # which yields each asset subpath required by the page, along with an #Array
    # of references to it. This can be used to output all the subpaths that
    # are needed for the page, automatically, along with (if desired) a list of
    # references to fragments that are aggregated in that subpath (i.e., why
    # that subpath is required).
    #
    # Usually, you'll add #FragmentReference objects to this set. However, there
    # are also #AggregateReference objects, in cases where you explicitly want to
    # require an aggregate rather than a single fragment. This couples code with
    # knowledge of what fragments are ending up in what aggregates, and so is 
    # generally a bad idea, but it's there if you need it.
    class ReferenceSet
      # Creates a new, empty instance.
      def initialize
        @references = [ ]
      end
      
      # Adds the given reference. Duplicate references will be silently ignored.
      def add(reference)
        @references << reference unless @references.include?(reference)
      end
      
      # Returns an array of symbols, which is the set of all distinct aggregate types
      # that this #ReferenceSet has references to in it. This is sorted alphabetically,
      # in order to comply with our "always be deterministic" principle.
      def aggregate_types
        @references.map { |r| r.aggregate_type }.uniq.sort_by { |t| t.to_s }
      end
      
      # Yields, in turn, both a subpath (a #String) and an #Array of all #FragmentReference
      # objects added to this set that refer to content that's aggregated under that
      # subpath, plus all #AggregateReference objects that explicitly refer to that
      # subpath. The +aggregate_type_symbol+ says what kind of content you want;
      # the +asset_aggregator+ is a reference to the top-level #AssetAggregator
      # object itself. (We need this so that we can go ask it where each of the
      # #Fragment objects we've got references to is being aggregated.)
      #
      # Subpaths are always yielded in alphabetical order. This conforms with our
      # guiding principle to always be deterministic about ordering.
      def each_aggregate_reference(aggregate_type_symbol, asset_aggregator, &block)
        subpath_to_reference_map = { }
        
        @references.select { |r| r.aggregate_type == aggregate_type_symbol }.each do |reference|
          # XXX TODO: DO SOMETHING AWESOME TO FIGURE OUT WHAT SUBPATHS ARE POSSIBLE
          subpaths = reference.aggregate_subpaths(asset_aggregator)
          subpaths.each do |subpath|
            subpath_to_reference_map[subpath] ||= [ ]
            subpath_to_reference_map[subpath] << reference
          end
        end
        
        subpath_to_reference_map.keys.sort.each { |k| block.call(k, subpath_to_reference_map[k].sort) }
      end
    end
  end
end
