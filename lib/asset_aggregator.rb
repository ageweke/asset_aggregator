module AssetAggregator
=begin
  Usage:
  
  AssetAggregator.aggregate :javascript do
    add :asset_packager_compatibility
    add :files, File.join(Rails.root, 'app', 'views'), '.js'
    add :widget_inlines, File.join(Rails.root, 'app', 'views')
  end
=end
  
  class << self
    def standard_instance
      @standard_instance ||= Impl.new
    end
    
    def aggregate(type, output_handler = nil, &definition_proc)
      standard_instance.set_aggregate_type(type, output_handler, definition_proc)
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
      @file_cache = AssetAggregator::Core::FileCache.new
    end

    def set_aggregate_type(type, output_handler, definition_proc)
      output_handler_class ||= "AssetAggregator::OutputHandlers::#{type.to_s.camelize}OutputHandler".constantize
      @aggregate_types[type.to_sym] = AssetAggregator::Core::AggregateType.new(type, @file_cache, output_handler_class, definition_proc)
    end

    def content_for(type, subpath)
      aggregate_type(type).content_for(subpath)
    end
    
    def refresh!
      @file_cache.refresh!
      @aggregate_types.values.each { |t| t.refresh! }
    end

    private
    def aggregate_type(type_name)
      @aggregate_types[type_name.to_sym] || (raise "There are no aggregations defined for type #{type_name.inspect}")
    end
  end
end
