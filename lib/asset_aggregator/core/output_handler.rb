module AssetAggregator
  module Core
    # An #OutputHandler is instantiated in the #content_for method of #AggregateType.
    # It then gets various calls as #Aggregator objects and #Fragment objects are
    # processed; finally, the result of its #text method is used to return the final,
    # aggregated data.
    class OutputHandler
      # Creates a new instance. +aggregate_type+ is the #AggregateType object that
      # we're outputting content for, and +subpath+ is the (#String) subpath that
      # we're outputting content for. Note that +subpath+ can actually be the filename
      # (with +Rails.root+ stripped off, if present) of a #Fragment, in the case
      # where we're outputting a single fragment (used in development mode when
      # requested).
      def initialize(aggregate_type, subpath, options)
        @aggregate_type = aggregate_type
        @subpath = subpath
        @options = options
        
        @out = StringIO.new
      end
      
      # Called once, at the very beginning of output.
      def start_all
        # nothing here
      end
      
      # Called when we start outputting content for each #Aggregator. An #Aggregator
      # will have one or more #Fragment objects that are output inside it.
      def start_aggregator(aggregator)
        # nothing here
      end
      
      # Called when we start outputting content for a #Fragment.
      def start_fragment(aggregator, fragment)
        # nothing here
      end
      
      # Called to output the content of a #Fragment itself. +content+ is the raw,
      # verbatim content of the #Fragment from wherever it came from.
      def fragment_content(aggregator, fragment, content)
        output content
      end
      
      # Called when we're finished outputting a #Fragment.
      def end_fragment(aggregator, fragment)
        # nothing here
      end
      
      # Called in between #Fragment objects, when multiple #Fragment objects are
      # being output for a single #Aggregator. +last_fragment+ is the #Fragment
      # that we just output, and +fragment+ is the one we're about to output.
      def separate_fragments(aggregator, last_fragment, fragment)
        output "\n\n"
      end
      
      # Called when we're ending the output of an #Aggregator.
      def end_aggregator(aggregator)
        # nothing here
      end
      
      # Called to separate two #Aggregator objects, when multiple #Aggreagtor objects
      # are being output for the same subpath for the same #AggregateType.
      def separate_aggregators(last_aggregator, aggregator)
        output "\n\n"
      end
      
      # Called once, at the very end of output.
      def end_all
        # nothing here
      end
      
      # Should return the text output of this #OutputHandler. Will only get called
      # once, after any and all of the previous methods that will be called are called.
      def text
        @out.string
      end
      
      private
      attr_reader :aggregate_type, :subpath, :options
      
      # Outputs the given string to the in-memory #StringIO object that we're
      # building up, using the same semantics as #puts.
      def output(s)
        @out.puts(s)
      end
    end
  end
end
