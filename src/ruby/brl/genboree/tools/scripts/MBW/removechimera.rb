#!/usr/bin/env ruby

otutable=ARGV[0]
chimeralist=ARGV[1]
chimeraarray=[]
File.open(chimeralist,"r").each_line{|line|
   line.strip!
   cols=line.split("\t")
   otunum=cols[1]
   if(cols[10]=~/YES/)
     chimeraarray << otunum
   end
}
outpath=File.dirname(otutable)
filterotutable="#{outpath}/otu_table.txt"
chimeraotu="#{outpath}/otu_table_chimeraotu.txt"
filteredotutable=File.open(filterotutable,"w")
chimeraotuout=File.open(chimeraotu,"w")
otupath=File.open(otutable,"r")


title=otupath.gets
header=otupath.gets
filteredotutable.puts title
filteredotutable.puts header
chimeraotuout.puts header
otupath.each_line{|line|
   line.strip!
   cols=line.split("\t")
   otunum=cols[0]
   if chimeraarray.include?(otunum)
     chimeraotuout.puts line
   else
     filteredotutable.puts line
   end
}
filteredotutable.close()
chimeraotuout.close()

