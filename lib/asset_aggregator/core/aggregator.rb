module AssetAggregator
  module Core
    # An Aggregator is responsible for finding fragments of content for a
    # particular aggregation type (e.g., JavaScript, CSS, whatever).
    # Different Aggregators will have different strategies
    # for doing this; for example, the #FilesAggregator just bundles
    # together a particular set of files or directories, while the 
    # #AssetPackagerCompatibilityAggregator looks at an asset_packager-style
    # YML file and pulls data from there. 
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
        @aggregate_type = aggregate_type
        @filesystem_impl = AssetAggregator::Core::FilesystemImpl.new
      end
      
      # FOR TESTING ONLY. Sets the FilesystemImpl-compatible object that this class
      # will use to talk to the filesystem.
      def filesystem_impl=(impl)
        @filesystem_impl = impl
      end
      
      # Returns the maximum modification time (as an integer, in Time#to_i
      # format) for any of the fragments in this #Aggregator that map to the
      # given +subpath+. Used to generate cache-busting URLs.
      def max_mtime_for(subpath)
        ensure_loaded!
        fragment_set.max_mtime_for(subpath)
      end
      
      # Given a #SourcePosition, returns the #Fragment with that
      # #SourcePosition, if any.
      def fragment_for(fragment_source_position)
        fragment_set.for_source_position(fragment_source_position)
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
        fragment_set.each_fragment_for(subpath, fragment_sorting_proc(subpath), &proc)
      end
      
      # The default #Proc used to sort #Fragment objects for the given
      # +subpath+. Used for things like the #AssetPackagerCompatibilityAggregator,
      # which needs to output its files in a particular order.
      def fragment_sorting_proc(subpath)
        nil
      end
      
      # Given the #SourcePosition of a #Fragment, returns an #Array of all
      # subpaths to which that #Fragment should be aggregated. Typically used
      # to answer the question "if I need this #Fragment included on my page,
      # which aggregated assets could I include?".
      def aggregated_subpaths_for(fragment_source_position)
        ensure_loaded!
        fragment_set.aggregated_subpaths_for(fragment_source_position) || [ ]
      end
      
      private
      attr_reader :fragment_set, :aggregate_type
      
      # Returns the #AssetAggregator that this #Aggregator is attached to.
      def asset_aggregator
        @aggregate_type.asset_aggregator
      end
      
      # Returns the #Integration object we should be using.
      def integration
        asset_aggregator.integration
      end
      
      # Not used by the #Aggregator class itself, but by subclasses. This is the
      # default method that determines where files get aggregated -- it accepts
      # the full path of a file (+file+), and the raw content in that file, and
      # returns the subpaths to which it should be aggregated.
      #
      # This method does the following:
      #
      # - If +file+ is under +#{integration.base}/app/<something>+, returns +something+.
      # - Otherwise, returns the base of the filename, without extensions --
      #   i.e., +foo/bar.html.erb+ maps to +bar+.
      #
      # This should hopefully provide a sane default.
      def default_subpath_definition(file, content)
        file = @filesystem_impl.canonical_path(file)
        
        out = File.basename(file)
        out = $1 if out =~ /^([^\.]+)\./
        
        if integration.is_under_base?(file)
          file = integration.base_relative_path(file)
          components = file.split(File::SEPARATOR).map { |c| c.strip.downcase }
          out = components[2] if components.length > 3 && components[0] == 'app'
        end
        
        out
      end
      
      # Returns the symbol associated with the #AggregateType, like :javascript
      # or :css.
      def aggregate_type_symbol
        aggregate_type.type
      end
      
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
      def update_with_tagged_subpaths(source_path, content, target_subpaths)
        out = target_subpaths.dup
        if content =~ /ASSET[\s_]*TARGET[\s:]*(\S+[^\n\r]+)/
          modification_string = $1.strip.downcase
          if modification_string =~ /^add\s+(.*)$/
            out |= paths_from($1)
          elsif modification_string =~ /^remove\s+(.*)$/
            out -= paths_from($1)
          elsif modification_string =~ /^exactly\s+(.*)$/
            out = paths_from($1)
          else
            out = paths_from(modification_string)
          end
        end
        out.sort
      end
      
      # Given a list of paths separated by spaces and possibly commas,
      # returns the paths as a list
      def paths_from(s)
        s.split(/\s*[\s,]\s*/).map { |s| s.strip }
      end
    end
  end
end
