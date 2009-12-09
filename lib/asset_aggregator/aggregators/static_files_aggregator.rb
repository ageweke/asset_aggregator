module AssetAggregator
  module Aggregators
    # A #StaticFilesAggregator includes a static set of files in a particular
    # subpath -- i.e., you give it the full paths of one or more files, or
    # directories, and it includes everything in those files or everything in
    # all the files in those directories. It is typically used to set up a
    # simple mapping -- e.g., 'upload.js' gets everything in
    # public/javascripts/upload/.
    class StaticFilesAggregator < Aggregator
      def initialize(fragment_set, file_cache, filters, subpath, include_proc, *files)
        super(fragment_set, file_cache, filters, subpath)
        @files = files.map { |f| File.canonical_path(f) }
        @directories = @files.select { |f| File.directory?(f) }
        @include_proc = include_proc || (Proc.new { |f| true })
        @include_proc = [ include_proc ] if @include_proc.kind_of?(String)
        if @include_proc.kind_of?(Array)
          extensions = @include_proc.dup.map { |x| x.strip.downcase }
          @include_proc = Proc.new do |f|
            ext = File.extname(f)
            ext = $1 if ext && ext =~ /^\.+(.*)$/
            extensions.include?(ext.strip.downcase)
          end
        end
      end
      
      private
      def refresh_fragments_since(last_refresh_fragments_since_time)
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
          
          changed.each do |changed_file|
            next if File.directory?(changed_file) || (! @include_proc.call(changed_file))
            content = File.read(changed_file)
            tagged = tagged_subpath(changed_file, content)
            next if tagged && tagged != subpath
            
            remove_all_fragments_for_file(changed_file)
            fragment_set.add(AssetAggregator::Fragments::Fragment.new(AssetAggregator::Files::SourcePosition.new(changed_file, nil), content))
          end
        end
      end
      
      def to_s
        ":static_files, #{@files.map { |f| "'" + AssetAggregator::Files::SourcePosition.trim_rails_root(f) + "'" }.join(", ")}"
      end
    end
  end
end
