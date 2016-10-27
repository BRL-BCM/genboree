#!/usr/bin/env ruby
#
# THIS FILE NOT COMPLIANT WITH BRL/GENBOREE STANDARDS
require "brl/util/textFileUtil"

scrmap =  {
            "acen" => -1.0,
            "gneg" => 0,
            "gpos100" => 1.0,
            "gpos25" => 0.25,
            "gpos33" => 0.25,
            "gpos50" => 0.50,
            "gpos66" => 0.50,
            "gpos75" => 0.75,
            "gvar" => 1.0,
            "stalk" => -1.0
          }
reader = BRL::Util::TextReader.new(ARGV[0])
reader.each {|ll|
  ff=ll.strip.split(/\t/)
  ff[0] =~ /chr(\S+)/
  chrID=$1
  puts "Marker\t#{chrID}#{ff[3]}\tCyto\tBand\t#{ff[0]}\t#{ff[1].to_i+1}\t#{ff[2]}\t\+\t\.\t#{scrmap[ff[4]]}\t.\t.\tbandType=#{ff[4]};"
}

exit(0)
