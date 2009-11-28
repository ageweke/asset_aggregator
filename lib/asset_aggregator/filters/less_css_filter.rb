module AssetAggregator
  module Filters
    class LessCssFilter
      def initialize(prefix = "")
        @prefix = prefix
        @prefix += "\n" unless @prefix[-1..-1] == "\n" || @prefix.blank?
      end
      
      def filter(input)
        require 'less'
        Less.parse(@prefix + input)
      end
    end
  end
end
