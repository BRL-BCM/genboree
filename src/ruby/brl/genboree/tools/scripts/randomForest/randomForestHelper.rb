#!/usr/bin/env ruby 
require "matrix.rb"
require "fileutils"
class RandomForestHelper
 
  # # samplesFeatureValues - tab delimited data file containing 
  # # the header line: 1 feature name column, n sample name columns
  # # each subsequent line contains a feature name, and one value for each sample
  attr_reader :samplesfeatureValues, :samplesMetadata, :unfilteredmatrix, :feature, :scratchDir  

  #samplesFeatureValues is a string to show the path to input table. The first row of input table is header, the first column of input table are row names. There should be no columns or rows have string content other than the first row and first column. The input table should follow this format, if not, please modify your input table to this format.   
  # samplesMetadata is a hash of sample name and corresponding feature value. 
  # feature is a string to indicate the name of the meta data feature 
  # scratchDir the output dir in this case.
  # unfilteredmatrix is a ruby matrix generated based on the information in input table.

  def initialize(samplesFeatureValues, samplesMetadata, feature,scratchDir)
       @samplesfeatureValues=samplesFeatureValues
       @samplesMetadata=samplesMetadata
       alldata=[]
       matrixfile=File.open(samplesFeatureValues, "r")
       matrixfile.each_line{ |line|
         line.strip!         
         cols=line.split(/\t/)
         alldata << cols
       }
       matrixfile.close()
       matrixinput=Matrix.rows(alldata)
      @unfilteredmatrix=matrixinput
      @feature=feature
      @scratchDir=scratchDir
 end


    #This method will add the metadata feature to the input ruby matrix, then return the modified matrix. 

   def addmeta(inputmatrix)
       #puts "filtered: #{inputmatrix.row_size}"
       alldatatrans=[]
       for ii in 0...inputmatrix.row_size
            name=inputmatrix.[](ii,0)
            if ii==0
              name=name.gsub(/#OTU\ ID/, "sampleID")
              line="#{name}\t#{feature}"
            else 
              line="#{name}\t#{samplesMetadata[name]}"
            end 
          for jj in 1...inputmatrix.column_size
            ele=inputmatrix.[](ii,jj)
            line="#{line}\t#{ele}"
          end
            cols=line.split(/\t/)
            alldatatrans << cols 
       end
       transMatrix=Matrix.rows(alldatatrans)
       #puts transMatrix.row_size
       return transMatrix
   end 

 # This method will print out the input ruby matrix to the output file path.

  def printmatrixTofile(inputmatrix,outfilePath)
    outfile=File.open(outfilePath,"w")
    for ii in 0...inputmatrix.row_size 
      line=""
      for jj in 0...inputmatrix.column_size
        line="#{line}\t#{inputmatrix.[](ii,jj)}" 
      end
        outfile.puts line.strip!
    end
    outfile.close()
  end 



#This method will normalize the input matix based on values in each row. Round and  multiplier value is data specific (hard coded for now). The normalized matrix will be returned. 

  def normalization(inputmatrix,round,multiplier)
     output=[]
     output << inputmatrix.row(0)
     for ii in 1...inputmatrix.row_size 
        rowsum=0
        line="#{inputmatrix.[](ii,0)}\t#{inputmatrix.[](ii,1)}"
        for jj in 2...inputmatrix.column_size
            rowsum += inputmatrix.[](ii,jj).to_i
        end
        for jj in 2...inputmatrix.column_size
            if (rowsum !=0)
              normval=inputmatrix.[](ii,jj).to_i * multiplier.to_i / rowsum.to_f
              roundnorm=sprintf("%.#{round}f",normval)
             # roundnorm=inputmatrix.[](ii,jj).to_i/rowsum.to_f
            else
              roundnorm=0
            end
            line = "#{line}\t#{roundnorm}"
        end 
        cols=line.split(/\t/)
        output << cols
     end
     return normalMatrix=Matrix.rows(output)
  end 


  # My idea is that you could reuse the same object to apply different filters, then regenerate the results
  # Up to now we used two filters: by minimum percent, and by maximum row count
  # The side effect is that the filter gets recorded, and next time we try to run machine learning/feature selection it gets applied to the input data
  def filterFeatureValuesByMinPercent(minPercent)
    filteredmatrix=[]
    #puts "unfiltered: #{unfilteredmatrix.row_size}"
    filteredmatrix << unfilteredmatrix.row(0)
    sorthash={}
    for ii in 1...unfilteredmatrix.row_size
      rowsum=0
      for jj in 1...unfilteredmatrix.column_size
         rowsum+=unfilteredmatrix.[](ii,jj).to_i
      end
      sorthash[unfilteredmatrix.row(ii)]=rowsum
    end
    rownum=unfilteredmatrix.row_size.to_i
    rowcut=(rownum*minPercent/100).to_i
    count=0
    sorthash.sort{|k,v| v[1]<=>k[1]}.each { |val|
      if count<rowcut
         filteredmatrix << val[0]
         count += 1
      end
    }
    return Matrix.rows(filteredmatrix)
  end

  # My idea is that you could reuse the same object to apply different filters, then regenerate the results
  # Up to now we used two filters: by minimum percent, and by minimum value of maximum feature value
  # The side effect is that the filter gets recorded, and next time we try to run machine learning/feature selection it gets applied to the input data
  def filterFeatureValuesByMinFeatureValue(minValue)
    filteredmatrix=[]
    #puts "unfiltered: #{unfilteredmatrix.row_size}"
    filteredmatrix << unfilteredmatrix.row(0) 
    for ii in 1...unfilteredmatrix.row_size
      rowsum=0
      for jj in 1...unfilteredmatrix.column_size
         rowsum+=unfilteredmatrix.[](ii,jj).to_i 
      end
      if (rowsum >= minValue)
         filteredmatrix << unfilteredmatrix.row(ii)
      end      
    end
    return Matrix.rows(filteredmatrix)
  end

# This is the method to run RandomForest package in R. The normMatrixFile is the path to the normalized input table file with meta data added. The output from the R package are stored in several files(*_bag.txt, *_plot.pdf, *_importance.txt), *_sortedImportance.txt is a sorted table generated based on the  MeanDecreaseGini value in  *_importance.txt.

  def machineLearning(normMatrixFile,cutoff,feature)
      outStub="#{scratchDir}/RandomForest/"
      FileUtils.mkdir_p outStub
      oobFile = "#{outStub}#{feature}-#{cutoff}_bag.txt"
      plotFile = "#{outStub}#{feature}-#{cutoff}_plot.pdf"
      impFile = "#{outStub}#{feature}-#{cutoff}_importance.txt"
      impOutStub = "#{outStub}#{feature}-#{cutoff}_sortedImportance.txt"

      rFile = "#{outStub}RFjob.r"     
      w = File.open(rFile, "w")
      w.puts "library(randomForest)"
      w.puts "library(\"Hmisc\")"
      w.puts "setwd(\"#{outStub}\")"
      w.puts "set.seed(44)"
      w.puts "tempdat <- read.table(\"#{normMatrixFile}\", row.names=1, header=TRUE, sep=\"\\t\",na.strings= \"NA\")"
      w.puts "DF = data.frame(tempdat)"
      w.puts "DF.rf <- randomForest(#{feature} ~ ., data=DF, importance=TRUE, proximity=TRUE)"
      w.puts "capture.output(print(DF.rf,width=5000), file=\"#{oobFile}\")"
      #w.puts "write(DF.rf, file=\"#{oobFile}\", sep = \"\t\")"
      w.puts "pdf(file=\"#{plotFile}\", height=4, width=4)"
      w.puts "plot(DF.rf)"
      w.puts "dev.off()"
      #w.puts "capture.output(print(round(DF.rf$importance, 2),width=5000), file=\"#{impFile}\")"
      w.puts "write.table(round(DF.rf$importance, 2), file=\"#{impFile}\", sep = \"\t\",  quote = FALSE)"
      w.close()
     `R --vanilla < #{rFile}`   
    #sort the importance table based on MeanDecreaseGini  
      sortHash={}
      r=File.open(impFile,"r")
      w=File.open(impOutStub,"w")
      templine= r.gets
      if templine =~ /MeanDecreaseGini/
         flag=1
      else
         flag=0
      end
      w.puts templine    
      r.each_line{ |line|
        if flag == 1
          line.strip!
          cols=line.split(/\s/)
          value=cols.pop
          key=cols.join("\t")
          sortHash[key]=value
        elsif line =~ /MeanDecreaseGini/
           flag =1
        end 
      }
      r.close() 
      sortHash.sort{|k,v| v[1]<=>k[1]}.each { |val|
        w.puts "#{val[0]}#{val[1]}"
     }
     w.close()
  end


# This is the method to run Boruta package in R. The normMatrixFile is the path to the normalized input table file with meta data added. The output from the R package are stored in several files(*_stats.txt, *_conFix.txt), *_confirmed.txt is based on the result indicated in *_stats.txt file , only records  confirmed by Boruta are printed in the file. 


  # This method would output the resulting features
  def borutaFeatureSelection(normMatrixFile,cutoff)
     outStub="#{scratchDir}/Boruta"
     FileUtils.mkdir_p outStub
     statsFile = "#{outStub}/Boruta_#{cutoff}_stats.txt"
     confirmedPlusFixFile = "#{outStub}/Boruta_#{cutoff}_conFix.txt"
     formattedConfirmedFile = "#{outStub}/Boruta_#{cutoff}_confirmed.txt"
     
     rFile="#{outStub}Borutajob.r"
     w = File.open(rFile, "w")
     w.puts "library(\"Boruta\")"
     w.puts "library(\"mlbench\")"
     w.puts "setwd(\"#{outStub}\")"
     w.puts "set.seed(44)"
     w.puts "tempdat <- read.table(\"#{normMatrixFile}\", row.names=1, header=TRUE, sep=\"\\t\", na.strings= \"NA\")"
     w.puts "DF = data.frame(tempdat)"
     w.puts "Boruta <- Boruta(#{feature} ~ ., data=DF, doTrace = 2, ntree = 500, maxRuns=300)"
     w.puts "capture.output(print(TentativeRoughFix(Boruta)), file=\"#{confirmedPlusFixFile}\")"
     w.puts "capture.output(print(attStats(Boruta)), file=\"#{statsFile}\")"
     w.close()
     `R --vanilla < #{rFile}`

     confirmedarray=[]
     r=File.open(confirmedPlusFixFile, "r")
     r.gets
     r.each_line{|line|
       break if line =~ /unimportant/
       if line =~ /important/ and line !~ /No attributes has been deemed important/
          spl=line.split(":\ ")[1].split(" ")
          spl.each{|val|
                confirmedarray << val.gsub(/X/,"")
          }
       end
       
       if (line =~ /^X/)
            spl=line.split(" ")
            spl.each{|val|
                confirmedarray << val.gsub(/X/,"")
          }   
       end 
     }
     r.close()
    #output those OTUs confirmed by Boruta
    r=File.open(samplesfeatureValues, "r")
    w=File.open(formattedConfirmedFile, "w")
    w.puts r.gets
    r.each_line{ |line|
      line.strip!
      cols=line.split(/\t/)
      name=cols[0].gsub(/-/,".")
      if confirmedarray.include?(name)
        w.puts line
      end
    }
    w.close()
    r.close()
     
  end

end

