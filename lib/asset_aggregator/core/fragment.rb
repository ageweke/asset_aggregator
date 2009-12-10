module AssetAggregator
  module Core
    # A #Fragment is one of the key pieces of the #AssetAggregator. It represents an
    # undecomposable fragment of content -- for example, some JavaScript or some CSS code --
    # that will get wrapped up into an aggregated asset by an #Aggregator.
    #
    # Each fragment records its content, its #SourcePosition (file, or file and line,
    # as appropriate), and its +target_subpath+ -- the subpath it should end up at when
    # being aggregated. It's up to the #Aggregator that creates this #Fragment to decide
    # what the target subpath should be, as each #Aggregator may assign it differently,
    # based on the directory the file is in, a configuration file, a line of code, or
    # whatever else.
    #
    # #Fragment objects are #Comparable, and #hash correctly; they compare and hash
    # based on their +source_position+ only. It turns out that for our uses, this is
    # most useful. If you need to compare them based on +content+ or +target_subpath+,
    # you're welcome to add your own methods or make your own wrapper. Don't change these,
    # though, or things will break.
    class Fragment
      include Comparable
      
      attr_reader :target_subpath, :source_position, :content
      
      # Creates a new instance. +target_subpath+ is the target subpath that this
      # #Fragment should end up at, without the extension or URL prefix (e.g.,
      # +foo/bar/baz+ for something that might end up accessed as
      # +http://myhost/javascripts/aggregated/foo/bar/baz.js+). +source_position+
      # is a #SourcePosition instance, representing the file this #Fragment came
      # from (or file and line, if it's not the entire file); +content+ is the actual
      # content of the data, byte-for-byte verbatim.
      def initialize(target_subpath, source_position, content)
        @target_subpath = target_subpath
        @source_position = source_position
        @content = content
      end
      
      # Returns a hash code for this #Fragment; as stated in the class comment, this 
      # compares only on the #SourcePosition.
      def hash
        source_position.hash
      end
    
      # Compares this #Fragment to another #Fragment. We also include #Comparable so
      # we get ==, <, >=, etc. As stated in the class comment, this compares only on
      # the #SourcePosition.
      def <=>(other)
        source_position <=> other.source_position
      end
    end
  end
end
