module AssetAggregator
  module Filters
    class JsminFilter < AssetAggregator::Core::Filter
      def filter(input)
        AssetAggregator::Filters::Jsmin.convert(input)
      end
    end
  end
end
