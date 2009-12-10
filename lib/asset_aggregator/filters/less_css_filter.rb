module AssetAggregator
  module Filters
    class LessCssFilter < AssetAggregator::Core::Filter
      def initialize(prefix = "")
        @prefix = prefix
        @prefix += "\n" unless @prefix.blank? || @prefix[-1..-1] == "\n"
      end
      
      def filter(input)
        require 'less'
        Less.parse(@prefix + input)
      end
    end
  end
end
