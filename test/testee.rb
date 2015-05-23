#!/usr/bin/env ruby
require File.expand_path("../../lib/docopt.rb", __FILE__)

require 'json'

doc = <<DOCOPT
Usage:
  #{__FILE__} demo [<args>...]
  #{__FILE__} -v
DOCOPT

begin
  puts Docopt.docopt(doc, options_first: true).to_json
rescue Docopt::Exit => ex
  puts '"user-error"'
end
