module AssetAggregator
  module Aggregates
    # An Aggregate represents a final asset that's delivered -- for example,
    # /javascripts/foo.js (or wherever you've mapped the path). It is canonically
    # defined by a type (the AggregateType object corresponding to :javascript,
    # :css, whatever) and a subpath ('foo' for 'foo.js', 'foo/bar/baz', whatever).
    class Aggregate
      attr_reader :subpath
      
      # Creates a new instance. aggregate_type must be an object conforming to
      # AssetAggregator::Types::AggregateType. file_cache should be an instance
      # of AssetAggregator::Files::FileCache. subpath should be a String
      # corresponding to the subpath to this aggregate, without extension
      # (e.g., 'foo/bar/baz' for something that might end up delivered as
      # '/javascripts/foo/bar/baz.js').
      #
      # definition_proc is an object that responds to #call; it is evaluated in
      # the context of this object. Its job is to call #add, and perhaps
      # #filter_with, so that the correct Aggregator objects get added to this
      # object...so that when content is requested of it, the right content
      # is delivered. This object is evaluated immediately, when it's passed
      # in to the constructor, so you don't need to keep it around after that
      # point.
      #
      # This mechanism may seem a little odd -- at least to me, it seems like
      # you ought to create an object that represents how *all* aggregates under
      # a certain path are created, and then it'd create the content for each
      # one as it wished. But this actually ends up being more flexible; you
      # can create Aggregates for each subpath that do anything you damn well
      # please, and it'll all "just work".
      def initialize(aggregate_type, file_cache, subpath, definition_proc)
        @aggregate_type = aggregate_type
        @file_cache = file_cache
        @subpath = subpath
        @aggregators = [ ]
        
        instance_eval(&definition_proc)
      end
      
      # Tells this Aggregate to refresh its content -- i.e., check against
      # whatever underlying files or other data sources are used to get its
      # content, and get up-to-date versions if necessary. This just calls
      # #refresh! on each of the Aggregators added to this object.
      #
      # This does NOT call #refresh! on the FileCache that this aggregate
      # uses; if you want that, you need to do it yourself. This is because
      # you really don't want to call that multiple times, as you would if
      # you ran through a list of Aggregates that all use the same underlying
      # FileCache and called refresh! on each one (if this method called
      # that); you'd end up re-scanning the filesystem way too many times.
      def refresh!
        @aggregators.each { |aggregator| aggregator.refresh! }
      end
      
      # Returns the actual content for this aggregate, as a String. Delegates
      # through to the AggregateType to do basically all of its work.
      def content
        @aggregate_type.content_for(self, @aggregators)
      end
      
      # Should primarily be called from the +definition_proc+ passed to the
      # constructor. Yields; any aggregators added (using +add+, below)
      # in the block will be filtered with the given +filter_name+.
      #
      # +filter_name+ may be a #String or #Symbol, in which case the filter class
      # AssetAggregator::Filters::#{filter_name.to_s.camelize}Filter will
      # be used; it can be a #Class, in which case it's used as the filter
      # class; or it can be a filter itself by responding to #filter, in which
      # case the object passed in will be used.
      #
      # If +filter_name+ is a #Class or a #String, then any arguments passed
      # after the +filter_name+ will be passed to the class upon its construction
      # for use as the filter.
      #
      # If you nest #filter_with calls, then filters are applied from the
      # inside out -- i.e., if you say:
      #   filter_with :foo { filter_with :bar { ... } }
      # ...then your content will get filtered by :bar, then filtered by
      # :foo, not the other way around.
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
      
      # Adds an aggregator of the given type. +aggregator_type+ can be a #Symbol
      # or a #String, in which case we use the class
      # AssetAggregator::Aggregators::#{aggregator_type.to_s.camelize}Aggregator;
      # or it can be a #Class, in which case we use it itself.
      #
      # Any extra arguments are passed to the class's constructor, after the
      # #FragmentSet, #FileCache, array of Filters, and subpath.
      def add(aggregator_type, *args)
        klass = if aggregator_type.kind_of?(Symbol) || aggregator_type.kind_of?(String)
          "AssetAggregator::Aggregators::#{aggregator_type.to_s.camelize}Aggregator".constantize
        elsif aggregator_type.kind_of?(Class)
          aggregator_type
        else
          raise "You need to pass a String, Symbol, or Class here"
        end
        
        filters = Thread.current[:filters] || [ ]
        args = [ AssetAggregator::Fragments::FragmentSet.new, @file_cache, filters, @subpath ] + args
        @aggregators << klass.new(*args)
      end
    end
  end
end
