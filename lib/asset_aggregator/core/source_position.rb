module AssetAggregator
  module Core
    # A SourcePosition represents the pair of a file (absolute, canonical path) and,
    # optionally, a line number. It's used to capture references to blocks of asset
    # code, to sort by file and line, and to print into comments that tell us in the
    # aggregates where the code came from.
    class SourcePosition
      class << self
        # Returns a SourcePosition representing the line of code that is calling
        # #for_here.
        def for_here
          levels_up_stack(1)
        end
      
        # Returns a SourcePosition representing the specified number of levels up the
        # stack. levels == 0 means 'the line of code calling #levels_up_stack', 
        # levels == 1 means the caller of that method, and so on.
        def levels_up_stack(levels)
          line = caller(levels + 1)[0]
          if line =~ /^([^:]+):(\d+)/
            new($1, $2.to_i)
          else
            new(line)
          end
        end
      end
      
      # Gives us ==, <, >, <=, >=
      include Comparable
    
      attr_reader :file, :line
      
      # Creates a new instance representing the given file and line number.
      def initialize(file, line)
        @file = File.canonical_path(file).strip
        @line = line
        @line = @line.to_i if @line
      end
      
      # A hash of this object, so we can, you know, use it as a key in hashes.
      def hash
        file.hash ^ line.hash
      end
      
      # Compares two instances. Instances with files, but no line numbers, compare
      # before instances with the same file, but any line number at all. Instances
      # with different files compare in alphabetical order of their files.
      def <=>(other)
        out = (file <=> other.file)
        
        if out == 0
          out = (line <=> other.line) if line && other.line
          out = 1 if line && (! other.line)
          out = -1 if (! line) && other.line
        end
        
        out
      end
    
      # Like #file, but uses the supplied #Integration object to provide a path
      # relative to the integration base directory, if this file is under it.
      def terse_file(integration = nil)
        if integration then integration.base_relative_path(@file) else @file end
      end
      
      # Returns a string like "/foo/bar/baz:123"; uses #terse_file, above, so if
      # you pass an #Integration object to it, it will trim off the base directory,
      # if needed.
      def to_s(integration = nil)
        if @line then "#{terse_file(integration)}:#{@line}" else terse_file(integration) end
      end
    end
  end
end
