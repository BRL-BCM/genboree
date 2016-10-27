#!/usr/bin/env ruby
@niceSizes = [ 8, 8, 8, 7, 6, 5, 3, 6, 5, 1, 5, 13 ]
# First, get all qstat lines
cmd = 'qstat -n1 '
cmd += " | grep -P \"(?:^Job)|#{ARGV.first}\" " if(ARGV and ARGV.size > 0)
qstatLines = `#{cmd}`

# Next, get all the Job_Names, hashed by Job Id number
cmd = 'qstat -f | grep -P "(Job Id:|Job_Name = )"'
qstatFLines = `#{cmd}`
jobNames = {}
qstatFLines.scan(/Job Id:\s+(\d+).+?Job_Name\s+=\s+(\S+)/m) { |jobIdNum, fullJobName| jobNames[jobIdNum] = fullJobName }

# Next, create the output recs and gather @niceSizes info
outputRecs = []
qstatLines.each_line { |line|
  cols = line.strip.split(/\s+/)
  firstCol = cols.first
  # make rec
  if(firstCol =~ /^(\d+)/)
    jobId = $1
    cols[0] = jobId
    cols[3] = jobNames[jobId]
  elsif(firstCol =~ /^Job/)
    tmp = cols.shift
    cols[0] = "#{tmp} #{cols[0]}"
    cols << "Nodes"
  else
    next
  end
  # update @niceSizes
  cols.each_index { |ii|
    colVal = cols[ii]
    @niceSizes[ii] = colVal.size if(colVal.size > @niceSizes[ii])
  }
  # save rec
  outputRecs << cols
}

unless(outputRecs.size <= 1)
  # Next, insert some nice --- lines
  dashes = @niceSizes.map { |ii| '-' * ii }
  outputRecs[1,0] = [dashes]
  # Finally output the qstatLines with the full names
  outputRecs.each { |cols|
    cols.each_index {|ii| cols[ii] = cols[ii].ljust(@niceSizes[ii]) }
    puts cols.join(" ").strip # the strip deals with ljust padding on last col
  }
else
  puts "\n[[ No jobs matched your pattern #{ARGV.first.inspect} ]]\n\n"
end
