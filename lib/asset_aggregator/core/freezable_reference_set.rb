module AssetAggregator
  module Core
    # A #FreezableReferenceSet is a #ReferenceSet that knows when its data has
    # been used, and will blow up or warn you when you're adding a reference
    # after its data has already been used. 
    #
    # This is useful because it's possible -- not common, but possible -- for
    # you to add references to assets after we've already rendered the code in
    # the page's <head> that links to the assets we need. In such a situation,
    # we look to see if someone else has already linked to the #Fragment
    # requested. If so, we print a warning message (as your page is correct,
    # but you're doing something dangerous); if not, we raise an exception,
    # because your page may well be completely incorrect.
    class FreezableReferenceSet < ReferenceSet
      # Creates a new, empty instance.
      def initialize(integration)
        super(integration)
        @frozen_types = [ ]
      end
      
      # Adds a reference. If the +aggregate_type+ of the reference has not already
      # been passed to #each_aggregate_reference, all is well. Otherwise, we look
      # to see if someone else has already added a reference to the exact same
      # #Fragment already. If so, we issue a warning and carry on; if not, we raise
      # an exception.
      def add(reference)
        if @frozen_types.include?(reference.aggregate_type)
          if @references.detect { |r| r.aggregate_type == reference.aggregate_type && r.fragment_source_position == reference.fragment_source_position }
            integration.warn %{Warning: You're trying to add a reference to an asset, but we've
already output the actual include tags (e.g., <script source="...">) for
this type of asset. This can occur when you've added a CSS or JavaScript
file for a partial that gets rendered by the layout itself, *after*
the code that outputs the required JavaScript or CSS tags.

This is actually OK in this case, because someone has already declared
an equivalent reference to
#{reference.fragment_source_position}
before we rendered the include tags for this asset type. But be careful.

This is happening at:
#{caller.join("\n")}}
          else
            raise %{You're trying to add a reference to an asset, but we've
already output the actual include tags (e.g., <script source="...">) for
this type of asset. This can occur when you've added a CSS or JavaScript
file for a partial that gets rendered by the layout itself, *after*
the code that outputs the required JavaScript or CSS tags.

You tried to add the following reference:
#{reference}

...which got added, explicitly or implicitly, at wherever this stack
trace is coming from.

One solution to this is to explicitly add a reference to
#{reference.fragment_source_position}
at some point above where we output the actual include tags for 
#{reference.aggregate_type.inspect} assets.}
          end
        end
        
        super(reference)
      end
      
      def each_aggregate_reference(aggregate_type_symbol, asset_aggregator, &block)
        super(aggregate_type_symbol, asset_aggregator, &block)
        @frozen_types |= [ aggregate_type_symbol ]
      end
    end
  end
end
