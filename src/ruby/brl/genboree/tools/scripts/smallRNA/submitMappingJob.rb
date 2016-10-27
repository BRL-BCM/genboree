#!/usr/bin/env ruby
require 'brl/util/textFileUtil'
if (ARGV.size == 0 || ARGV[0]=="-h" || ARGV[0]=="--help") then
	puts "submitMappingJob.rb <input file> <offsets file> <scratchDir> <jobName> <lff target file> <reference offsets file> <use_tags_flag>"
	exit(1)
end
inputFile=ARGV[0]
offsetsFile=ARGV[1]
scratchDir = ARGV[2]
jobName = ARGV[3]
lffFile = ARGV[4]
referenceInfo = ARGV[5]
tagString =" -t " 
if (ARGV.size>6 && ARGV[6]=="no") then
   tagString =" " 
end
fullScratchDir="#{scratchDir}/mapJob.#{Process.pid}"
system("mkdir -p #{fullScratchDir}")

labelsHash = {}
r = BRL::Util::TextReader.new(lffFile)
$stderr.sync = true
r.each {|l|
	f = l.split(/\t/)
	#$stderr.puts f[0,4].join("\t") 
    
	buff = ""
	buff << f[0] <<":" << f[2] <<":"<<f[3]
	if (!labelsHash.key?(buff)) then
		labelsHash[buff]=1
		$stderr.puts "added track #{buff}"
	end
}
r.close()

# collect lff class:type:subtype
newLabel=""
label=nil
labelsHash.keys.each {|label|
	if (label=~/(\S+):(\S+):(\S+)/) then 
		newLabel<< label <<";" << "#{jobName}:#{jobName}:#{$2}_#{$3};" 
	end
}
$stderr.puts "newLabel=#{newLabel}"
mappCommand="time mappingsOntoLff.exe -p #{inputFile} -l #{lffFile} -o #{jobName}.tracks.is "
mappCommand << " -T #{jobName}.trackintersection.is  -r #{offsetsFile} #{tagString} -R #{referenceInfo} -n #{jobName}.namecount.is "
mappCommand << " -s #{fullScratchDir}  -L out.#{jobName}.coverage.lff -N \"#{newLabel}\" > log.mappIntersect.#{jobName} 2>&1" 
$stderr.puts "mappings account command = #{mappCommand}"
system(mappCommand)
system("/bin/rm -rf #{fullScratchDir}")
