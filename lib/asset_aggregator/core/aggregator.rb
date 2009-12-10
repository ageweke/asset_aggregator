module AssetAggregator
  module Aggregators
    # An Aggregator is responsible for finding fragments of content for a
    # particular aggregation type (e.g., JavaScript, CSS, whatever).
    # Different Aggregators will have different strategies
    # for doing this; for example, the #StaticFilesAggregator just bundles
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
      def initialize(file_cache, filters)
        @fragment_set = AssetAggregator::Fragments::FragmentSet.new(filters)
        @file_cache = file_cache
        @filtered_content_cache = { }
      end
      
      def all_subpaths
        fragment_set.all_subpaths
      end

      # Given a #Fragment, returns the content associated with that fragment,
      # filtered through the filters we were given upon construction. This
      # is cached by the #FragmentSet, for performance reasons.
      def filtered_content_from(fragment)
        fragment_set.filtered_content_from(fragment)
      end
      
      # Tells this #Aggregator that it should go back out and recompute the
      # set of #Fragment objects that it uses. For example, the 
      # #StaticFilesAggregator would go back out and re-scan any directories
      # that were added to it, and the #AssetPackagerYmlAggregator
      # would go re-read the asset_packages.yml file.
      def refresh!
        new_last_fragments_time = Time.now
        refresh_fragments_since(@last_fragments_time)
        @last_fragments_time = new_last_fragments_time
      end
      
      # Yields each #Fragment, in turn, in order.
      def each_fragment_for(subpath, &proc)
        refresh! unless @last_fragments_time # Make sure we've done it at least once
        fragment_set.each_fragment_for(subpath, &proc)
      end
      
      private
      # Must make sure +fragment_set+ contains all up-to-date fragments;
      # +last_refresh_fragments_since_time+ is the last time this was run (will be
      # nil the first time).
      def refresh_fragments_since(last_refresh_fragments_since_time)
        raise "Must override in #{self.class.name}"
      end
      
      def tagged_subpath(source_path, content)
        $1.strip.downcase if content =~ /ASSET[\s_]*TARGET[\s:]*(\S+)/
      end
    end
  end
end
