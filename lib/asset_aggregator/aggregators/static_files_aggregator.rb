module AssetAggregator
  module Aggregators
    class StaticFilesAggregator < Aggregator
      def initialize(fragment_set, file_cache, filters, subpath, *files)
        super(fragment_set, file_cache, filters, subpath)
        @files = files
      end
      
      private
      def refresh_fragments_since(last_refresh_fragments_since_time)
        @files.each do |file|
          if File.exist?(file)
            mtime = File.mtime(file)
            if (! last_refresh_fragments_since_time) || mtime > last_refresh_fragments_since_time
              remove_all_fragments_for_file(file)
              fragment_set.add(AssetAggregator::Fragments::Fragment.new(AssetAggregator::Files::SourcePosition.new(file, nil), File.read(file)))
            end
          end
        end
      end
      
      def to_s
        ":static_files, #{@files.map { |f| "'" + AssetAggregator::Files::SourcePosition.trim_rails_root(f) + "'" }.join(", ")}"
      end
    end
  end
end
