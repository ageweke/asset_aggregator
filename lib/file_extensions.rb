class File
  class << self
    def extname_no_dot(path)
      out = extname(path)
      out = $1 if out =~ /^\.+(.*)$/
      out
    end
    
    def canonical_path(p)
      return '/' if p == '/'
      p = File.expand_path(p)
      out = canonical_path(File.dirname(p))
      if File.symlink?(p)
        out = canonical_path(File.expand_path(File.join(out, File.readlink(p))))
      else
        out = File.join(out, File.basename(p))
      end
      out
    end
    
    def with_temporary_directory
      require 'tempfile'
      require 'fileutils'

      tempfile = Tempfile.new(File.basename(__FILE__))
      tempfile_path = tempfile.path
      tempfile.close!
      File.delete(tempfile_path) if File.exist?(tempfile_path)
      begin
        FileUtils.mkdir_p(tempfile_path)
        yield tempfile_path
      ensure
        FileUtils.rm_rf(tempfile_path) if File.exist?(tempfile_path)
      end
    end
  end
end
