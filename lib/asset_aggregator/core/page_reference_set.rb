module AssetAggregator
  module Core
    # A #PageReferenceSet is a wrapper around a #ReferenceSet that provides methods with
    # friendly APIs for adding dependencies to it. It also can use a #PageReferencesOutputHandler
    # to produce HTML markup that's appropriate for including into a page -- that is, the
    # actual text of the set of <script src="..."> tags or <link rel="stylesheet" ...> tags
    # you need in order to get the assets onto your page.
    class PageReferenceSet
      # Creates a new instance. +asset_aggregator+ is the #AssetAggregator instance to use;
      # we need it to map fragment references back to subpaths and to figure out exactly
      # which subpaths to include, as well as for configuration data, etc.
      #
      # A new instance of this class should generally be used for each page you generate.
      # The idea is that you'll create it (perhaps lazily) as a +before_filter+ on your
      # #ApplicationController, call #require_fragment (ideally) or #require_aggregate
      # (when absolutely necessary; generally you'd like to have fine-grained dependencies,
      # so you know *why* a particular aggregate gets included, rather than requiring the
      # whole damn thing manually) throughout your code as things get rendered and
      # controller actions get hit, and then call #include_text on it from your layout,
      # plunking the resulting tags in the right places on your page.
      def initialize(asset_aggregator)
        @asset_aggregator = asset_aggregator
        @reference_set = AssetAggregator::Core::FreezableReferenceSet.new(integration)
      end
      
      # Tells this #PageReferenceSet that, for the given +aggregate_type+ (like
      # :javascript or :css), a fragment in +fragment_file+ (either a straight-up filename,
      # either absolute or relative to #Integration's base directory, or that plus a colon
      # and a line number, if referring to a fragment with a line number) is needed by
      # code originating at +source_position+. If not supplied, +source_position+ defaults
      # to the caller of this method. +descrip+ can be a human-readable string explaining
      # *why* the fragment in question is required; if not supplied, it defaults to
      # "explicit reference", implying that code directly stated that the fragment was
      # required (as opposed to being required because we're rendering an associated
      # view, or something like that).
      def require_fragment(aggregate_type, fragment_file, source_position = nil, descrip = nil)
        descrip ||= "explicit reference"
        source_position ||= AssetAggregator::Core::SourcePosition.levels_up_stack(2)
        
        if fragment_file.kind_of?(String)
          fragment_line = nil
          if fragment_file =~ /^(.*?)\s*:\s*(\d+)\s*$/
            fragment_file = $1
            fragment_line = $2.to_i
          end
          fragment_file = AssetAggregator::Core::SourcePosition.new(integration.path_from_base(fragment_file), fragment_line)
        end
        
        @reference_set.add(AssetAggregator::Core::FragmentReference.new(aggregate_type, fragment_file, source_position, descrip))
      end
      
      # Tells this #PageReferenceSet that, for the given +aggregate_type+ (like :javascript
      # or :css), the entire aggregate at the given +aggregate_subpath+ is required.
      #
      # Generally, you shouldn't do this: part of the point of the dependency-tracking
      # mechanisms of the #AssetAggregator is that you tell it what _fragments_ you need,
      # and let it figure out the best set of aggregates to include that will cover those
      # fragments. However, if you have lots of legacy code that can't really register its
      # dependencies correctly, or if you have special situations, you can explicitly require
      # an aggregate this way.
      #
      # By doing this, note that you lose three concrete things:
      #   * You can't know what _part_ of the aggregate is required; if you decide later
      #     you want to change the aggregation rules to optimize inclusion behavior,
      #     you can't figure out what you can put in different groupings to make things
      #     faster or better;
      #   * You constrain the aggregate-selection algorithm in the #ReferenceSet; because
      #     you're fixing certain aggregates, other combinations are not possible; and
      #   * You can't pass +:include_fragment_dependencies_instead_of_aggregates+ to
      #     the options for #include_text (in order to check whether your dependencies
      #     are really all there), and thus get _just_ the fragments themselves
      #     included -- because you're explicitly requiring an aggregate, we can't really
      #     include this _and_ fragments themselves, because we'd very likely double-
      #     include one or more fragments. 
      def require_aggregate(aggregate_type, aggregate_subpath, source_position = nil, descrip = nil)
        descrip ||= "explicit reference"
        source_position ||= AssetAggregator::Core::SourcePosition.levels_up_stack(2)

        @reference_set.add(AssetAggregator::Core::AggregateReference.new(aggregate_type, aggregate_subpath, source_position, descrip))
      end
      
      # Returns HTML markup that will include all necessary aggregates for this page.
      # This is guaranteed to include aggregates that cover at least all fragments
      # you have added dependencies for (using #require_fragment), plus any aggregates
      # you've added explicit dependencies for (using #require_aggregate). 
      #
      # The actual text creation is done by a separate output-handler class, which
      # defaults to #PageReferencesOutputHandler but which can be overridden by passing
      # the class in as +:output_handler_class+ in the +options+.
      #
      # You can restrict the output to only a particular kind of content, by passing
      #   options[:types] => [ :javascript, :css ]
      # ...or something similar. All other options are passed through to the constructor
      # of the output-handler class and can be used to modify its output.
      def include_text(options = { })
        options = options.dup
        
        types = options.delete(:types) || @reference_set.aggregate_types
        output_handler_class = options.delete(:output_handler_class) || AssetAggregator::Core::PageReferencesOutputHandler
        
        output_handler = output_handler_class.new(asset_aggregator, options)
        output_handler.start_all
        
        types.each do |type_symbol|
          aggregate_type = asset_aggregator.aggregate_type(type_symbol)
          
          subpath_references_pairs_this_type = [ ]
          @reference_set.each_aggregate_reference(type_symbol, asset_aggregator) do |subpath, references|
            subpath_references_pairs_this_type << [ subpath, references ]
          end
          
          output_handler.start_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
          subpath_references_pairs_this_type.each do |(subpath, references)|
            output_handler.aggregate(aggregate_type, subpath, references)
          end
          output_handler.end_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
        end
        
        output_handler.end_all
        output_handler.text
      end
      
      private
      # The #AssetAggregator we're working for.
      def asset_aggregator
        @asset_aggregator
      end
      
      # The #Integration object we should use.
      def integration
        @asset_aggregator.integration
      end
    end
  end
end
