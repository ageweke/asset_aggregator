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
      DEBUG = false # for debugging the #best_fit algorithm
      
      # Creates a new, empty instance.
      def initialize
        @references = [ ]
      end
      
      # Adds the given reference. Duplicate references will be silently ignored.
      def add(reference)
        unless @references.include?(reference)
          @references << reference
          @subpaths_and_references = nil
        end
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
        @subpaths_and_references ||= begin
          debug "> each_aggregate_reference: computing references for #{aggregate_type_symbol.inspect}"
          needed_references = @references.select { |r| r.aggregate_type == aggregate_type_symbol }
          debug "> each_aggregate_reference: computing references for #{aggregate_type_symbol.inspect}: need #{needed_references.length} references"
          reference_to_subpaths_map = create_reference_to_subpaths_map(needed_references, asset_aggregator)
          debug "> each_aggregate_reference: reference_to_subpaths_map is of size #{reference_to_subpaths_map.size}"
        
          potential_combinations = [ ]
          debug "> each_aggregate_reference: calling needed_subpaths..."
          needed_subpaths(needed_references, reference_to_subpaths_map) { |subpaths| potential_combinations << subpaths.sort }
          debug "> each_aggregate_reference: got #{potential_combinations.length} potential combinations from needed_subpaths"
          potential_combinations = potential_combinations.uniq.sort do |one, two|
            out = one.length <=> two.length
            out = one <=> two if out == 0
            out
          end
          debug "> each_aggregate_reference: got #{potential_combinations.length} potential combinations from needed_subpaths after unique"
        
          debug "Potential combinations of subpaths:"
          potential_combinations.each_with_index do |c,i|
            debug "  #{i}: #{c.inspect}"
          end
        
          used_subpaths = potential_combinations[0]
        
          subpath_to_reference_map = { }
          needed_references.each do |reference|
            subpaths = reference_to_subpaths_map[reference]
            subpaths.each do |subpath|
              subpath_to_reference_map[subpath] ||= [ ]
              subpath_to_reference_map[subpath] << reference
            end
          end
        
          subpaths_and_references = [ ]
          used_subpaths.each { |subpath| subpaths_and_references << [ subpath, subpath_to_reference_map[subpath].sort] }
          subpaths_and_references
        end
        
        subpaths_and_references.each { |(subpath, references)| block.call(subpath, references) }
      end
      
      private
      def debug(s)
        puts s if DEBUG
      end
      
      # Given an #Array of reference objects, returns a #Hash that maps each reference to
      # an #Array of subpaths, any of which will satisfy the given reference. 
      def create_reference_to_subpaths_map(references, asset_aggregator)
        out = { }
        references.each { |r| out[r] = r.aggregate_subpaths(asset_aggregator) }
        out
      end
      
      # Yields #Array objects. Each #Array is a set of distinct subpaths that will, together,
      # include all fragments required by any reference in +references+ -- in other words, computes all
      # permutations of subpaths that will include all fragments required by the +references+.
      # Used by #each_aggregate_reference to find the #Array with the minimum length --
      # in other words, the smallest set of subpaths that will cover all of the fragments
      # required by this #ReferenceSet.
      #
      # +reference_to_subpaths_map+ must be a #Hash that maps each reference to an #Array
      # of subpaths that will each satisfy it. This is passed in because it's fairly expensive
      # to create, and we need it in #each_aggregate_reference, above, too.
      def needed_subpaths(references, reference_to_subpaths_map, &proc)
        # Now, split the references into those that point to a single subpath, vs. those that
        # point to multiple subpaths. While not strictly necessary, this tends to make the
        # following algorithm much more efficient, because many references point to a single
        # subpath, and so we *know* we'll need all those subpaths.
        debug ">> needed_subpaths(#{references.length} references, reference_to_subpaths_map of size #{reference_to_subpaths_map.size}): working..."
        (single_subpath_references, multiple_subpath_references) = references.partition { |r| reference_to_subpaths_map[r].length <= 1 }
        debug ">> needed_subpaths: have #{single_subpath_references.length} references to a single subpath, and #{multiple_subpath_references.length} references to multiple subpaths"
        # These are the subpaths we *know* we'll need.
        required_subpaths = single_subpath_references.inject([ ]) { |required, reference| required | reference_to_subpaths_map[reference] }
        debug ">> needed_subpaths: have #{required_subpaths.length} distinct required subpaths: #{required_subpaths.join(", ")}"
        
        # These are the remaining references that aren't covered by any of the subpaths we
        # *know* we need. This can be empty.
        needed_references = multiple_subpath_references.select { |r| (reference_to_subpaths_map[r] & required_subpaths).empty? }
        debug ">> needed_subpaths: have #{needed_references.length} references remaining that we need"
        
        # Now, call down to our recursive algorithm to go generate potential combinations.
        best_fit(required_subpaths, needed_references, reference_to_subpaths_map, &proc)
      end
      
      # Given a set of subpaths we know we're going to use (+subpaths_so_far+) and a set of
      # references that we have yet to satisfy (i.e., none of them are satisfied by any of the
      # subpaths in +subpaths_so_far+), computes the set of all subpaths that each would
      # satisfy at least one of the +needed_references+. For each subpath in that set,
      # recursively calls itself, adding the subpath to +subpaths_so_far+ and removing the
      # references that subpath satisfies from +needed_references+.
      #
      # If all references are satisfied -- i.e., +needed_references+ is empty -- then calls
      # the supplied block with the +subpaths_so_far+.
      #
      # Taken together, this calls the supplied block with every possible combination of
      # subpaths that will satisfy all the +needed_references+, which is the whole point.
      def best_fit(subpaths_so_far, needed_references, reference_to_subpaths_map, &proc)
        debug ">>> best_fit(subpaths #{subpaths_so_far.inspect}, #{needed_references.length} remaining references needed)"
        if needed_references.empty?
          debug ">>> best_fit: no more references needed, calling block with: #{subpaths_so_far.join(", ")}"
          proc.call(subpaths_so_far)
        else
          # Construct a map of subpath -> references for the remaining references we have...
          subpath_to_reference_map = { }
          needed_references.each do |needed_reference|
            reference_to_subpaths_map[needed_reference].each do |subpath|
              subpath_to_reference_map[subpath] ||= [ ]
              subpath_to_reference_map[subpath] << needed_reference
            end
          end

          debug ">>> best_fit: subpath_to_reference_map has #{subpath_to_reference_map.size} entries; subpaths: #{subpath_to_reference_map.keys.join(", ")}"
          # Now, go through it and pick each subpath in turn, recursing...
          subpath_to_reference_map.each do |subpath, references_covered|
            # BUT: only pick subpaths alphabetically greater than all the subpaths we've tried
            # so far. In other words, only try (aaa, bbb), not also (bbb, aaa). This makes
            # the algorithm hugely faster; we're trying distinct combinations of subsets, not
            # all permutations. All permutations is exponential and makes this run forever
            # very, very fast.
            unless subpaths_so_far.detect { |s| s > subpath }
              debug ">>> best_fit: subpath #{subpath} covers #{references_covered.length} references; recursing..."
              best_fit(subpaths_so_far | [ subpath ], needed_references - references_covered, reference_to_subpaths_map, &proc)
            end
          end
        end
      end
    end
  end
end
