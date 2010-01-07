module AssetAggregator
  module Filters
    # A #Filter that uses the same algorithm that the asset_packager
    # (http://synthesis.sbecker.net/pages/asset_packager) uses to compress CSS.
    class CssminFilter < AssetAggregator::Core::Filter
      def filter(input)
        input = input.dup
        input.gsub!(/\s+/, " ")           # collapse space
        input.gsub!(/\} /, "}\n")         # add line breaks
        input.gsub!(/\n$/, "")            # remove last break
        input.gsub!(/ \{ /, " {")         # trim inside brackets
        input.gsub!(/; \}/, "}")          # trim inside brackets
        input
      end
    end
  end
end
