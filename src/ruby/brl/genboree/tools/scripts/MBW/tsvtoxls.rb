#!/usr/bin/env ruby

require 'spreadsheet'

indir=ARGV[0]
feature=ARGV[1]

tsvfiles=`find #{indir} -name "*gini_trends_3sorted"`.to_a
xlsfile="#{indir}/#{feature}_gini_trends_3sorted.xls"

unless tsvfiles.empty?
  book = Spreadsheet::Workbook.new
  tsvfiles.each{|tsvfile|
     tsvfile.strip!
     filename=File.basename(tsvfile)
     sheet = book.create_worksheet :name => "#{filename}"
     readtsvfile=File.open(tsvfile,"r")
     rowcount=0
     readtsvfile.each{|line|
       line.strip!
       cols=line.split("\t")
       cols.each{|col|
         sheet.row(rowcount).push "#{col}"
       }
       rowcount+=1
     }
  }
  book.write "#{xlsfile}"
end
