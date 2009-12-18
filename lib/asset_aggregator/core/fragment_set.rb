module AssetAggregator
  module Core
    # A #FragmentSet is used to hold the set of #Fragment objects that an #Aggregator
    # collects and uses. Its job in life is to provide efficient-enough access to these
    # #Fragments; although its implementation is very simple right now, we strive to
    # keep its API broad enough that we could simply change the implementation of this
    # class were we to need more efficient data structures (for example, to implement
    # #all_subpaths).
    #
    # A #FragmentSet knows which #Filters should be used on its #Fragments; this is so
    # that it can cache the filtered data, as some filters are fairly slow. This is
    # the sole performance improvement this class currently offers beyond a simple
    # #Array.
    class FragmentSet
      # Creates a new instance, with the given (possibly empty) array of #Filter objects.
      def initialize(filters)
        @fragments = [ ]
        @filters = filters
        @filtered_fragments = { }
        @filesystem_impl = AssetAggregator::Core::FilesystemImpl.new
      end
      
      # Given a #SourcePosition, returns the #Fragment that has that #SourcePosition,
      # if any. Returns nil if none matches.
      def for_source_position(source_position)
        @fragments.detect { |f| f.source_position == source_position }
      end

      # FOR TESTING ONLY. Sets the FilesystemImpl-compatible object that this class
      # will use to talk to the filesystem.
      def filesystem_impl=(impl)
        @filesystem_impl = impl
      end
      
      # Adds the given #Fragment. Replaces any other that shares the same #SourcePosition.
      def add(fragment)
        remove { |f| f.source_position == fragment.source_position }
        @fragments << fragment
      end
      
      # Removes all #Fragment objects satisfying the given block. 
      def remove(&proc)
        out = @fragments.select(&proc)
        @fragments -= out
        @filtered_fragments.delete_if { |fragment, content| out.include?(fragment) }
        out
      end
      
      # Returns the set of all distinct subpaths that any #Fragment in this set has.
      def all_subpaths
        @fragments.inject([ ]) { |out,f| out | f.target_subpaths }.uniq.sort
      end
      
      # Given the #SourcePosition of a #Fragment, returns the #target_subpaths for that
      # #Fragment. Returns nil if there is no #Fragment with that #SourcePosition.
      # Typically used to answer the question "if I need this #Fragment included on
      # my page, which aggregated assets could I include?".
      def aggregated_subpaths_for(fragment_source_position)
        out = @fragments.find { |f| f.source_position == fragment_source_position }
        out.target_subpaths if out
      end
      
      # Removes all #Fragment objects whose #SourcePosition indicates that they came from
      # the given file.
      def remove_all_for_file(file)
        file = @filesystem_impl.canonical_path(file)
        remove { |f| f.source_position.file == file }
      end
      
      # Yields each #Fragment that specifies +subpath+ as one of its given +target_subpaths+,
      # in sorted order (by #SourcePosition).
      def each_fragment_for(subpath, &proc)
        @fragments.select { |f| f.target_subpaths.include?(subpath) }.sort.each(&proc)
      end
      
      # Given a #Fragment, returns its content as filtered through the +filters+
      # specified when this #FragmentSet was created. This caches the filtered content,
      # since some filters can be expensive to run.
      def filtered_content_from(fragment)
        @filtered_fragments[fragment] ||= begin
          raise "This fragment is not part of this FragmentSet: #{fragment}" unless @fragments.include?(fragment)
          
          content = fragment.content
          @filters.inject(content) { |content, filter| filter.filter(content) }
        end
      end
    end
  end
end
