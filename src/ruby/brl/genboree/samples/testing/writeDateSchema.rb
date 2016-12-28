#!/usr/bin/env ruby

num = ARGV[0].to_i
length = ARGV[1].to_i

puts "ASSAY NAME:\tOMGWTFBBQ"

print "RECORD FIELDS\t"
1.upto(num){ |i|
  print "f#{i}\t"
}
print "\n"

print "FIELD TYPES:\t"
1.upto(num){ |i|
  print "date\t"
}
print "\n"

puts "ASSAY ATTRIBUTES:\tatt1=asdf; att2=asdf2;"
puts "ANNO LINK ATTRIBUTE:    attAnnoLinkHere"
puts "ANNO LINK TRACK:\ttrack:name"
puts "1\tlink1"
puts "2\tlink2"
puts "3\tlink3"


$stderr.puts "ASSAY NAME:\tOMGWTFBBQ"
$stderr.puts "ASSAY RUN NAME:\tRUNNAME2"
$stderr.puts "DATA:"

1.upto(length){ |i|
	$stderr.print "Sample1\t"
	1.upto(num){ |i|
	  $stderr.print "Jan 5, 2006\t"
	}
	$stderr.print "\n"
}
