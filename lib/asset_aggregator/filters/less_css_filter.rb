module AssetAggregator
  module Filters
    # A simple Filter that uses Less (http://lesscss.org/) to process 'less'
    # code into normal CSS.
    class LessCssFilter < AssetAggregator::Core::Filter
      # Creates a new instance. If you pass text in 'prefix', it will get prepended
      # to the source before it gets processed through 'less'. This is intended to
      # allow you to add automatic @import statements, variable settings, etc.;
      # adding actual CSS rules in there is likely a Very Bad Idea (tm).
      def initialize(prefix = "")
        @prefix = prefix
        @prefix += "\n" unless @prefix.blank? || @prefix[-1..-1] == "\n"
      end
      
      def filter(input)
        require 'less'
        net_input = (@prefix || "") + input
        
        begin
          Less.parse(net_input)
        rescue => e
          raise "Unable to process CSS using Less; got: #{e} with input:\n#{net_input}"
        end
      end
    end
  end
end
