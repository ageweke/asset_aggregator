module AssetAggregator
  module Filters
    # The #ERbFilter simply processes its content through ERb. If you supply an
    # object to its constructor, then it will be used as the ERb binding --
    # if it's an actual #Binding, we'll use that; if it's a #Hash, we'll turn it
    # into an #OpenStruct and use that (so it'll do what you'd naturally expect);
    # if it's any other kind of #Object, we'll grab a #Binding from that and use
    # it; otherwise, we'll make a new, blank #Binding (off an #OpenStruct) and
    # use that.
    #
    # Newline trimming (+-%>+) is enabled here.
    class ErbFilter < AssetAggregator::Core::Filter
      def initialize(binding = nil)
        @binding = if binding.kind_of?(Binding)
          binding
        elsif binding.kind_of?(Hash)
          binding_object = OpenStruct.new
          binding.each { |k,v| binding_object.send("#{k}=", v) }
          binding_object.send(:binding)
        elsif binding.kind_of?(Object)
          binding.send(:binding)
        else
          OpenStruct.new.send(:binding)
        end
      end
      
      def filter(input)
        template = ERB.new(input, nil, '-')
        template.result(@binding)
      end
    end
  end
end
