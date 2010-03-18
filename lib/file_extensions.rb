class File
  class << self
    def extname_no_dot(path)
      out = extname(path)
      out = $1 if out =~ /^\.+(.*)$/
      out
    end
    
    def canonical_path(p)
      extant = File.expand_path(p)
      suffix = ""
      until File.exist?(extant)
        suffix = File.join(File.basename(extant), suffix)
        extant = File.dirname(extant)
      end
      
      extant = Pathname.new(extant).realpath.to_s
      out = File.join(extant, suffix)
      out = $1 if out =~ %r{^(.+?)\s*/+\s*$}i
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
