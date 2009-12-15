module AssetAggregator
  module Core
    # An Aggregator is responsible for finding fragments of content for a
    # particular aggregation type (e.g., JavaScript, CSS, whatever).
    # Different Aggregators will have different strategies
    # for doing this; for example, the #FilesAggregator just bundles
    # together a particular set of files or directories, while the 
    # #AssetPackagerYmlAggregator looks at an asset_packager-style YML file
    # and pulls data from there. 
    class Aggregator
      # Creates a new instance. +file_cache+
      # is the #FileCache that this Aggregator should use if it needs to
      # scan the filesystem. +filters+ is the array of #Filter objects that
      # should be applied to each #Fragment found, in order (i.e., the first
      # should be applied to the raw text of the fragment, the second to the
      # output of the first, and so on, with the output of the last filter
      # being what's actually used).
      def initialize(aggregate_type, file_cache, filters)
        @fragment_set = AssetAggregator::Core::FragmentSet.new(filters)
        @file_cache = file_cache
        @filtered_content_cache = { }
        @aggregate_type = aggregate_type
      end
      
      # Returns the set of all subpaths that this #Aggregator has content for.
      def all_subpaths
        ensure_loaded!
        fragment_set.all_subpaths
      end

      # Given a #Fragment, returns the content associated with that fragment,
      # filtered through the filters we were given upon construction. This
      # is cached by the #FragmentSet, for performance reasons.
      def filtered_content_from(fragment)
        ensure_loaded!
        fragment_set.filtered_content_from(fragment)
      end
      
      # Tells this #Aggregator that it should go back out and recompute the
      # set of #Fragment objects that it uses. For example, the 
      # #FilesAggregator would go back out and re-scan any directories
      # that were added to it, and the #AssetPackagerYmlAggregator
      # would go re-read the asset_packages.yml file, and any files it refers
      # to. 
      #
      # We grab the time at the beginning, then set it at the end, just to
      # make sure that (a) we don't update the time if there's an exception,
      # and (b) we don't miss files by setting a time after we scanned the
      # filesystem.
      def refresh!
        new_last_refresh = Time.now
        refresh_fragments_since(@last_refresh)
        @last_refresh = new_last_refresh
      end
      
      # Yields each #Fragment that should be included in the given subpath,
      # in turn, in order.
      def each_fragment_for(subpath, &proc)
        ensure_loaded!
        fragment_set.each_fragment_for(subpath, &proc)
      end
      
      # Given the #SourcePosition of a #Fragment, returns the subpath to which
      # that #Fragment has been aggregated. Returns nil if there is no #Fragment
      # with that #SourcePosition. Typically used to answer the question
      # "if I need this #Fragment included on my page, which aggregated asset
      # should I include?".
      def aggregated_subpath_for(fragment_source_position)
        ensure_loaded!
        fragment_set.aggregated_subpath_for(fragment_source_position)
      end
      
      private
      attr_reader :fragment_set
      
      # Must make sure +fragment_set+ contains all up-to-date fragments;
      # +last_refresh_fragments_since_time+ is the last time this was run (will be
      # nil the first time).
      def refresh_fragments_since(last_refresh_fragments_since_time)
        raise "Must override in #{self.class.name}"
      end
      
      # Make sure we've loaded our data at least once -- i.e., make sure
      # we've called refresh! at least once.
      def ensure_loaded!
        refresh! unless @last_refresh
      end
      
      # Given the content of a fragment, tells whether it is 'tagged' with
      # an explicit subpath. This is a means of overriding, on a file-by-file
      # basis, the subpath to which a fragment of content maps.
      def tagged_subpath(source_path, content)
        $1.strip.downcase if content =~ /ASSET[\s_]*TARGET[\s:]*(\S+)/
      end
    end
  end
end
