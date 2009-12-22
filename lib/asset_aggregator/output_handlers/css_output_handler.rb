module AssetAggregator
  module OutputHandlers
    # The #CommonOutputHandler subclass that we use for CSS.
    class CssOutputHandler < CommonOutputHandler
      def extension
        'css'
      end
    end
  end
end
