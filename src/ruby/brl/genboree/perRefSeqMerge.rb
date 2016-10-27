#!/usr/bin/env ruby
require 'brl/util/util'

# called like this:
# ./perRefSeqMerge.rb complete-sortByMouse-k5-e10-s40.txt.k5e10s40-RefSeqIsMouse.lff "Mm%chr%-b2" RefSeqIsMouse pseudoSynteny.lff

chroms = [ 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,'X','Y' ]
$stderr.puts("Yer args:")
$stderr.puts(ARGV.inspect)

fileName = ARGV[0]
refSeqPattern = ARGV[1]
outDir = ARGV[2]
propFile = ARGV[3]
mergePattern = ARGV[4]

chroms.each {
	|chrom|
	# make a dir for this chrome
	dirName = "./#{outDir}/#{chrom}-mergeResults"
	outFile = "chr#{chrom}.only"
	outFilePath = "#{dirName}/#{outFile}"
	Dir.recursiveSafeMkdir(dirName)
	unless(FileTest.exist?(outFilePath))
		# Chunk the file
		pattern = refSeqPattern.gsub("%chr%", chrom.to_s)
		cmd = "/home/hgsc/bin/grep \"#{pattern}\" #{fileName} > #{outFilePath}"
		puts cmd
		puts `#{cmd}`
	end
	currDir = Dir.pwd()
	Dir.chdir(dirName)
	# submit the bsub job to merge the files (not needed)
	cmd = "time ~brl/bin/lffMerger.rb -p #{propFile} -f ./chr#{chrom}.only"
	puts `#{cmd}`

	Dir.chdir(currDir) # go back up to where we were
}
# Merge all the results into 1 file
cmd = "cat ./#{outDir}/*mergeResults/*#{mergePattern} > ./#{outDir}/#{File.basename(fileName)}.#{mergePattern}.merged.lff"
puts `#{cmd}`
exit(0)

