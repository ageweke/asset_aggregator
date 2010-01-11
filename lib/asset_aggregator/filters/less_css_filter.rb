module AssetAggregator
  module Filters
    # A simple Filter that uses Less (http://lesscss.org/) to process 'less'
    # code into normal CSS.
    class LessCssFilter < AssetAggregator::Core::Filter
      # Creates a new instance. 
      #
      # +options+ can contain any of:
      #   * +:prefix+ -- if supplied, prepended to the input (with a newline
      #     between) before it gets processed through 'less'. This is intended to
      #     allow you to add automatic @import statements, variable settings, etc.;
      #     adding actual CSS rules in there is likely a Very Bad Idea (tm).
      #   * +:processing+ -- if supplied, called with the #Fragment being
      #     filtered, the entire (#String) contents of the input being filtered,
      #     and the amount of time taken to do the processing, after each call.
      #   * +:runner+ -- if supplied, called instead of +Less.parse(input)+; its
      #     return value is assumed to be the result of running Less. Can be used
      #     to cache Less invocations, among other things (since running Less
      #     can be very slow). 
      def initialize(options = { })
        @options = options
        
        @prefix = options[:prefix]
        @prefix += "\n" unless @prefix.blank? || @prefix[-1..-1] == "\n"
        
        @processing = options[:processing] || (Proc.new { |fragment, input, time| })
        
        @runner = options[:runner] || (Proc.new { |fragment, net_input| Less.parse(net_input) })
      end
      
      def filter(fragment, input)
        require 'less'
        net_input = (@prefix || "") + input
        
        begin
          start_time = Time.now
          out = @runner.call(fragment, net_input)
          end_time = Time.now
          
          @processing.call(fragment, input, end_time - start_time)
          out
        rescue => e
          raise "Unable to process CSS using Less; got: #{e} with input:\n#{net_input}"
        end
      end
    end
  end
end
