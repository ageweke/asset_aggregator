module AssetAggregator
  module OutputHandlers
    # The #CommonOutputHandler subclass that we use for Javascript.
    class JavascriptOutputHandler < CommonOutputHandler
      def extension
        'js'
      end
    end
  end
end
