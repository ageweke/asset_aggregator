module AssetAggregator
  module Aggregates
    class ParallelFilesAggregator < Aggregator
      def initialize(fragment_set, file_cache, filters, subpath, root, source_to_target_mapping)
        super(fragment_set, file_cache, filters, subpath)
        @root = File.expand_path(root)
        @source_to_target_mapping = source_to_target_mapping
        @last_fragments_time = nil
      end

      def implicit_references_for(source_file)
        mappings_for(source_file, :source_to_target).map do |target_file|
          AssetAggregator::References::AggregateReference.new(
            AssetAggregator::Files::SourcePosition.new(source_file, nil),
            AssetAggregator::Files::SourcePosition.new(target_file, nil)
          )
        end
      end
      
      def to_s
        ":parallel_files, '#{@root}', #{@source_to_target_mapping.inspect}"
      end
      
      private
      def refresh_fragments_since(last_refresh_fragments_since_time)
        file_cache.changed_files_since(@root, last_refresh_fragments_since_time).each do |target_file|
          source_files = mappings_for(target_file, :target_to_source) if File.exist?(target_file)
          next if source_files.empty?
          
          remove_all_fragments_for_file(target_file)
          
          if File.exist?(target_file)
            content = File.read(target_file)
            file_target_subpath = target_subpath(source_files.first, content)
            
            if file_target_subpath == subpath
              fragment_set.add(AssetAggregator::Fragments::Fragment.new(subpath, AssetAggregator::Files::SourcePosition.new(target_file, nil), content))
            end
          end
        end
      end
      
      def expand(pattern, subpath, filename)
        out = pattern.gsub(':subpath', subpath).gsub(':filename', filename)
        out = File.join(@root, out) unless out =~ %r{^/}
        out = File.expand_path(out)
        out
      end
      
      def trim_root(path)
        if path[0..(@root.length - 1)] == @root
          path = path[@root.length..-1]
          path = $1 if path =~ %r{^/+(.*)$}
        end
        
        path
      end
      
      def mappings_for(path, direction)
        path = File.expand_path(path)
        filename = File.basename(path)
        filename = $1 if filename =~ /^(.+?)\./i
        subpath = trim_root(File.dirname(path))
        
        out = [ ]
        
        @source_to_target_mapping.keys.sort.each do |source_pattern|
          match_pattern = mapped_pattern = nil
          
          if direction == :source_to_target
            match_pattern = source_pattern
            mapped_pattern = @source_to_target_mapping[source_pattern]
          elsif direction == :target_to_source
            match_pattern = @source_to_target_mapping[source_pattern]
            mapped_pattern = source_pattern
          else
            raise "Unknown direction #{direction.inspect}"
          end
          
          potential_filename = expand(match_pattern, subpath, filename)
          if potential_filename && potential_filename == path
            mapped_file = expand(mapped_pattern, subpath, filename)
            out << mapped_file if mapped_file && File.exist?(mapped_file)
          end
        end
        
        out
      end
    end
  end
end
