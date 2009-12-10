module AssetAggregator
  module Core
    class Filter
      def filter(input)
        raise "Must override in #{self.class.name}"
      end
    end
  end
end
