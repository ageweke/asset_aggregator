module AssetAggregator
  module Fragments
    class Fragment
      include Comparable
      
      attr_reader :target_subpath, :source_position, :content
    
      def initialize(target_subpath, source_position, content)
        @target_subpath = target_subpath
        @source_position = source_position
        @content = content
      end
    
      def source_file
        source_position.file
      end
      
      def write_to(out)
        out.puts content
      end
      
      def <=>(other)
        source_position <=> other.source_position
      end
    end
  end
end
