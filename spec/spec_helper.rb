$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require 'respec'
require 'tmpdir'

ROOT = File.expand_path('..', File.dirname(__FILE__))
TMP = Dir.tmpdir
