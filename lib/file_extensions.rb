class File
  class << self
    def extname_no_dot(path)
      out = extname(path)
      out = $1 if out =~ /^\.+(.*)$/
      out
    end
  end
end
