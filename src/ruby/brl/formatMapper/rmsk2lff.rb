#!/usr/bin/env ruby
# Maybe want to put in newlines?? Nahhh....

if(ARGV.length < 1)
  puts "\n\nUSAGE:\n   rmsk2lff.rb chr14_rmsk.txt.gz\n\n"
else
  hh=Hash.new(0); subtypes={ "RNA"=>"RNA","scRNA"=>"RNA","tRNA"=>"RNA", "rRNA"=>"RNA", "srpRNA"=>"RNA", "Satellite"=>"Satellite","snRNA"=>"RNA", "Other"=>"Other", "Unknown"=>"Unknown", "LINE" => "LINE", "DNA"=> "DNA","LTR" => "LTR", "Low_complexity" => "LowComplex", "SINE" => "SINE", "Simple_repeat" => "Simple" } ; reader = BRL::Util::TextReader.new(ARGV[0]) ; reader.each {|ll| ff=ll.strip.split("\t"); unless(subtypes.key?(ff[11])) then $stderr.puts "UNK class: #{ff[11]}" ; end ; nn="#{ff[12]}.#{ff[10]}" ; hh[nn]+=1; ff[5]=~/chr(\S+)/; chrID=$1; puts "Repeat\t#{nn}.#{chrID}.#{hh[nn]}\tRepeat\t#{subtypes[ff[11]]}\t#{ff[5]}\t#{ff[6].to_i+1}\t#{ff[7]}\t#{ff[9]}\t\.\t#{ff[1]}\t.\t.\trepName=#{ff[10]}; repClass=#{ff[11]}; repFamily=#{ff[12]}; repStart=#{ff[13]}; repEnd=#{ff[14]}; repLeft=#{ff[15]}; milliDiv=#{ff[2]}; milliDel=#{ff[3]}; milliIns=#{ff[4]}; genoLeft=#{ff[5]}; ucscId=#{ff[16]}; "; } ;
end
exit
