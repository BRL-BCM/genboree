#!/usr/bin/env ruby
require 'spreadsheet'

cutoffs=[]
outDir=ARGV[0]

for i in 1..10
   unless ARGV[i].nil?
     cutoffs << ARGV[i]
   end
end

summaryfile="#{outDir}/RF_summary.xls"
book = Spreadsheet::Workbook.new
sheet = book.create_worksheet :name => 'sheet'

errhash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

cutoffs.each{|cutoff|
  bagfiles=`find #{outDir} -name "*-#{cutoff}_bag.txt"`.to_a
  bagfiles.each{|bagfile|
    bagfile.strip!
    filename=File.basename(bagfile)
    meta=filename.gsub(/-#{cutoff}_bag.txt/,"")
    File.open(bagfile,"r").each_line{|line|
       if line=~/error\ rate/
         err = line.split(": ")[1].split("%")[0].to_f
         errhash[meta][cutoff]=err
       end
    }
  }
}

sheet.row(0).push "	"
cutoffs.each{|cut|
  sheet.row(0).push "#{cut}"
}

rowcount=1
errhash.each{|legend,valuehash|
   sheet.row(rowcount).push "#{legend}"
   cutoffs.each{|cut|
     sheet.row(rowcount).push "#{valuehash[cut].to_s}"
   }
   rowcount+=1
}
book.write "#{summaryfile}"
