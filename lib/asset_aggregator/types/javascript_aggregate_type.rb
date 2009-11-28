module AssetAggregator
  module Types
    class JavascriptAggregateType < AggregateType
      private
      def write_content_header(aggregate, out)
        out.puts <<-END
/************************************************************************
 * '#{aggregate.subpath}.js'
 *
 * This file is GENERATED by the AssetAggregator; do not edit it.
 * This version was generated at #{Time.now}
 ************************************************************************/
END
      end

      def write_aggregator_header(aggregate, aggregator, out)
        out.puts <<-END


/************************************************************************
 * #{aggregator}
 ************************************************************************/

END
      end
      
      def write_fragment_separator(aggregate, aggregator, out)
        out.puts ""
      end
      
      def write_fragment_header(aggregate, aggregator, fragment, out)
        out.puts <<-END
/* ----------------------------------------------------------------------
   - #{fragment.source_position}
   ---------------------------------------------------------------------- */
END
      end
    end
  end
end
