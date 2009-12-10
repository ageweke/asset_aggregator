module AssetAggregator
  module Aggregators
    # A #StaticFilesAggregator includes a static set of files in a particular
    # subpath -- i.e., you give it the full paths of one or more files, or
    # directories, and it includes everything in those files or everything in
    # all the files in those directories. It is typically used to set up a
    # simple mapping -- e.g., 'upload.js' gets everything in
    # public/javascripts/upload/, or all JavaScript files in .
    class StaticFilesAggregator < Aggregator
      def initialize(file_cache, filters, root, inclusion_proc = nil, &subpath_definition_proc)
        super(file_cache, filters)
        
        @root = root
        @inclusion_proc ||= normalize_inclusion_proc(inclusion_proc)
        @subpath_definition_proc ||= method(:default_subpath_definition)
      end
      
      def to_s
        ":static_files, \'#{@root}\'"
      end
      
      private
      def refresh_fragments_since(last_refresh_fragments_since_time)
        files_changed_since(last_refresh_fragments_since_time) do |changed_file|
          next if File.basename(changed_file) =~ /^\./ || File.directory?(changed_file) || (! @inclusion_proc.call(changed_file))
          
          content = File.read(changed_file)
          target_subpath = tagged_subpath(changed_file, content) || @subpath_definition_proc.call(changed_file, content)
          
          fragment_set.remove_all_for_file(changed_file)
          fragment_set.add(AssetAggregator::Fragments::Fragment.new(target_subpath, AssetAggregator::Files::SourcePosition.new(changed_file, nil), content))
        end
      end
      
      def normalize_inclusion_proc(inclusion_proc)
        inclusion_proc = [ inclusion_proc ] if inclusion_proc.kind_of?(String)
        if inclusion_proc.kind_of?(Array)
          extensions = inclusion_proc.map do |e|
            out = e.strip.downcase
            out = $1 if out =~ /^\.+(.*)$/
            out
          end
          
          inclusion_proc = Proc.new do |file|
            extension = File.extname(file)
            extension = $1 if extension =~ /^\.+(.*)$/
            extensions.include?(extension)
          end
        end
        
        inclusion_proc || Proc.new { |f| true }
      end
      
      def default_subpath_definition(file, content)
        file = File.canonical_path(file)
        rails_root_canonical = File.canonical_path(Rails.root)
        
        out = File.basename(file)
        out = $1 if out =~ /^([^\.]+)\./
        
        if file[0..(Rails.root.length - 1)] == rails_root_canonical
          file = file[(Rails.root.length + 1)..-1] 
          components = file.split(File::SEPARATOR).map { |c| c.strip.downcase }
          out = components[2] if components.length > 3 && components[0] == 'app'
        end
        
        out
      end
      
      def files_changed_since(last_refresh_fragments_since_time, &proc)
        @files.each do |file|
          is_directory = @directories.include?(file)
          root = if is_directory then file else File.dirname(file) end
          
          changed = @file_cache.changed_files_since(root, last_refresh_fragments_since_time)
          unless is_directory
            if changed.include?(file)
              changed = [ file ]
            else
              changed = [ ]
            end
          end
          
          changed.each(&proc)
        end
      end
    end
  end
end
