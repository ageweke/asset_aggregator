module AssetAggregator
  module Rails
    module PerViewReferences
      class << self
        AGGREGATE_TYPE_TO_EXTENSION_MAP = { :javascript => 'js', :css => 'css' }
        
        def alongside_files(types = [ :javascript, :css ])
          Proc.new do |filename|
            out = { }
            
            types.each do |type|
              raise "Don't know extension for aggregates of type #{type.inspect}; check #{self.name}::AGGREGATE_TYPE_TO_EXTENSION_MAP" unless AGGREGATE_TYPE_TO_EXTENSION_MAP[type]
              
              file = filename
              file = $1 if file =~ %r{^(.*/[^/\.]+)\.[^/]+$}i
              file += ("." + AGGREGATE_TYPE_TO_EXTENSION_MAP[type])
              out[type] = file if File.exist?(file)
            end
            
            out
          end
        end
        
        def rendering_template(view, template)
          @on_view_proc.call(view, template) if @on_view_proc
        end
        
        def use_implicit_references(predefined, &proc)
          if (!proc) && predefined
            proc = send(predefined) if respond_to?(predefined)
          end
          
          install!
          
          @on_view_proc = Proc.new do |view, template|
            controller = view.controller
            reference_targets = proc.call(template.filename)
            
            if reference_targets && (! reference_targets.empty?)
              unless controller.respond_to?(:asset_aggregator_page_reference_set)
                raise "Unable to add references to your controller #{controller}; it doesn't respond to #asset_aggregator_page_reference_set. Did you remember to 'include AssetAggregator::Rails::ControllerMethods' in your ApplicationController?"
              end
              
              reference_set = controller.asset_aggregator_page_reference_set
              reference_targets.each do |aggregate_type_symbol, targets|
                targets = Array(targets).map do |target|
                  target = AssetAggregator::Core::SourcePosition.new(target, nil) if target.kind_of?(String)
                end.compact.uniq
                
                targets.each do |target|
                  reference_set.require_fragment(aggregate_type_symbol, target, AssetAggregator::Core::SourcePosition.new(template.filename, nil), "implicit view reference")
                end
              end
            end
          end
        end
        
        def install!
          unless @installed
            ActionView::Template.module_eval <<-END
              def render_template_with_asset_aggregator_per_view_references(view, *args)
                AssetAggregator::Rails::PerViewReferences.rendering_template(view, self)
                render_template_without_asset_aggregator_per_view_references(view, *args)
              end
          
              alias_method_chain :render_template, :asset_aggregator_per_view_references
            END
            @installed = true
          end
        end
      end
    end
  end
end
