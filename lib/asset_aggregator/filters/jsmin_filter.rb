module AssetAggregator
  module Filters
    # A simple #Filter that uses our wrapped #Jsmin implementation to
    # filter JavaScript code according to Douglas Crockford's jsmin.c
    # implementation.
    class JsminFilter < AssetAggregator::Core::Filter
      def filter(fragment, input)
        AssetAggregator::Filters::Jsmin.convert(input)
      end
    end
  end
end
