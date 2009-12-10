module AssetAggregator
  module Fragments
    class FragmentSet
      def initialize(filters)
        @fragments = [ ]
        @filters = filters
        @filtered_fragments = [ ]
      end
      
      def add(fragment)
        remove { |f| f.source_position == fragment.source_position }
        @fragments << fragment
      end
      
      def remove(&proc)
        out = @fragments.select(&proc)
        @fragments -= out
        @filtered_fragments.delete_if { |fragment, content| out.include?(fragment) }
        out
      end
      
      def all_subpaths
        @fragments.map { |f| f.target_subpath }.uniq.sort
      end
      
      def remove_all_for_file(file)
        remove { |f| f.source_position.file == file }
      end
      
      def each_fragment_for(subpath, &proc)
        @fragments.select { |f| f.subpath == subpath }.each(&proc)
      end
      
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
