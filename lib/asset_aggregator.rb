# = #AssetAggregator
#
# #AssetAggregator was written to help solve software-engineering issues that
# cropped up in a large (> 1500 view templates/partials) Rails application
# at scribd.com. To wit:
#
# There's a natural tension in Javascript, CSS, and other assets that a modern
# Web application requires. JS/CSS typically "belongs" to a piece of HTML that's
# encapsulated in a view or partial; in a perfect world, it would therefore
# "live" with that view or partial -- inside the same file, or in a small file
# alongside it and encapsulated.
#
# The tension comes because, at runtime, you can't reasonably deliver your
# JS or CSS as hundreds and hundreds of tiny little files -- browsers will get
# very unhappy, or slow, at this. Browsers and runtime therefore wants your
# assets to be in a small number of large files -- the exact opposite of what
# software-engineering practices would deem best.
#
# There are currently (at least) three solutions to this:
#
#   * Store your JS/CSS on disk as a few big files (typically under public/);
#     tell your developers to carefully maintain them, including comments about
#     what view source file the CSS/JS goes with, and to remember to delete
#     dead code. Sounds great; in our experience, doesn't actually work very
#     well, as developers (yours truly especially) are lazy.
#
#   * Use the asset_packager[http://synthesis.sbecker.net/pages/asset_packager]
#     to package up your multiple source files into larger, aggregated files
#     for delivery. This is a huge, huge improvement, and a very nice piece of
#     software. In our experience, though, there was a caveat: =asset_packages.yml=
#     is manually maintained. You're therefore at the mercy of every developer
#     to /pick/ an appropriate source file to put his or her JS/CSS into, to
#     add it to =asset_packages.yml=, and to remember to remove it when done.
#     Also, at the kind of granularity we really wanted (e.g., one CSS source
#     file per view that needs CSS), =asset_packages.yml= gets very big.
#     Really, we wanted something rule-based, that allowed a complete decoupling
#     of the two primary responsibilities -- "I made a new view/partial and
#     need to put the CSS/JS some place" vs. "I need to control how all these
#     JS/CSS source files roll up into assets delivered at runtime".
#
#   * This package, the #AssetAggregator. It lets you define how small chunks
#     of assets 'roll up' (aggregate) into the aggregate JS/CSS files that get
#     delivered at runtime, programmatically. It also adds features that let
#     you override this code on a case-by-case basis, filter content (e.g.,
#     jsmin for JS, ERb, Less[http://lesscss.org/] for CSS, etc.) before delivery,
#     include either the original fragments directly (useful for development)
#     or the aggregated assets, and automatically handle dependencies -- you
#     don't need to think about your include tags in the <head>;
#     #AssetAggregator will determine what needs to be included based on the
#     views and partials you render, and output the right tags, fully
#     commented with exactly why they're required.
#
# = Using the Asset Aggregator
#
# Add something like the following to =config/environment.rb=:
#
#   AssetAggregator.aggregate :javascript do
#     add :asset_packager_compatibility
#     add :files, File.join(Rails.root, 'app', 'views'), 'js'
#   end
#
# Let's break that down:
#
#   * =:javascript= is the /type/ to aggregate. Different types aggregate
#     completely separately, meaning you can use totally different rules for
#     CSS than for Javascript. The type can actually be any arbitrary symbol,
#     although if you use something other than the predefined =:javascript=
#     or =:css= you'll have to pass an object compatible with
#     #AssetAggregator::Core::OutputHandler as the second argument to #aggregate
#     so that we know how to, textually speaking, "glue" together a bunch
#     of code fragments to make a delivered, aggregated asset.
#
#   * =add= adds a new /aggregator/ (a subclass of #AssetAggregator::Core::Aggreagtor)
#     to this type. An aggregator is an object that understands how to
#     "scoop up" fragments of content according to some particular set of rules.
#     In this case, we have two aggregators:
#
#         * =:asset_packager_compatibility= (which gets turned into the class
#           #AssetAggregator::Aggregators::AssetPackagerCompatibilityAggregator
#           via Rails-style naming rules; you can pass an actual #Class object
#           if defining your own), which takes no arguments and knows how to
#           emulate what the asset_packager[://synthesis.sbecker.net/pages/asset_packager]
#           does;
#
#         * =:files= (which similarly becomes #AssetAggregator::Aggregators::FileAggregator),
#           which takes two arguments, a directory and an extension (or #Array
#           of extensions); it "scoops up" all the files under the given
#           directory with the given extension(s), and makes them available under
#           a subpath that depends on the path to the file. (Basically, it
#           uses the top-level subdirectory under =#{Rails.root}/app/*= if the
#           file's under there, so =#{Rails.root}/app/views/foo/bar/baz.js
#           shows up in a file called =foo.js=; otherwise, it uses the
#           name of the file without any extensions, so =/foo/bar/baz.bar.js=
#           shows up in a file called =baz.js=.) You can control the mapping to
#           subpaths and which files get included very easily; see the
#           documentation for #AssetAggregator::Aggregators::FileAggregator
#           for details.
#
# OK, so now you have aggregation mappings set up. But you need to define a
# way to actually deliver the given assets. The easiest way to do this is to
# create a new controller to do so:
#
#    app/controllers/aggregated_controller.rb
#    class AggregatedController < ApplicationController
#      include AssetAggregator::Rails::AggregatedController
#    end
#
#    config/routes.rb
#      ...
#      map.aggregate aggregated/
#
# #AssetAggregator::Rails::AggregatedController will automatically add methods
# to this controller that are named after any types you've aggregated
#
#
#
# = Ordering
#
# When including various assets, ordering is important -- this is true for both
# JavaScript and CSS, as later JS or CSS can change the behavior of earlier JS
# or CSS. 
#
# The #AssetAggregator follows these principles about ordering:
#
#   * Ordering among #Aggregator objects is defined. If, inside your #aggregate
#     call, you #add two aggregators in order, then, in any aggregated file that
#     contains content from both, all content from the first #Aggregator will
#     precede all content from the second #Aggregator.
#
#   * All other ordering is alphabetical: within a single #Aggregator, content
#     in an aggregated file will be ordered alphabetically by pathname, and,
#     within a pathname, by source line number (in the rare case where you add
#     multiple fragments of content from a single source file -- Erector widgets
#     with inline assets are about the only case where this can happen currently).
#     Also, if you use the automated reference-tracking capabilities of the
#     #AssetAggregator, then references will be added in alphabetical order by
#     aggregated filename.
#
# This may seem somewhat inflexible. However, it (a) allows dramatically simpler
# configuration, (b) provides a deterministic ordering (moving your code to
# another machine that happens to return files in a directory in a different
# order won't suddenly break things), and (c) still lets you control ordering
# anyway, by using naming schemes in your files to control ordering.
module AssetAggregator
  class << self
    def standard_instance
      @standard_instance ||= Impl.new
    end
    
    def output_options
      standard_instance.output_options
    end
    
    def output_options=(x)
      standard_instance.output_options = x
    end
    
    def on_encryption(&proc)
      AssetAggregator::OutputHandlers::CommonOutputHandler.on_encryption(&proc)
    end
    
    def aggregate(type, output_handler_creator = nil, &definition_proc)
      standard_instance.set_aggregate_type(type, output_handler_creator, definition_proc)
    end
    
    def aggregated_subpaths_for(type, fragment_source_position)
      standard_instance.aggregated_subpaths_for(type, fragment_source_position)
    end

    def each_aggregate_reference_in_set(reference_set, type, &block)
      standard_instance.each_aggregate_reference_in_set(reference_set, type, &block)
    end
    
    def fragment_for(type, fragment_source_position)
      standard_instance.fragment_for(type, fragment_source_position)
    end
    
    def fragment_content_for(type, fragment_source_position)
      standard_instance.fragment_content_for(type, fragment_source_position)
    end
    
    def refresh!
      standard_instance.refresh!
    end
    
    def all_types
      standard_instance.all_types
    end
    
    def all_subpaths(type)
      standard_instance.all_subpaths(type)
    end
    
    def content_for(type, subpath)
      standard_instance.content_for(type, subpath)
    end
  end
  
  class Impl
    def initialize
      @aggregate_types = { }
      @file_cache = AssetAggregator::Core::FileCache.new
      
      if ::Rails.env.development?
        @output_options = {
          :header_comment     => :full,
          :aggregator_comment => :full,
          :fragment_comment   => :full
        }
      else
        @output_options = {
          :header_comment     => :none,
          :aggregator_comment => :brief,
          :fragment_comment   => :brief
        }
      end
    end
    
    def output_options=(options)
      @output_options = options
    end
    
    def output_options
      @output_options
    end

    def set_aggregate_type(type, output_handler_creator, definition_proc)
      output_handler_creator = Proc.new do |*args|
        output_handler_class = "AssetAggregator::OutputHandlers::#{type.to_s.camelize}OutputHandler".constantize
        args << @output_options
        output_handler_class.new(*args)
      end
      
      @aggregate_types[type.to_sym] = AssetAggregator::Core::AggregateType.new(type, @file_cache, output_handler_creator, definition_proc)
    end
    
    def aggregated_subpaths_for(type, fragment_source_position)
      type = @aggregate_types[type] || (raise "No such aggregate type #{type.inspect}")
      type.aggregated_subpaths_for(fragment_source_position)
    end
    
    def each_aggregate_reference_in_set(reference_set, type, &block)
      reference_set.each_aggregate_reference(type, self, &block)
    end
    
    def all_types
      @aggregate_types.keys
    end

    def content_for(type, subpath)
      aggregate_type(type).content_for(subpath)
    end
    
    def all_subpaths(type)
      out = [ ]
      type = @aggregate_types[type]
      out = type.all_subpaths if type
      out
    end
    
    def fragment_content_for(type, fragment_source_position)
      out = nil
      type = @aggregate_types[type]
      out = type.fragment_content_for(fragment_source_position) if type
      out
    end
    
    def fragment_for(type, fragment_source_position)
      out = nil
      type = @aggregate_types[type]
      out = type.fragment_for(fragment_source_position) if type
      out
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
