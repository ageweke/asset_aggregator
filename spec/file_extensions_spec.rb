require 'spec/spec_helper'
require 'fileutils'

describe File do
  describe "#canonical_path" do
    it "should work for an extant file" do
      File.canonical_path("/bin/cp").should == "/bin/cp"
    end
    
    it "should work for an extant directory" do
      File.canonical_path("/usr/bin").should == "/usr/bin"
    end
    
    it "should work for the root" do
      File.canonical_path("/").should == "/"
    end
    
    it "should remove double-slashes" do
      File.canonical_path("//usr//bin//").should == "/usr/bin"
    end
    
    it "should work for a nonexistent file" do
      File.canonical_path("/bin/this_should_never_exist").should == "/bin/this_should_never_exist"
    end
    
    it "should work for a nested nonexistent file" do
      File.canonical_path("/bin/this/should/never/exist").should == "/bin/this/should/never/exist"
    end
    
    describe "with some symlinks" do
      def with_setup
        File.with_temporary_directory do |tempdir|
          FileUtils.mkdir_p(File.join(tempdir, "foo"))
          FileUtils.mkdir_p(File.join(tempdir, "bar"))
          
          Dir.chdir(tempdir) do
            yield Pathname.new(tempdir).realpath.to_s
          end
        end
      end
      
      it "should resolve one symlink" do
        with_setup do |tempdir|
          FileUtils.ln_s('foo', 'baz')
          File.canonical_path(File.join(tempdir, "baz")).should == File.join(tempdir, "foo")
        end
      end
      
      it "should resolve an extant file underneath a symlink" do
        with_setup do |tempdir|
          FileUtils.ln_s('foo', 'baz')
          FileUtils.touch(File.join(tempdir, "foo", "bonk"))
          File.canonical_path(File.join(tempdir, "baz", "bonk")).should == File.join(tempdir, "foo/bonk")
        end
      end
      
      it "should resolve a nonexistent file underneath a symlink" do
        with_setup do |tempdir|
          FileUtils.ln_s('foo', 'baz')
          File.canonical_path(File.join(tempdir, "baz", "bonk")).should == File.join(tempdir, "foo/bonk")
        end
      end
      
      it "should resolve a file through two symlinks" do
        with_setup do |tempdir|
          FileUtils.ln_s('foo', 'baz')
          FileUtils.ln_s('baz', 'quux')
          FileUtils.touch(File.join(tempdir, "foo", "bonk"))
          File.canonical_path(File.join(tempdir, "quux", "bonk")).should == File.join(tempdir, "foo/bonk")
        end
      end
      
      it "should resolve a file through two symlinks along its path" do
        with_setup do |tempdir|
          FileUtils.ln_s('foo', 'baz')
          FileUtils.mkdir_p('foo/quux')
          FileUtils.ln_s('quux', 'foo/marph')
          File.canonical_path(File.join(tempdir, "baz", "marph", "mongo")).should == File.join(tempdir, "foo/quux/mongo")
        end
      end
    end
  end
end
