require 'find'

module AssetAggregator
  module Core
    # The FileCache allows the AssetAggregator to efficiently scan large subtrees, looking
    # for files that have changed since some particular time in the past. While there's
    # no magic here -- if you want to look for changed files, you still have to stat(2)
    # all of them -- this class at least makes sure we don't do it more often than we
    # need to, and gives us a global way to say "now go look again".
    #
    #
    # Basically, you new up an instance of this class, and then call
    # #changed_files_since(path, some_time). 'path' is the absolute path to the directory
    # you're interested in (all files and directories underneath this directory are
    # included, recursively); 'some_time' is the time we're looking since. It returns
    # an array of absolute paths to all files underneath this directory that have
    # changed since *or at* some_time. It's "since or at" because filesystems typically
    # have coarser mtime resolution than Ruby does; imagine the following situation:
    #
    #    5:00:01.10 PM -- Ruby code does something, notes the timestamp
    #    5:00:01.20 PM -- file gets changed; filesystem will set mtime to 5:00:01 PM
    #    5:00:01.30 PM -- Ruby code calls #changed_files_since(..., 5:00:01.20 PM)
    # 
    # This class will round down the passed-in timestamp to the nearest second, and then
    # use >=, not >. This way, 5:00:01.20 PM gets turned into 5:00:01.00 PM, and then we
    # do '>=', so we'll pick up the changed file. If we didn't do either of these things,
    # we wouldn't pick it up.
    #
    # Yes, this will sometimes err on the side of picking up files that haven't actually
    # changed since the last call. For our purposes, this is fine: this reduces efficiency
    # ever so slightly but keeps correctness, which is what really matters.
    # 
    # 
    # There's one other important thing: #changed_files_since will only actually hit
    # the filesystem and go look if someone has called refresh! since the last time it
    # was called for the 'path' you pass into it. This is where we get our efficiency
    # gains, and also how we keep things fast in production environments: refresh! gets
    # called once per HTTP request into Rails in the development environment, and once,
    # ever, in the production environment.
    class FileCache
      # Creates a new instance. In general, you should only ever need one of these;
      # making more than one will only make things less efficient.
      def initialize
        @roots = { }
        @filesystem_impl = AssetAggregator::Core::FilesystemImpl.new
      end
      
      # FOR TESTING ONLY. Sets the FilesystemImpl-compatible object that this class
      # will use to talk to the filesystem.
      def filesystem_impl=(impl)
        @filesystem_impl = impl
      end
      
      # Does not actually hit the filesystem at all itself, but rather marks all
      # of the cached file data as stale so that the next time someone calls
      # #changed_files_since, we'll go hit the filesystem again instead of just
      # using data from memory.
      def refresh!
        @roots.keys.each { |root| @roots[root].delete(:up_to_date) }
      end
      
      # Returns an array containing the fully-qualified paths of all files underneath
      # the given root directory (recursively) that have changed since the given time.
      # Note that, as explained in the header, we round down and are otherwise 
      # conservative about the time, so it's easily possible to get a file on two
      # successive calls even if it hasn't changed in between.
      #
      # Deleted files: if a file has been deleted, we will return its path in the
      # result when we notice it's been deleted. That is, if you have:
      #
      #    refresh!..changed_files_since..<file deletion>..refresh!..changed_files_since
      #
      # ...then we will report it as deleted at the time of the second call to
      # #changed_files_since, since that's when we will notice it's been deleted.
      # In other words, if you call #changed_files_since with a time distinctly
      # after that of the second call, you won't get the deleted file; if you call
      # #changed_files_since with a time that's at or before the time of the second
      # call, you will get the deleted file.
      #
      # YOU ARE WARNED: unless you have called #refresh! on this object, new changes
      # will NOT be picked up by this method. This is part of the whole point, as
      # it makes it much more efficient.
      def changed_files_since(root, time)
        root = @filesystem_impl.expand_path(root)
        data = @roots[root]
    
        unless data && data[:up_to_date]
          new_mtimes = { }
          start_time = Time.now
          @filesystem_impl.find(root) { |path| new_mtimes[path] = @filesystem_impl.mtime(path) }
          end_time = Time.now
          
          # Deleted files -- if we don't have a new mtime for it, it doesn't exist;
          # we then say it was modified now, the first time we noticed it was gone.
          if data
            data.keys.each { |path| new_mtimes[path] ||= start_time }
          end
          
          data = new_mtimes
          @roots[root] = data
          @roots[root][:up_to_date] = true
        end
        
        file_list = data.keys - [ :up_to_date ]
        if time
          time = Time.at(time.to_i)
          file_list = file_list.select { |path| data[path] >= time }
        end
        
        file_list
      end
    end
  end
end
