module AssetAggregator
  module Aggregates
    class StaticFilesAggregator < Aggregator
      def initialize(fragment_set, file_cache, filters, subpath, *files)
        super(fragment_set, file_cache, filters, subpath)
        @files = files
      end

      def refresh_fragments_since(last_refresh_fragments_since_time)
        @files.each do |file|
          if File.exist?(file)
            mtime = File.mtime(file)
            $stderr.puts ">>> refresh_fragments_since(#{last_refresh_fragments_since_time.inspect}): mtime #{mtime.inspect}"
            if (! last_refresh_fragments_since_time) || mtime > last_refresh_fragments_since_time
              fragment_set.remove_all_fragments_for(file)
              fragment_set.add(AssetAggregator::Fragments::Fragment.new(subpath, AssetAggregator::Files::SourcePosition.new(file, nil), File.read(file)))
            end
          end
        end
      end
      
      def implicit_references_for(source_file)
        [ ]
      end
      
      def to_s
        ":static_files, #{@files.map { |f| AssetAggregator::Files::SourcePosition.trim_rails_root(f) }.join(", ")}"
      end
    end
  end
end
