module AssetAggregator
  module Core
    class AggregateType
      # An AggregateType represents the aggregation of a particular type of asset --
      # e.g., :javascript or :css -- which is the +type+ parameter. You can actually
      # supply whatever type you want; it is used simply as a top-level parameter
      # to AssetAggregator.content_for(), so that you can have the same subpath with
      # different kinds of aggregated content.
      #
      # +file_cache+ is the #FileCache object that should be used, which is typically
      # global to the #AssetAggregator (so as to achieve maximum caching effect).
      # +output_handler+ is the #OutputHandler instance to be used with this type;
      # this defines the literal representation of combined assets -- i.e., how we
      # put fragments together with content to make a text string that the browser
      # can read. +definition_proc+ gets run in the context of this object; it is
      # what calls some combination of #add and #filter_with so that the right
      # #Aggregator objects get added to this type.
      def initialize(type, file_cache, output_handler_class, definition_proc)
        @type = type
        @file_cache = file_cache
        @output_handler_class = output_handler_class
        @aggregators = [ ]
        
        instance_eval(&definition_proc)
      end
      
      # Tells this #AggregateType to go out and refresh its #Aggregators -- this
      # typically means looking at the disk again to see if files they use have changed,
      # and, if so, re-reading them. Note that this does NOT call #refresh! on the
      # #FileCache, because you want to do that once, not once per #AggregateType,
      # for best performance. 
      def refresh!
        @aggregators.each { |aggregator| aggregator.refresh! }
      end
      
      # Given a particular +subpath+, returns the content that we should render for
      # that subpath, or +nil+ if there is none. Returns the content as a +String+, all
      # ready for output to the browser.
      def content_for(subpath)
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
        output_handler.end_all
        
        output_handler.text if found_content
      end
      
      # Adds an #Aggregator to this type. +aggregator_name+ can be a String or Symbol,
      # in which case we use the class
      # AssetAggregator::Aggregators::#{aggregator_name.to_s.camelize}Aggregator; or
      # it can be a Class object, in which case we use it. +args+ are passed through
      # literally to the constructor for the given class, and can be anything you want.
      # Any filters currently in effect (see #filter_with, below) are applied to this
      # aggregator.
      def add(aggregator_name, *args)
        filters = Thread.current[:asset_aggregator_filters] || [ ]
        args = [ self, @file_cache, filters ] + args
        
        aggregator = if aggregator_name.kind_of?(String) || aggregator_name.kind_of?(Symbol)
          "AssetAggregator::Aggregators::#{aggregator_name.to_s.camelize}Aggregator".constantize.new(*args)
        elsif aggregator_name.kind_of?(Class)
          aggregator_name.new(*args)
        else
          raise "Unknown Aggregator type #{aggregator_name.inspect}"
        end
        
        @aggregators << aggregator
      end
      
      # Returns the set of all subpaths that this type has content for. That is,
      # this is the set of subpaths that we generate (e.g.) JavaScript files for.
      def all_subpaths
        out = @aggregators.inject([ ]) { |out, agg| out | agg.all_subpaths }
        out.uniq
      end
      
      # Applies a filter to any #Aggregator objects added during its execution -- this
      # method takes a block.. The filter is specified by +filter_name+, which can
      # be a String or Symbol, in which case we use the class
      # AssetAggregator::Filters::#{filter_name.to_s.camelize}Filter; it can be a
      # Class, in which case we use that class; or it can be an object responding to
      # #filter, in which case we use it.
      #
      # If you add multiple filters, content will be filtered as so:
      #
      #    filter_with(:foo) do
      #      filter_with(:bar) do
      #        add :baz
      #      end
      #    end
      #
      # #Aggregator +baz+ will have its raw content first filtered with +bar+, then
      # that filter's output filtered with +foo+.
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
          # We add it to the start, so the ordering in the comment above applies.
          Thread.current[:asset_aggregator_filters] = [ the_filter ] + Thread.current[:asset_aggregator_filters]
          yield
        ensure
          Thread.current[:asset_aggregator_filters] = old_filters
        end
      end
    end
  end
end
