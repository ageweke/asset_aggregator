module AssetAggregator
  module Aggregates
    class Aggregator
      attr_reader :fragment_set, :file_cache, :subpath
      
      def initialize(fragment_set, file_cache, filters, subpath)
        @fragment_set = fragment_set
        @file_cache = file_cache
        @filters = filters
        @subpath = subpath
      end
      
      def implicit_references_for(source_file)
        [ ]
      end
      
      def filtered_content_from(fragment)
        out = fragment.content
        @filters.each do |filter|
          out = filter.filter(out)
        end
        out
      end
      
      def refresh!
        new_last_fragments_time = Time.now
        refresh_fragments_since(@last_fragments_time)
        @last_fragments_time = new_last_fragments_time
      end
      
      def each_fragment
        refresh! unless @last_fragments_time # Make sure we've done it at least once
        fragment_set.fragments.each { |f| yield f }
      end
      
      private
      # Must make sure fragment_set contains all up-to-date fragments; last_refresh_fragments_since_time
      # is the last time this was run (will be nil the first time).
      def refresh_fragments_since(last_refresh_fragments_since_time)
        raise "Must override in #{self.class.name}"
      end
      
      def target_subpath(source_path, content)
        if content =~ /ASSET[\s_]*TARGET[\s:]*(\S.*?)/
          $1.strip
        else
          default_target_subpath(source_path)
        end
      end
      
      def default_target_subpath(source_path)
        if source_path[0..(Rails.root.length - 1)] == Rails.root
          source_path = source_path[(Rails.root.length + 1)..-1]
          components = source_path.split(File::SEPARATOR)
          if components[0].downcase == 'app' && components.length >= 3
            components[2]
          else
            File.dirname(source_path)
          end
        else
          File.dirname(source_path)
        end
      end
    end
  end
end
