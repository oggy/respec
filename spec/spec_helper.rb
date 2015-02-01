ROOT = File.expand_path('..', File.dirname(__FILE__))
TMP = "#{ROOT}/spec/tmp"

$:.unshift "#{ROOT}/lib"
require 'respec'
require 'temporaries'
