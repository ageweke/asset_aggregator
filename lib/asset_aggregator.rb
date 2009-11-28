module AssetAggregator
  class << self
    def standard_instance
      @standard_instance ||= Impl.new
    end
    
    def aggregate(type, &definition_proc)
      standard_instance.set_aggregate_type(type, definition_proc)
    end
    
    def refresh!
      standard_instance.refresh!
    end
    
    def content_for(type, subpath)
      standard_instance.content_for(type, subpath)
    end
  end
  
  class Impl
    def initialize
      @aggregate_types = { }
      @file_cache = AssetAggregator::Files::FileCache.new
    end

    def set_aggregate_type(type, definition_proc)
      type_class = "AssetAggregator::Types::#{type.to_s.camelize}AggregateType".constantize
      @aggregate_types[type.to_sym] = type_class.new(type, @file_cache, definition_proc)
    end

    def content_for(type, subpath)
      aggregate = aggregate_type(type).aggregate_for(subpath)
      aggregate.content if aggregate
    end
    
    def refresh!
      @file_cache.refresh!
      @aggregate_types.values.each { |t| t.refresh! }
    end

    private
    def aggregate_type(type_name)
      out = @aggregate_types[type_name.to_sym]
      raise "There are no aggregations defined for type #{type_name.inspect}" unless out
      out
    end
  end
end
