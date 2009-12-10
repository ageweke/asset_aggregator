module AssetAggregator
  module Filters
    class JsminFilter < AssetAggregator::Core::Filter
      def filter(input)
        jsmin = AssetAggregator::Filters::Jsmin.new
        jsmin.convert(input)
      end
    end
  end
end
