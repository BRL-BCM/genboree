#!/usr/bin/env ruby
require 'spreadsheet'
 
outDir=ARGV[0]
outfile="#{outDir}/sequences_metrics_summary.xls"

metadata=[]
for i in 1..10
  unless ARGV[i].nil?
    metadata << ARGV[i]
  end
end

# create a new book and sheet
book = Spreadsheet::Workbook.new
samplesheet = book.create_worksheet :name => 'sampleSheet'
allsheet =book.create_worksheet :name => 'allSheet'


statfiles=`find #{outDir} -name "*stat" -print`.to_a

stathash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

# save stat in to hash 
statfiles.each{|statfilepath|
   statfilepath.strip!
   sampleName=statfilepath.gsub(/_stat/,"")
   statfile=File.open(statfilepath,"r")
   statfile.each{|line|
      cols=line.split(":")
      stathash[sampleName][cols[0]]=cols[1].strip!
   }
   statfile.close()
}


metahash=Hash.new{|h,k| h[k]=Hash.new(&h.default_proc)}

#write into all sample sheet
allsheet.row(0).push 'sampleName','Average_read_length','total_sequence_counts_in_all_sffFile','total_sequence_counts_match_barcode_proximal_primer','total_sequence_counts_after_quality_filter','sequence_length_shorter_than_min_after_trimming','sequence_qual_lower_than_min','sequence_hasN_filtered',"total_number_of_bases"

allsheethash={}
allsheethash[2]=0
allsheethash[3]=0
allsheethash[4]=0
allsheethash[5]=0
allsheethash[6]=0
allsheethash[7]=0
allsheethash[8]=0
sffarray=[]
stathash.each{|sampleName,samplehash|
   countafter=0
   countbefore=0
   lengthtrim=0
   qualtrim=0
   ntrim=0
   nuccount=0
   sfffile=""
   samplehash.each{|k,v|
         sfffile=samplehash["fileLocation"]
         unless sffarray.include?(sfffile)
            sffarray << sfffile
            allsheethash[2]+=samplehash["total_sequence_counts_in_sffFile"].to_i
         end
         countafter=samplehash["total_sequence_counts_after_filter"].to_i
         countbefore=samplehash["total_sequnece_counts_before_filter"].to_i
#         col4+=samplehash["sequence_not_match_proximal_primer"].to_i
         lengthtrim=samplehash["sequence_length_shorter_than_min_after_trimming"].to_i
         qualtrim=samplehash["sequence_qual_lower_than_min"].to_i
         ntrim=samplehash["sequnece_hasN_filtered"].to_i
         nuccount=samplehash["Averge_read_length"].to_i*samplehash["total_sequence_counts_after_filter"].to_i    
   }
   allsheethash[4]+=countafter
   allsheethash[3]+=countbefore
   allsheethash[5]+=lengthtrim
   allsheethash[6]+=qualtrim
   allsheethash[7]+=ntrim
   allsheethash[8]+=nuccount
}
if allsheethash[4] != 0
  allsheethash[1]=allsheethash[8]/allsheethash[4]
else 
  allsheethash[1]=0
end
allsheet[1,0]="allsample"
for ii in 1..8
   allsheet[1,ii]=allsheethash[ii]
end


#write data into sample sheet and record each metadata 
samplesheet.row(0).push 'sampleName','Average_read_length','total_sequence_counts_in_sffFile','total_sequence_counts_match_barcode_proximal_primer','total_sequence_counts_after_quality_filter','sequence_not_match_proximal_primer','sequence_length_shorter_than_min_after_trimming','sequence_qual_lower_than_min','sequence_hasN_filtered',"minseqLength","minAveQual","minSeqCount"

poshash={}
poshash["sampleName"]=0
poshash["Averge_read_length"]=1
poshash["total_sequence_counts_in_sffFile"]=2
poshash["total_sequnece_counts_before_filter"]=3
poshash["total_sequence_counts_after_filter"]=4
poshash["sequence_not_match_proximal_primer"]=5
poshash["sequence_length_shorter_than_min_after_trimming"]=6
poshash["sequence_qual_lower_than_min"]=7
poshash["sequnece_hasN_filtered"]=8
poshash["minseqLength"]=9
poshash["minAveQual"]=10
poshash["minSeqCount"]=11

count=12
metadata.each{|meta|
  poshash[meta]=count
  count+=1
  samplesheet.row(0).push meta
}


row=1
stathash.each{|sampleName,samplehash|
   samplehash.each{|k,v|
     col=poshash[k]
     unless col.nil?
       if col==1||col==2||col==3||col==4||col==5||col==6||col==7||col==8||col==9||col==10||col==11
         samplesheet[row,col]=v.to_i
       else
         samplesheet[row,col]=v
       end
       if metadata.include?(k)
           if metahash.has_key?(k)
              if metahash[k].has_key?(v)
                 samplearray=metahash[k][v]
                 samplearray << sampleName
                 metahash[k][v]=samplearray
              else
                 samplearray=[]
                 samplearray << sampleName
                 metahash[k][v] =samplearray 
              end
           else 
              samplearray=[]
              samplearray << sampleName
              metahash[k][v] = samplearray
           end 
       end
     end
   }
   row+=1
}


#write data into metadata summary sheet
metasheethash={}

metadata.each{|meta|    
   metasheet =book.create_worksheet :name => "#{meta}Sheet"
   metasheet.row(0).push 'metalabel','Average_read_length','total_sequence_counts_match_barcode_proximal_primer','total_sequence_counts_after_quality_filter','sequence_length_shorter_than_min_after_trimming','sequence_qual_lower_than_min','sequence_hasN_filtered',"total_number_of_bases"
   metanamehash=metahash[meta]
   rowcount=1
   metanamehash.each{|metaname,samplearray|
     metasheet[rowcount,0]=metaname
     metasheethash[2]=0
     metasheethash[3]=0
     metasheethash[4]=0
     metasheethash[5]=0
     metasheethash[6]=0
     metasheethash[7]=0
     samplearray.each{|samplename|
         metasheethash[3]+=stathash[samplename]["total_sequence_counts_after_filter"].to_i
         metasheethash[2]+=stathash[samplename]["total_sequnece_counts_before_filter"].to_i
         metasheethash[4]+=stathash[samplename]["sequence_length_shorter_than_min_after_trimming"].to_i
         metasheethash[5]+=stathash[samplename]["sequence_qual_lower_than_min"].to_i
         metasheethash[6]+=stathash[samplename]["sequnece_hasN_filtered"].to_i
         metasheethash[7]+=stathash[samplename]["Averge_read_length"].to_i*stathash[samplename]["total_sequence_counts_after_filter"].to_i
     }
     if metasheethash[3]!= 0
       metasheethash[1]=metasheethash[7]/metasheethash[3]
     else 
       metasheethash[1]=0
     end 
     for ii in 1..7
       metasheet[rowcount,ii]=metasheethash[ii]
     end 
     rowcount+=1
   }
}


# save file
book.write "#{outfile}"

