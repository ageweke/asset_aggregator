module AssetAggregator
  module Core
    class PageReferencesOutputHandler
      def initialize(asset_aggregator, options_in = { })
        require 'stringio'
        @out = StringIO.new
        @asset_aggregator = asset_aggregator
        
        options = {
          :verbose                                             => integration.include_dependency_tag_comments?,
          :max_css_link_tags                                   => 31,
          :include_fragment_dependencies_instead_of_aggregates => integration.include_fragment_dependencies_instead_of_aggregates?
        }.merge(options_in)
        
        @verbose = options[:verbose]
        @max_css_link_tags = options[:max_css_link_tags]
        @include_fragment_dependencies_instead_of_aggregates = options[:include_fragment_dependencies_instead_of_aggregates]
        @type_to_extension_map = {
          :javascript => 'js', :css => 'css'
        }.merge(options[:type_to_extension_map] || { })
      end
      
      def start_all
        output_if_verbose "<!-- BEGIN AssetAggregator Includes -->"
        
        if @include_fragment_dependencies_instead_of_aggregates
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
      
      def start_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
        output_if_verbose "  <!-- Begin #{aggregate_type} includes -->"
        
        if aggregate_type == :css && need_to_import_css_instead?(subpath_references_pairs_this_type)
          output_if_verbose "    <!-- HACK HACK HACK: "
          output_if_verbose "         Internet Explorer can't handle more than 31 linked CSS stylesheets "
          output_if_verbose "         per page. We're therefore outputting a bunch of @import tags instead, "
          output_if_verbose "         because we have #{subpath_references_pairs_this_type.length} stylesheets to import."
          output_if_verbose "         (This number might be smaller than 32 if you've set :max_css_link_tags.)"
          output_if_verbose "         This is disgusting, but necessary. "
          output_if_verbose "    -->"
          output "    <style media=\"all\" type=\"text/css\">"
          output "    <!--"
          @output_as_imports = true
        else
          @output_as_imports = false
        end
      end
      
      def aggregate(aggregate_type, subpath, references)
        if @include_fragment_dependencies_instead_of_aggregates
          aggregate_fragments(aggregate_type, subpath, references)
        else
          aggregate_whole(aggregate_type, subpath, references)
        end
      end
      
      def end_aggregate_type(aggregate_type, subpath_references_pairs_this_type)
        if @output_as_imports
          output "    -->"
          output "    </style>"
        end
        output_if_verbose "  <!-- End #{aggregate_type} includes -->"
      end
      
      def end_all
        output_if_verbose "<!-- END AssetAggregator Includes -->"
      end
      
      def text
        @out.string
      end
      
      private
      def current_comment_start
        @output_as_imports ? "/*" : "<!--"
      end
      
      def current_comment_end
        @output_as_imports ? "*/" : "-->"
      end
      
      def aggregate_whole(aggregate_type, subpath, references)
        output_if_verbose "    #{current_comment_start} Aggregate '#{integration.html_escape(subpath)}' is required by:"
        references.each do |reference|
          text = "          #{reference}"
          if reference.kind_of?(AssetAggregator::Core::FragmentReference)
            text += ", which has been aggregated to '#{subpath}'"
          end
          output_if_verbose text
        end
        output_if_verbose "    #{current_comment_end}"
        output "    #{aggregate_include_tag_for(aggregate_type, subpath)}"
        output_if_verbose ""
      end
      
      def aggregate_fragments(aggregate_type, subpath, references)
        if references.detect { |r| r.kind_of?(AssetAggregator::Core::AggregateReference) }
          output_if_verbose "    <!-- NOTE: Aggregate '#{integration.html_escape(subpath)}' is explicitly required (as an aggregate), "
          output_if_verbose "         so we have to include it as such, even though you're asking for fragments "
          output_if_verbose "         separately. -->"
          aggregate_whole(aggregate_type, subpath, references)
        else
          references.each do |reference|
            fragment = asset_aggregator.fragment_for(aggregate_type, reference.fragment_source_position)
            raise "This reference points to a fragment that doesn't exist. Please check the location and try again.\n#{reference}" unless fragment
            output_if_verbose "    <!-- #{reference}: -->"
            output "    #{fragment_include_tag_for(aggregate_type, reference.fragment_source_position)}"
            output_if_verbose ""
          end
        end
      end
      
      def need_to_import_css_instead?(subpath_references_pairs_this_type)
        if @include_fragment_dependencies_instead_of_aggregates
          (subpath_references_pairs_this_type.map { |(subpath, references)| references.length }.inject(0) { |m,o| m + o }) > @max_css_link_tags
        else
          subpath_references_pairs_this_type.length > @max_css_link_tags
        end
      end
      
      def output(s)
        @out.puts s
      end
      
      def output_if_verbose(s)
        output(s) if @verbose
      end
      
      def asset_aggregator
        @asset_aggregator
      end
      
      def integration
        asset_aggregator.integration
      end
      
      def cache_bust(url, mtime)
        return url unless mtime
        
        if url =~ /\?/
          url + "&_aamt=#{mtime.to_i}"
        else
          url + "?#{mtime.to_i}"
        end
      end
      
      def include_tag_for_url(aggregate_type, url)
        case aggregate_type
        when :javascript then integration.javascript_include_tag(url)
        when :css
          if @output_as_imports
            "@import url(#{url});\n"
          else
            integration.stylesheet_link_tag(url)
          end
        else
          method = "#{aggregate_type}_aggregate_include_tag".to_sym
          if integration.respond_to?(method)
            integration.send(method, url)
          else
            raise "Don't know how to take a URL and turn it into HTML that references that URL (e.g., the equivalent of <script src=\"...\">) for aggregates of type #{aggregate_type.inspect}; please either implement ##{method} in your Integration implementation, or else subclass #{self.class.name}, override #include_tag_for_url, and pass it in to PageReferenceSet#include_text."
          end
        end
      end
      
      def extension_for(aggregate_type)
        @type_to_extension_map[aggregate_type] || raise("Don't know what extension #{aggregate_type.inspect} references should have in their URL; please supply options[:type_to_extension_map][#{aggregate_type.inspect}]")
      end
      
      def aggregate_subpath_url_for(aggregate_type, subpath)
        url = asset_aggregator.aggregate_url(aggregate_type, subpath)
        cache_bust(url, asset_aggregator.mtime_for(aggregate_type, subpath))
      end
      
      def aggregate_include_tag_for_url(aggregate_type, subpath, url)
        include_tag_for_url(aggregate_type, url)
      end
      
      def aggregate_include_tag_for(aggregate_type, subpath)
        aggregate_include_tag_for_url(aggregate_type, subpath, aggregate_subpath_url_for(aggregate_type, subpath))
      end
      
      def fragment_url_for(aggregate_type, source_position)
        extension = extension_for(aggregate_type)
        
        path = integration.base_relative_path(source_position.file)
        path = path.split(%r{/+})
        path[-1] = $1 if path[-1] =~ /^(.*)\.#{extension}$/i
        
        path[-1] += ":#{source_position.line}" if source_position.line
        url = asset_aggregator.fragment_url(aggregate_type, source_position)
        cache_bust(url, asset_aggregator.fragment_mtime_for(aggregate_type, source_position))
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
