module AssetAggregator
  module Filters
    class JsminFilter
      def filter(input)
        jsmin = AssetAggregator::Filters::Jsmin.new
        jsmin.convert(input)
      end
    end
  end
end
