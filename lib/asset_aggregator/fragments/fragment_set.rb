module AssetAggregator
  module Fragments
    class FragmentSet
      def initialize
        @fragments = [ ]
      end
      
      def fragments
        @fragments.sort
      end

      def add(fragment)
        @fragments.delete_if { |f| f.source_position == fragment.source_position }
        @fragments << fragment
      end

      def remove_all_fragments_for(path)
        @fragments.delete_if { |f| f.source_position.file == path }
      end
    end
  end
end
