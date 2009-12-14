module AssetAggregator
  module Core
    # This class exists so that we can mock out the filesystem, for testing;
    # see asset_aggregator/spec/asset_aggregator/test_filesystem_impl.
    # This way we don't have to create actual files on disk, we can test
    # various aspects of mtime handling without having to wait a long time,
    # and so on.
    #
    # This class is not spec'd, because doing so is fragile (lots of filesystem
    # setup and teardown, etc.) and it's so stupid simple that, hopefully,
    # errors should be rare.
    class FilesystemImpl
      # Returns the same as File.mtime(path).
      def mtime(path)
        File.mtime(path)
      end
  
      # Behaves the same as Find.find(root, &proc).
      def find(root, &proc)
        require 'find'
        Find.find(root, &proc)
      end
      
      # Behaves the same as our File.canonical_path(path).
      def canonical_path(path)
        File.canonical_path(path)
      end
      
      # Behaves the same as File.directory?(path).
      def directory?(path)
        File.directory?(path)
      end
      
      # Behaves the same as File.read(path)
      def read(path)
        File.read(path)
      end
      
      # Behaves the same as File.exist?(path)
      def exist?(path)
        File.exist?(path)
      end
    end
  end
end
