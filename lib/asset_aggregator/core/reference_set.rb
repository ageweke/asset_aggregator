module AssetAggregator
  module Core
    # A #ReferenceSet is a collection of #FragmentReference objects. It's used
    # to implement reference tracking on a per-page basis: a single instance of
    # this class (actually, #FreezableReferenceSet) is created and added to the
    # #ApplicationController on each request. As controller methods are called
    # and views are rendered, references can be added to this object -- either
    # explicitly, or implicitly, in cases where +foo.html.erb+ is set to
    # automatically pick up, for example, +foo.js+ and +foo.css+. 
    #
    # When the page is complete, the layout calls +each_aggregate_reference+,
    # which yields each asset subpath required by the page, along with an #Array
    # of references to it. This can be used to output all the subpaths that
    # are needed for the page, automatically, along with (if desired) a list of
    # references to fragments that are aggregated in that subpath (i.e., why
    # that subpath is required).
    class ReferenceSet
      # Creates a new, empty instance.
      def initialize
        @references = [ ]
      end
      
      # Adds the given reference. Duplicate references will be silently ignored.
      def add(reference)
        @references << reference unless @references.include?(reference)
      end
      
      # Yields, in turn, both a subpath (a #String) and an #Array of all #FragmentReference
      # objects added to this set that refer to content that's aggregated under that
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
          subpath = asset_aggregator.aggregated_subpath_for(aggregate_type_symbol, reference.fragment_source_position)
          unless subpath
            raise %{You declared a reference,
#{reference},
that points to a fragment,
#{reference.fragment_source_position},
that isn't actually aggregated by the AssetAggregator!

You'll need to change your AssetAggregator configuration so that data in
#{reference.fragment_source_position}
is aggregated, so that when you declare this reference, we know what
aggregate we need to include.}
          end
          
          subpath_to_reference_map[subpath] ||= [ ]
          subpath_to_reference_map[subpath] << reference
        end
        
        subpath_to_reference_map.keys.sort.each { |k| block.call(k, subpath_to_reference_map[k]) }
      end
    end
  end
end
