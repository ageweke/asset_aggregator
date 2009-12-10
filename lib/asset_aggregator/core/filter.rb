module AssetAggregator
  module Core
    # A #Filter lets you transform a #Fragment's output before it ends up being
    # aggregated. This can be used to do things like minimize or obfuscate your
    # JavaScript, use a CSS enhancer like less or sass, or so on.
    class Filter
      # Very simple: takes a string as input, returns the filtered data as a string.
      # That's it.
      def filter(input)
        raise "Must override in #{self.class.name}"
      end
    end
  end
end
