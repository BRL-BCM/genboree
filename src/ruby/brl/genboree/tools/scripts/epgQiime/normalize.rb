#!/usr/bin/env ruby

require 'brl/util/util'
require 'getoptlong'
require 'brl/genboree/rest/apiCaller'



# Quick getoptlong parsing that's linear in flow

vars = [:inputFile,:outputFile,:mult]
varTypes = {:mult => GetoptLong::OPTIONAL_ARGUMENT}
defVals = {:mult => 100000}
optsArray = []
vars.each{|vv|
  varType = GetoptLong::REQUIRED_ARGUMENT
  varType=varTypes[vv] unless varTypes[vv].nil?
  optsArray << ["--#{vv.to_s}","-#{vv.to_s[0].chr}", varType]
}
progOpts = GetoptLong.new(*optsArray)
optsHash = progOpts.to_hash
if(!progOpts.getMissingOptions().empty? or optsHash.empty?) then
  puts "missing options #{vars.inspect}"
  exit;
else
  vals = {}
  vars.each{|vv|
    vals[vv] = optsHash["--#{vv.to_s}"]
    if(vals[vv].nil? and !defVals[vv].nil?) then vals[vv] = defVals[vv] end
  }
end


lines = []
sums = Hash.new(0)
fh = File.open(File.expand_path(vals[:inputFile]),"r")
ofh = File.open(File.expand_path(vals[:outputFile]),"w")
fh.each_line{|line|
  if(line =~ /^#/) then
    ofh.puts line.chomp
  else
    # First column is assumed to be id and not normalized
    sl = line.chomp.split(/\t/)
    lines << sl
    sl.each_index{|ii|
      if(ii!=0) then
        sums[ii] += sl[ii].to_f
      end
      }
  end
  }
fh.close
puts sums.inspect
lines.each{|ll|
  ll.each_index{|ii|
    if(ii == 0) then
      ofh.print ll[ii]
    else
      ofh.print("\t#{ll[ii].to_f/sums[ii].to_f*vals[:mult].to_f}")
    end
    }
  ofh.puts
  }
ofh.close
