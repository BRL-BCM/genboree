#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'

require 'rinda/tuplespace'
#port = rand(5000) + 2096
#port = 4615 + 2096
port = 6690
puts "Tuplespace is on port #{port}"
ts = Rinda::TupleSpace.new
DRb.start_service("druby://brl2.brl.bcm.tmc.edu:#{port}", ts)
puts "Rinda listening on #{DRb.uri}..."
DRb.thread.join
