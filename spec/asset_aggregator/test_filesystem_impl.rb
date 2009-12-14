module AssetAggregator
  # A mock FilesystemImpl, for use in tests.
  class TestFilesystemImpl
    attr_reader :mtime_calls, :find_calls, :canonical_path_calls, :directory_calls, :read_calls, :exist_calls
  
    def initialize
      @find_returns = [ ]
      @mtime_returns = { }
      @canonical_path_returns = { }
      @directories = [ ]
      @content = { }
      @do_not_exist = [ ]
      
      clear_calls!
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
    
    def set_canonical_path(path, canonical_path)
      @canonical_path_returns[path] = canonical_path
    end
    
    def canonical_path(path)
      @canonical_path_calls << path
      @canonical_path_returns[path] || path
    end
    
    def set_directory(dir)
      @directories |= [ dir ]
    end
    
    def directory?(path)
      @directory_calls << path
      @directories.include?(path)
    end
    
    def set_content(path, content)
      @content[path] = content
    end
    
    def read(path)
      @read_calls << path
      @content[path] || (raise "No content specified for '#{path}'")
    end
    
    def clear_calls!
      @mtime_calls = [ ]
      @find_calls = [ ]
      @canonical_path_calls = [ ]
      @directory_calls = [ ]
      @read_calls = [ ]
      @exist_calls = [ ]
    end
    
    def set_does_not_exist(path, does_not_exist)
      if does_not_exist then @do_not_exist |= [ path ] else @do_not_exist -= [ path ] end
    end
    
    def exist?(path)
      @exist_calls << path
      ! @do_not_exist.include?(path)
    end
  end
end
