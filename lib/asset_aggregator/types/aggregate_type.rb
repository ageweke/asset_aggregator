require 'stringio'

module AssetAggregator
  module Types
    class AggregateType
      attr_reader :type
      
      def initialize(type, file_cache, output_handler, definition_proc)
        @type = type
        @file_cache = file_cache
        @output_handler_class = output_handler_class
        @aggregators = [ ]
        
        instance_eval(&definition_proc)
      end
      
      def add(aggregator_name, *args)
        filters = Thread.current[:filters] || [ ]
        args = [ @file_cache, filters ] + args
        
        aggregator = if aggregator_name.kind_of?(String) || aggregate_name.kind_of?(Symbol)
          "AssetAggregator::Aggregators::#{aggregator_name.to_s.camelize}Aggregator".constantize.new(args)
        elsif aggregator_name.kind_of?(Class)
          aggregate_name.new(args)
        else
          raise "Unknown Aggregator type #{aggregator_name.inspect}"
        end
        
        @aggregators << aggregator
      end
      
      def all_subpaths
        out = @aggregators.inject([ ]) { |out, agg| out | agg.all_subpaths }
        out.uniq
      end
      
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
        
        Thread.current[:asset_aggregator_filters] ||= [ ]
        old_filters = Thread.current[:asset_aggregator_filters]
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
          Thread.current[:asset_aggregator_filters] = [ the_filter ] + Thread.current[:asset_aggregator_filters]
          yield
        ensure
          Thread.current[:asset_aggregator_filters] = old_filters
        end
      end
      
      def content_for(subpath)
        out = StringIO.new
        found_content = false
        
        output_handler = @output_handler_class.new(self, subpath)
        
        output_handler.start_all
        @aggregators.each do |aggregator|
          output_handler.start_aggregator(aggregator)
          
          last_fragment = nil
          aggregator.each_fragment_for(subpath) do |fragment|
            output_handler.separate_fragments(aggregator, last_fragment, fragment) if last_fragment
            last_fragment = fragment
            
            output_handler.start_fragment(aggregator, fragment)
            fragment_content = aggregator.filtered_content_from(fragment)
            output_handler.fragment_content(aggregator, fragment, fragment_content)
            found_content = true
            output_handler.end_fragment(aggregator, fragment)
          end
          
          output_handler.end_aggregator(aggregator)
        end
        
        output_handler.text if found_content
      end
      
      def refresh!
        @aggregators.each { |aggregator| aggregator.refresh! }
      end
    end
  end
end
