require 'stringio'

module AssetAggregator
  module Types
    class AggregateType
      def initialize(type, file_cache, definition_proc)
        @type = type
        @file_cache = file_cache
        @definition_proc = definition_proc
        @aggregates = { }
      end
      
      def aggregate_for(subpath)
        @aggregates[subpath] ||= AssetAggregator::Aggregates::Aggregate.new(self, @file_cache, subpath, @definition_proc)
      end
      
      def content_for(aggregate, aggregators)
        out = StringIO.new
        
        write_content_header(aggregate, out)
        aggregators.each do |aggregator|
          write_aggregator_header(aggregate, aggregator, out)
          
          index = 0
          aggregator.each_fragment do |fragment|
            write_fragment_separator(aggregate, aggregator, out) unless index == 0
            write_fragment_header(aggregate, aggregator, fragment, out)
            
            fragment_content = aggregator.filtered_content_from(fragment)
            
            write_fragment(aggregate, aggregator, fragment, fragment_content, out)
            index += 1
          end
        end
        
        out.string
      end
      
      def refresh!
        @aggregates.values.each { |aggregate| aggregate.refresh! }
      end
      
      private
      def write_content_header(aggregate, out)
        raise "Must override in #{self.class.name}"
      end

      def write_aggregator_header(aggregate, aggregator, out)
        raise "Must override in #{self.class.name}"
      end
      
      def write_fragment_separator(aggregate, aggregator, out)
        raise "Must override in #{self.class.name}"
      end
      
      def write_fragment_header(aggregate, aggregator, fragment, out)
        raise "Must override in #{self.class.name}"
      end
      
      def write_fragment(aggregate, aggregator, fragment, fragment_content, out)
        out.puts fragment_content
      end
    end
  end
end
