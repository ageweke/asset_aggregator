module AssetAggregator
  class TestFilesystemImpl
    attr_reader :mtime_calls, :find_calls
  
    def initialize
      @mtime_calls = [ ]
      @find_calls = [ ]
    
      @find_returns = [ ]
      @mtime_returns = { }
    end
  
    def set_mtime(path, mtime)
      @mtime_returns[path] = mtime
    end
  
    def mtime(path)
      @mtime_calls << path
      @mtime_returns[path] || raise("No test mtime specified for #{path}")
    end
  
    def set_find_yields(returns)
      @find_returns << returns
    end
  
    def find(root)
      @find_calls << root
      yields = @find_returns.shift
      yields.each { |y| yield y }
    end
  
    def expand_path(path)
      path
    end
  
    def clear_calls!
      @mtime_calls = [ ]
      @find_calls = [ ]
    end
  end
end
