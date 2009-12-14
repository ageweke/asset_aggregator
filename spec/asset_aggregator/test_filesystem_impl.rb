module AssetAggregator
  class TestFilesystemImpl
    attr_reader :mtime_calls, :find_calls, :canonical_path_calls, :directory_calls
  
    def initialize
      @mtime_calls = [ ]
      @find_calls = [ ]
      @canonical_path_calls = [ ]
      @directory_calls = [ ]
      @content = { }
    
      @find_returns = [ ]
      @mtime_returns = { }
      @canonical_path_returns = { }
      @directories = [ ]
    end
  
    def set_mtime(path, mtime)
      @mtime_returns[path] = mtime
    end
  
    def mtime(path)
      @mtime_calls << path
      @mtime_returns[path] || raise("No test mtime specified for '#{path}'")
    end
  
    def set_find_yields(returns)
      @find_returns << returns
    end
  
    def find(root)
      @find_calls << root
      yields = @find_returns.shift
      yields.each { |y| yield y }
    end
    
    def canonical_path(path)
      @canonical_path_calls << path
      @canonical_path_returns[path] || (raise "No canonical path specified for '#{path}'")
    end
    
    def directory?(path)
      @directory_calls << path
      @directories.include?(path)
    end
    
    def read(path)
      @read_calls << path
      @content[path] || (raise "No content specified for '#{path}'")
    end
    
    def clear_calls!
      @mtime_calls = [ ]
      @find_calls = [ ]
    end
  end
end
