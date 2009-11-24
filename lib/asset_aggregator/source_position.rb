module AssetAggregator
  class SourcePosition
    class << self
      def for_here
        levels_up_stack(1)
      end
      
      def levels_up_stack(levels = 0)
        line = caller(levels + 1)[0]
        if line =~ /^([^:]+):(\d+)/
          new($1, $2.to_i)
        else
          new(line)
        end
      end
    end
    
    attr_reader :file, :line
    
    def initialize(file, line)
      @file = File.expand_path(file).strip
      @line = line
      @line = @line.to_i if @line
    end
    
    def terse_file
      out = @file
      if (out.length > Rails.root.length + 1) && (out[0..(Rails.root.length - 1)] == Rails.root)
        out = out[(Rails.root.length)..-1]
        out = $1 if out =~ %r{[/\\]+(.*)$}
      end
      out
    end
    
    def to_s
      if @line then "#{terse_file}:#{@line}" else terse_file end
    end
  end
end
