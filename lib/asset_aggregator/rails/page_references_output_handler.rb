module AssetAggregator
  module Rails
    class PageReferencesOutputHandler
      def initialize(asset_aggregator, object_to_call_helper_methods_on, options = { })
        require 'stringio'
        @out = StringIO.new
        @asset_aggregator = asset_aggregator
        @object_to_call_helper_methods_on = object_to_call_helper_methods_on
        @options = options
        @options[:verbose] = true if (! @options.has_key?(:verbose)) && ::Rails.env.development?
      end
      
      def start_all
        output_if_verbose "<!-- BEGIN AssetAggregator Includes -->"
        
        if @options[:fragments]
          output_if_verbose ""
          output_if_verbose "<!-- NOTE:"
          output_if_verbose ""
          output_if_verbose "     The AssetAggregator was asked to output direct fragment references"
          output_if_verbose "     for this page. This is therefore NOT the output that you will receive"
          output_if_verbose "     in production, and, in fact, it may behave differently; this output"
          output_if_verbose "     method is useful for debugging, to see if you're relying on CSS/JS/etc."
          output_if_verbose "     that's only getting included incidentally, not directly. This is also"
          output_if_verbose "     why there may be a LOT of include tags on this page."
          output_if_verbose ""
          output_if_verbose "     You have been warned."
          output_if_verbose "-->"
          output_if_verbose ""
        end
      end
      
      def start_aggregate_type(aggregate_type)
        output_if_verbose "  <!-- Begin #{aggregate_type} includes -->"
      end
      
      def aggregate(aggregate_type, subpath, references)
        if options[:fragments]
          aggregate_fragments(aggregate_type, subpath, references)
        else
          aggregate_whole(aggregate_type, subpath, references)
        end
      end
      
      def aggregate_fragments(aggregate_type, subpath, references)
        if references.detect { |r| r.kind_of?(AssetAggregator::Core::AggregateReference) }
          output_if_verbose "    <!-- NOTE: Aggregate '#{h(subpath)}' is explicitly required (as an aggregate), "
          output_if_verbose "         so we have to include it as such, even though you're asking for fragments "
          output_if_verbose "         separately. -->"
          aggregate_whole(aggregate_type, subpath, references)
        else
          references.each do |reference|
            fragment = @asset_aggregator.fragment_for(aggregate_type, reference.fragment_source_position)
            raise "This reference points to a fragment that doesn't exist. Please check the location and try again.\n#{reference}" unless fragment
            output_if_verbose "    <!-- #{reference}: -->"
            output_if_verbose "    #{fragment_include_tag_for(aggregate_type, reference.fragment_source_position)}"
            output_if_verbose ""
          end
        end
      end
      
      def aggregate_whole(aggregate_type, subpath, references)
        output_if_verbose "    <!-- Aggregate '#{h(subpath)}' is required by:"
        references.each do |reference|
          text = "          #{reference}"
          if reference.kind_of?(AssetAggregator::Core::FragmentReference)
            text += ", which has been aggregated to '#{subpath}'"
          end
          output_if_verbose text
        end
        output_if_verbose "    -->"
        output "    #{aggregate_include_tag_for(aggregate_type, subpath)}"
        output_if_verbose ""
      end
      
      def end_aggregate_type(aggregate_type)
        output_if_verbose "  <!-- End #{aggregate_type} includes -->"
      end
      
      def end_all
        output_if_verbose "<!-- END AssetAggregator Includes -->"
      end
      
      def text
        @out.string
      end
      
      private
      attr_reader :object_to_call_helper_methods_on, :options
      
      def output(s)
        @out.puts s
      end
      
      def output_if_verbose(s)
        output(s) if @options[:verbose]
      end
      
      def h(s)
        ERB::Util.html_escape(s)
      end
      
      def cache_bust(url)
        url
      end
      
      def include_tag_for_url(aggregate_type, url)
        case aggregate_type
        when :javascript then object_to_call_helper_methods_on.javascript_include_tag(url)
        when :css then object_to_call_helper_methods_on.stylesheet_link_tag(url)
        else raise "Don't know how to take a URL and turn it into HTML that references that URL (e.g., the equivalent of <script src=\"...\">) for aggregates of type #{aggregate_type.inspect}; please subclass #{self.class.name}, override #aggregate_include_tag_for_url, and pass it in to PageReferenceSet#include_text"
        end
      end
      
      def extension_for(aggregate_type)
        out = (options[:extensions] || { })[aggregate_type]
        out ||= 'js' if aggregate_type == :javascript
        out ||= 'css' if aggregate_type == :css
        raise "Don't know what extension #{aggregate_type.inspect} references should have in their URL; please supply options[:extensions][#{aggregate_type.inspect}]" unless out
        out
      end
      
      def aggregate_subpath_url_for(aggregate_type, subpath)
        object_to_call_helper_methods_on.url_for(
          :controller => (options[:aggregated_controller_name] || 'aggregated'),
          :action => aggregate_type.to_s,
          :path => subpath.split(%r{/+}),
          :format => extension_for(aggregate_type),
          :only_path => false)
      end
      
      def aggregate_include_tag_for_url(aggregate_type, subpath, url)
        include_tag_for_url(aggregate_type, url)
      end
      
      def aggregate_include_tag_for(aggregate_type, subpath)
        aggregate_include_tag_for_url(aggregate_type, subpath, aggregate_subpath_url_for(aggregate_type, subpath))
      end
      
      
      def fragment_url_for(aggregate_type, source_position)
        extension = extension_for(aggregate_type)
        
        path = AssetAggregator::Core::SourcePosition.trim_rails_root(source_position.file)
        path = path.split(%r{/+})
        path[-1] = $1 if path[-1] =~ /^(.*)\.#{extension}$/i
        
        path[-1] += ":#{source_position.line}" if source_position.line
        object_to_call_helper_methods_on.url_for(
          :controller => (options[:aggregated_controller_name] || 'aggregated'),
          :action => "#{aggregate_type}_fragment",
          :path => path,
          :format => extension_for(aggregate_type),
          :only_path => false)
      end
      
      def fragment_include_tag_for_url(aggregate_type, subpath, url)
        include_tag_for_url(aggregate_type, url)
      end
      
      def fragment_include_tag_for(aggregate_type, source_position)
        fragment_include_tag_for_url(aggregate_type, source_position, fragment_url_for(aggregate_type, source_position))
      end
    end
  end
end
