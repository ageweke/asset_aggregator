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
      
      def remove(&proc)
        out = @fragments.select(&proc)
        @fragments.delete_if(&proc)
        out
      end
    end
  end
end
