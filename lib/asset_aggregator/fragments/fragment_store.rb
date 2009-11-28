module AssetAggregator
  module Fragments
    class FragmentStore
      def initialize
        @sets = [ ]
      end

      def new_set(description)
        new_set = FragmentSet.new(description)
        @sets << new_set
        new_set
      end

      def sets
        @sets.sort
      end
    end
  end
end
