require 'find'

module AssetAggregator
  module Files
    class FileCache
      def initialize
        @roots = { }
      end
  
      def refresh!
        @roots.keys.each { |root| @roots[root].delete(:up_to_date) }
      end
  
      def changed_files_since(root, time)
        root = File.expand_path(root)
        data = @roots[root]
    
        unless data && data[:up_to_date]
          new_mtimes = { }
          start_time = Time.now
          file_count = 0
          Find.find(root) { |path| file_count += 1; new_mtimes[path] = File.mtime(path) }
          end_time = Time.now
          $stderr.puts ">>> Find.find(#{root.inspect}): #{file_count} files in #{end_time - start_time} s"
          
          # Deleted files -- if we don't have a new mtime for it, it doesn't exist;
          # we then say it was modified now, the first time we noticed it was gone.
          if data
            data.keys.each { |path| new_mtimes[path] ||= Time.now }
          end
          
          data = new_mtimes
          @roots[root] = data
          @roots[root][:up_to_date] = true
        end
        
        file_list = data.keys - [ :up_to_date ]
        file_list = file_list.select { |path| data[path] > time } if time
        file_list
      end
    end
  end
end
