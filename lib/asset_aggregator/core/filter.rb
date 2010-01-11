module AssetAggregator
  module Core
    # A #Filter lets you transform a #Fragment's output before it ends up being
    # aggregated. This can be used to do things like minimize or obfuscate your
    # JavaScript, use a CSS enhancer like less or sass, or so on.
    class Filter
      # Very simple: takes the #Fragment object and a string as input, returns
      # the filtered data as a string.
      #
      # Note that +input+ may very much *not* be the same as +fragment.content+,
      # because it may have been passed through several filters beforehand.
      # Let me say that again: do *NOT* filter +fragment.content+; use the
      # +input+ string instead.
      def filter(fragment, input)
        raise "Must override in #{self.class.name}"
      end
    end
  end
end
