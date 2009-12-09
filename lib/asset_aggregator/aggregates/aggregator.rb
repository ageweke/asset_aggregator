module AssetAggregator
  module Aggregates
    # An Aggregator is responsible for finding fragments of content for a 
    # particular subpath. Different Aggregators will have different strategies
    # for doing this; for example, the #StaticFilesAggregator just bundles
    # together a particular set of files or directories, while the 
    # #AssetPackagerYmlAggregator looks at an asset_packager-style YML file
    # and pulls data from there. 
    #
    # Aggregators are also responsible for finding implicit references from
    # source files. For example, in the #ParallelFilesAggregator,
    # 'app/views/foo/bar.html.erb' may add an implicit reference to 
    # 'public/javascripts/views/foo/bar.js', meaning whenever the view is
    # rendered (alone, or as a partial that's part of a larger view context),
    # that JavaScript file will be automatically included. 
    class Aggregator
      attr_reader :fragment_set, :file_cache, :subpath
      
      # Creates a new instance. +fragment_set+ is the #FragmentSet to which
      # all fragments found by this Aggregator should be added; +file_cache+
      # is the #FileCache that this Aggregator should use if it needs to
      # scan the filesystem. +filters+ is the array of #Filter objects that
      # should be applied to each #Fragment found, in order (i.e., the first
      # should be applied to the raw text of the fragment, the second to the
      # output of the first, and so on, with the output of the last filter
      # being what's actually used). +subpath+ is the subpath of the 
      # #Aggregate that we're working for.
      def initialize(fragment_set, file_cache, filters, subpath)
        @fragment_set = fragment_set
        @file_cache = file_cache
        @filters = filters
        @subpath = subpath
        @filtered_content_cache = { }
      end
      
      # Returns a (possibly-empty) array of #AggregateReference objects for
      # the given source file, representing the implicit references that this
      # #Aggregator generates for the given file. Note that +source_file+ is
      # the absolute path to the file; some Aggregators may want to open this
      # file up, while others may not need to.
      def implicit_references_for(source_file)
        [ ]
      end
      
      # Given a #Fragment, returns the content associated with that fragment,
      # filtered through the filters we were given upon construction. This
      # is cached, for performance reasons.
      def filtered_content_from(fragment)
        @filtered_content_cache[fragment] ||= begin
          out = fragment.content
          @filters.each do |filter|
            out = filter.filter(out)
          end
          out
        end
      end
      
      # Tells this #Aggregator that it should go back out and recompute the
      # set of #Fragment objects that it uses. For example, the 
      # #StaticFilesAggregator would go back out and re-scan any directories
      # that were added to it; the #ParallelFilesAggregator would re-scan
      # mapped paths for target files; and the #AssetPackagerYmlAggregator
      # would go re-read the asset_packages.yml file. 
      def refresh!
        new_last_fragments_time = Time.now
        refresh_fragments_since(@last_fragments_time)
        @last_fragments_time = new_last_fragments_time
      end
      
      # Yields each #Fragment, in turn, in order.
      def each_fragment
        refresh! unless @last_fragments_time # Make sure we've done it at least once
        fragment_set.fragments.each { |f| yield f }
      end
      
      private
      # Must make sure +fragment_set+ contains all up-to-date fragments;
      # +last_refresh_fragments_since_time+ is the last time this was run (will be
      # nil the first time).
      def refresh_fragments_since(last_refresh_fragments_since_time)
        raise "Must override in #{self.class.name}"
      end
      
      # Removes all fragments for the given path. Typically called when we've
      # detected that the given path has changed; we'll remove all fragments
      # associated with it, and then re-add them.
      def remove_all_fragments_for_file(path)
        path = File.expand_path(path)
        remove_fragments_if { |f| f.source_position.file == path }
      end
      
      # Removes all fragments from the +fragment_set+ that satisfy a particular
      # condition. Useful because we need to clear the @filtered_content_cache,
      # too.
      def remove_fragments_if(&proc)
        matching_fragments = fragment_set.remove(&proc)
        matching_fragments.each { |f| @filtered_content_cache.delete(f) }
      end
      
      # May be used by subclasses. Given the path of a source file and the
      # content in that file, returns the subpath that this source file would
      # normally aggregate up into. 
      #
      # This follows a two-part algorithm:
      #   - If the content contains the string 'ASSET TARGET <xxx>' anywhere
      #     in it (or 'ASSET_TARGET:', or some variant thereof), then <xxx>
      #     is used as the subpath for the content.
      #   - Otherwise, if the file is nested at least two levels underneath
      #     'app', we use the name of the top-level subdirectory underneath
      #     'app/*' -- for example, 'app/views/foo/bar/baz' will use 'foo'.
      #   - If the file is nested only one level underneath 'app' -- e.g.,
      #     'app/views/foo.html.erb' -- then we use the name of the file,
      #     without extension; in this case, 'foo'.
      #   - Otherwise, we use the name of the directory the file is in, period.
      def target_subpath(source_path, content)
        if content =~ /ASSET[\s_]*TARGET[\s:]*(\S+)/
          $1.strip
        else
          default_target_subpath(source_path)
        end
      end
      
      # Implements the second and third parts of the algorithm defined
      # by #target_subpath, above.
      def default_target_subpath(source_path)
        if source_path[0..(Rails.root.length - 1)] == Rails.root
          source_path = source_path[(Rails.root.length + 1)..-1]
          components = source_path.split(File::SEPARATOR)
          if components[0].downcase == 'app' && components.length >= 3
            out = components[2]
            out = $1 if out =~ /^([^\.]+)\./
            out
          else
            File.dirname(source_path)
          end
        else
          File.dirname(source_path)
        end
      end
    end
  end
end
