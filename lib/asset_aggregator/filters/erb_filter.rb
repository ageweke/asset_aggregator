module AssetAggregator
  module Filters
    # The #ERbFilter simply processes its content through ERb.
    #
    # +options+ can contain:
    #   * +:binding+ -- if an actual #Binding, we'll use that as the #Binding
    #     we pass to ERb; if it's a #Hash, we'll turn it into an #OpenStruct
    #     and use that (so it'll do what you'd naturally expect); if it's any
    #     other kind of #Object, we'll grab a #Binding from that and use it;
    #     otherwise, we'll make a new, blank #Binding (off an #OpenStruct) and
    #     use that.
    #   * +:binding_proc+ -- if +:binding+ is not supplied, but this is, it
    #     will be called with the #Fragment and input text each time we need
    #     to filter something, and whatever it returns will be used as the ERb
    #     binding, in exactly the way described above.
    #
    # Newline trimming (+-%>+) is enabled here.
    class ErbFilter < AssetAggregator::Core::Filter
      def initialize(options = { })
        if options[:binding_proc]
          @binding_proc = options[:binding_proc]
        else
          binding = options[:binding]
          @binding_proc = Proc.new { |fragment, input| binding }
        end
      end
      
      def filter(fragment, input)
        binding = to_binding(@binding_proc.call(fragment, input))
        template = ERB.new(input, nil, '-')
        begin
          template.result(binding)
        rescue Exception => e
          raise "Unable to process data from fragment at #{fragment.source_position} with ERb; got an exception:\n\n#{e} (#{e.class.name})\n#{e.backtrace.join("\n")}\n\n"
        end
      end
      
      private
      def to_binding(o)
        if o.kind_of?(Binding)
          o
        elsif o.kind_of?(Hash)
          binding_object = OpenStruct.new
          o.each { |k,v| binding_object.send("#{k}=", v) }
          binding_object.send(:binding)
        elsif o.kind_of?(Object)
          o.send(:binding)
        else
          OpenStruct.new.send(:binding)
        end
      end
    end
  end
end
