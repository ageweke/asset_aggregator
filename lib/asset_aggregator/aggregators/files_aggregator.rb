module AssetAggregator
  module Aggregators
    # A #FilesAggregator includes a set of files in a particular
    # subpath -- i.e., you give it the full paths of one or more files, or
    # directories, and it includes everything in those files or everything in
    # all the files in those directories. It is typically used to set up a
    # simple mapping -- e.g., 'upload.js' gets everything in
    # public/javascripts/upload/, or all JavaScript files in app/views/upload/.
    class FilesAggregator < AssetAggregator::Core::Aggregator
      # Creates a new instance.
      #
      # * +root+ is the root directory that should be scanned.
      # * +inclusion_proc+ can be a #String file extension (without the dot),
      #      an #Array of extensions, or a #Proc or something responding to
      #      #call. It indicates whether given files should be included or
      #      not -- if a #Proc, it gets called once for every file that is
      #      under the given +root+, and returns a value that evaluates to
      #      true or false depending on whether file should be included in the
      #      aggregate or not.
      # * +options+ can contain any of the following:
      #    * +:exclude_directories+ -- if present, will be passed directly to
      #      FileCache#changed_files_since, as its +prunes+ argument. That is,
      #      any directories listed here that are underneath the +root+ will
      #      get skipped over, and files in them will not get aggregated.
      #    * +:delay_read+ -- if true, will cause this aggregator to _not_ read
      #      content eagerly when found, and instead simply add #Fragment objects
      #      without content. This is useful for image spriting, where we don't
      #      want to read #Fragment objects' content, but rather just keep
      #      track of where it is on the filesystem.
      # * +subpath_definition_proc+ (the block passed to this constructor), if
      #      present, will get called once for each file that gets included in
      #      this aggregate. It gets passed both the absolute path of the file
      #      and its content. Its job is to return the subpath (without extension
      #      or prefix) that the given file should be aggregated up to. For
      #      example, returning a constant will aggregate all content up into
      #      a single file; returning the name of the file itself will aggregate
      #      all content into a file with its same name (sort of a pointless
      #      use of the #AssetAggregator).
      #
      #      Note that files tagged with explicit subpath(s) (see
      #      #Aggregator.#update_with_tagged_subpaths) can override this.
      #
      # By default (if no +subpath_definition_proc+ is supplied), if content
      # is underneath #{Rails.root}/app/, and is nested at least 3 levels deep
      # under Rails.root (e.g., app/views/foo/bar.css), then we use the name
      # of the second-level directory underneath app/ as the subpath -- 'foo'
      # in this instance. Note that this does not descend;
      # app/views/foo/bar/baz.css will still aggregate into 'foo'.
      #
      # If no +subpath_definition_proc+ is supplied and the content is *not*
      # underneath #{Rails.root}/app/, then we use the base name of the file
      # itself, without extension, as the subpath to aggregate the content
      # into. For example, 'foo/bar/baz.css.erb' will aggregate into 'baz'.
      #
      # As always, files tagged with an explicit subpath will use that subpath,
      # no matter what.
      def initialize(aggregate_type, file_cache, filters, root, inclusion_proc = nil, options = nil, &subpath_definition_proc)
        super(aggregate_type, file_cache, filters)
        
        @root = root
        @inclusion_proc = normalize_inclusion_proc(inclusion_proc)
        @subpath_definition_proc = subpath_definition_proc || method(:default_subpath_definition)
        @options = options || { }
      end

      # A nice human-readable description.
      def to_s
        ":files, \'#{integration.base_relative_path(@root)}\', ..."
      end
      
      private
      # Called by #Aggregator; see that class for its exact requirements.
      # Uses the #FileCache to go look out at its +root+, and pulls in content
      # from each file that has changed.
      def refresh_fragments_since(last_refresh_fragments_since_time)
        @file_cache.changed_files_since(@root, last_refresh_fragments_since_time, @options[:exclude_directories] || [ ]).each do |changed_file|
          next if File.basename(changed_file) =~ /^\./ || @filesystem_impl.directory?(changed_file) || (! @inclusion_proc.call(changed_file))
          
          fragment_set.remove_all_for_file(changed_file)
          if @filesystem_impl.exist?(changed_file)
            content = @filesystem_impl.read(changed_file) unless @options[:delay_read]
            target_subpaths = Array(@subpath_definition_proc.call(changed_file, content))
            target_subpaths = update_with_tagged_subpaths(changed_file, content, target_subpaths) if content
            
            fragment_set.add(AssetAggregator::Core::Fragment.new(target_subpaths, AssetAggregator::Core::SourcePosition.new(changed_file, nil), content, @filesystem_impl.mtime(changed_file)))
          end
        end
      end
      
      # Takes whatever kind of +inclusion_proc+ was passed in the constructor,
      # and returns a #Proc object that represents it.
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
        
        inclusion_proc || (Proc.new { |f| true })
      end
    end
  end
end
