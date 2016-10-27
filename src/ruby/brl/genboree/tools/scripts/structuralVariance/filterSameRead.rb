#!/usr/bin/env ruby

DEBUG=false

inF = ARGV[0]
sameRead = ARGV[1]
diffRead = ARGV[2]
minDist = ARGV[3].to_i

r  = File.open(inF, "r")
ws = File.open(sameRead, "w")
wd = File.open(diffRead, "w")

mateStruct = Struct.new("Mate", :pos1, :pos2)
l = nil
fSz = 0
r.each {|l|
  f = l.split(/\s+/)
  if ( (f[5].to_i-f[4].to_i>=minDist) && (f[8].to_i-f[7].to_i>=minDist)) then
    # parse actually different positions
    nMates = f[1].to_i
    if (nMates>2000) then
      nMates = 2000
    end
    posArray = []
#    $stderr.puts "look at rdNames #{f[9]} #{f[17]} #{f[25]}"
#    0.upto(nMates-1) {|i|
#      puts ">>>> #{f[9+i*8,8].join("\t")}"
#    }
    uniqueMates =""
    0.upto(nMates-1) {|i|
      crtPos = 9+i*8
      break if (crtPos>=f.size)
      rdName = f[9+i*8]
      pos1 = f[9+i*8+1].to_i
      pos2 = f[9+i*8+4].to_i
#      $stderr.puts "look at rdName #{rdName} same pos #{pos1} #{pos2}"
      found = false
      posArray.each {|s|
        if (pos1 == s.pos1 && pos2 == s.pos2) then
#          $stderr.puts "same pos #{pos1} #{pos2} == #{s.pos1} #{s.pos2}"
          found = true
          $stderr.puts "found ! #{pos1} #{pos2}  vs #{s.pos1} #{s.pos2}" if (DEBUG)
          break
        end
      }
      if (!found ) then
        posArray.push(mateStruct.new(pos1, pos2))
        uniqueMates << "\t#{f[9+i*8,8].join("\t")}"
        $stderr.puts "uniqueMates: #{uniqueMates}" if (DEBUG)
      else
        #puts "#{i}\t#{rdName}\t#{f[9+i*8,8].join("\t")}"
      end
    }
    if (posArray.size==1) then
      ws.print l
    else
      wd.puts "#{f[0]}\t#{posArray.size}\t#{f[2,7].join("\t")}\t#{uniqueMates}"
    end
  else
    ws.print l
  end
}
r.close()
ws.close()
wd.close()
