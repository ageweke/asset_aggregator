module AssetAggregator
  module OutputHandler
    class OutputHandler
      def initialize(aggregate_type, subpath)
        @aggregate_type = aggregate_type
        @subpath = subpath
        
        @out = StringIO.new
      end
      
      def start_all
        must_override
      end
      
      def start_aggregator(aggregator)
        must_override
      end
      
      def separate_fragments(aggregator, last_fragment, fragment)
        output "\n\n"
      end
      
      def start_fragment(aggregator, fragment)
        must_override
      end
      
      def fragment_content(aggregator, fragment, content)
        output content
      end
      
      def end_fragment(aggregator, fragment)
        # nothing here
      end
      
      def end_aggregator(aggregator)
        # nothing here
      end
      
      def text
        @out.string
      end
      
      private
      attr_reader :aggregate_type, :subpath
      
      def output(s)
        @out.puts(s)
      end
      
      def must_override
        raise "Must override in #{self.class.name}"
      end
    end
  end
end
