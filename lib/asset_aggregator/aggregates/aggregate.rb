module AssetAggregator
  module Aggregates
    class Aggregate
      attr_reader :subpath
      
      def initialize(aggregate_type, file_cache, subpath, definition_proc)
        @aggregate_type = aggregate_type
        @file_cache = file_cache
        @subpath = subpath
        @aggregators = [ ]
        
        instance_eval(&definition_proc)
      end
      
      def refresh!
        @aggregators.each { |aggregator| aggregator.refresh! }
      end
      
      def content
        @aggregate_type.content_for(self, @aggregators)
      end
      
      private
      def filter_with(filter_name, *args)
        the_filter = if filter_name.kind_of?(Symbol) || filter_name.kind_of?(String)
          "AssetAggregator::Filters::#{filter_name.to_s.camelize}Filter".constantize.new(*args)
        elsif filter_name.kind_of?(Class)
          filter_name.new(*args)
        elsif (! filter_name.respond_to?(:filter))
          raise "You passed something that isn't a String, Symbol, or Class, but it doesn't respond to :filter"
        elsif (! args.empty?)
          raise "You need to pass a symbol (for a predefined filter) or a class if you want to pass arguments to the filter" unless args.empty?
        else
          filter_name
        end
        
        Thread.current[:filters] ||= [ ]
        old_filters = Thread.current[:filters]
        begin
          # We add it to the start, so that this:
          #
          #   filter_with :foo do
          #     filter_with :bar do
          #       ...
          #     end
          #   end
          #
          # applies bar first, then foo.
          Thread.current[:filters] = [ the_filter ] + Thread.current[:filters]
          yield
        ensure
          Thread.current[:filters] = old_filters
        end
      end
      
      def add(aggregator_type, *args)
        klass = "AssetAggregator::Aggregates::#{aggregator_type.to_s.camelize}Aggregator".constantize
        filters = Thread.current[:filters] || [ ]
        args = [ AssetAggregator::Fragments::FragmentSet.new, @file_cache, filters, @subpath ] + args
        @aggregators << klass.new(*args)
      end
    end
  end
end
