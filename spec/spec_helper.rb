$:.unshift File.expand_path('../lib', File.dirname(__FILE__))
require 'respec'
require 'temporaries'

ROOT = File.expand_path('..', File.dirname(__FILE__))
TMP = "#{ROOT}/spec/tmp"
