module AssetAggregator
  module Aggregators
    module AggregatorSpecHelperMethods
      def fragments_from(aggregator, subpath)
        fragments = [ ]
        aggregator.each_fragment_for(subpath) { |f| fragments << f }
        fragments
      end

      def check_fragments(aggregator, subpath, expected_fragments)
        actual_fragments = fragments_from(aggregator, subpath)
        actual_fragments.length.should == expected_fragments.length
        actual_fragments.each_with_index do |actual_fragment, index|
          expected_fragment = expected_fragments[index]

          actual_fragment.target_subpaths.should == expected_fragment[:target_subpaths]
          actual_fragment.source_position.file.should == expected_fragment[:file]
          actual_fragment.source_position.line.should == expected_fragment[:line]
          actual_fragment.content.should == expected_fragment[:content]
          actual_fragment.mtime.should == expected_fragment[:mtime] if expected_fragment[:mtime]
        end
      end
    end
  end
end
