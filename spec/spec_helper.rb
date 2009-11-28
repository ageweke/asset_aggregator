dir = File.dirname(__FILE__)
require "rubygems"
$LOAD_PATH.unshift("#{dir}/../lib")
ARGV.push(*File.read("#{File.dirname(__FILE__)}/spec.opts").split("\n"))
require "spec"
require "spec/autorun"
require File.join(dir, "..", "init")
