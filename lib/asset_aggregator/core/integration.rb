module AssetAggregator
  module Core
    class Integration
      def initialize(base_directory, logger)
        @base_directory = File.canonical_path(base_directory)
        @base_relative_paths = { }
        @logger = logger
      end
      
      def path_from_base(*subpath)
        joined = File.join(*subpath)
        if joined =~ %r{^\s*/}
          joined
        else
          File.join(@base_directory, *subpath)
        end
      end
      
      def is_under_base?(path)
        path = File.canonical_path(path)
        base_relative_path(path) != path
      end
      
      def base_relative_path(path)
        @base_relative_paths[path] ||= begin
          out = File.canonical_path(path)
          if (out.length > @base_directory.length + 1) && (out[0...@base_directory.length] == @base_directory)
            out = out[(@base_directory.length)..-1]
            out = $1 if out =~ %r{[/\\]+(.*)$}
          end
          out
        end
      end
      
      def warn(s)
        @logger.warn(s)
      end
      
      def debug(s)
        @logger.debug(s)
      end
    end
  end
end
