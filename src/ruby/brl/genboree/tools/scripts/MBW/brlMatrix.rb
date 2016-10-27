#!/usr/bin ruby
  
require "matrix.rb"
#require "mathn"

class MatrixWork  
  DEBUG=false
 
#  def setARGS()
#    @inputFile = fep(ARGV[0])
#    @outputFile = fep(ARGV[1]) if ARGV[1] != nil
#  end

  def initialize(inputFile, outputFile)
    @inputFile = fep(inputFile)
    @outputFile = fep(outputFile)
  end
  
  #shortened version to get full file path
  def fep(file)
    return File.expand_path(file)
  end

  #borrowed from
  #http://rosettacode.org/wiki/Determine_if_a_string_is_numeric#Ruby
  def isNumeric(s)
    Float(s) != nil rescue false
  end

  #input: file
  #function returns a matrix from file input
  def file2matrix (addRow)
    file = @inputFile
    r = File.open(file, "r") 

    @otuFormatFlag = 0
  
    #in order to properly transpose, etc. matrices we have to make sure
    # that if there is not an entry in the "0,0" location of the file
    # that we add a place holder (ex. "___"), otherwise the matrix will
    # be shifted to the left one position in the first row
    firstLine = r.gets
    #if we have OTU table format we need to remove the first line
    # and we can replace later if appropriate for output
    if firstLine =~ /\#Full/ || firstLine =~ /trueMark/
      firstLine = r.gets
      @otuFormatFlag = 1
    end
  
    secondLine = r.gets
    
    firstLen = firstLine.split.size
    secondLen = secondLine.split.size
  
    r.close()
    r = File.open(file, "r")
  
    allFileContents = ""
    lineCount = 0
    #if we find out that first line needs a placeholder 
    if firstLen < secondLen
      tmpLine = r.gets.strip
      allFileContents = "___\t#{tmpLine}\n" 
    end
  

    pos = 0
    r.each{ |line|
      line.strip!
      next if line =~ /\#Full/
      #cannot have spaces in header line
      if pos == 0
        line = line.gsub(/OTU\ ID/, "OTUID")
        line = line.gsub(/Consensus Lineage/, "ConsensusLineage")
        #add optional row which can be meta data
        #allFileContents += addRow if addRow != nil
      end
      line = line.gsub(/\ /, "_")
      allFileContents += "#{line}\n"
      allFileContents += addRow if addRow != nil && pos == 0
      pos += 1     
    }  
    r.close()
    
    returnMatrix = Matrix.rows(allFileContents.lines.map{ |l| l.split })
    #returnMatrix = Matrix.rows(allFileContents.lines.map{ |l| l.chomp.chomp.chomp.split("\t")})
    #allFileContents.lines.map{ |l| puts l.chomp.split("\t")}
    #exit
  
    return returnMatrix
  end



=begin
  def guessHeaders(matrix)
    rSize = matrix.row_size
    cSize = matrix.column_size


    0.upto(rSize-1) do |rVal|
      0.upto(cSize-1) do |cVal|

  
      end
    end
  end
=end
  
  def printMatrix (matrix, file)
    #if file is empty then print to screen
    #  otherwise print to file
    w = File.open(file, "w") if file != nil
    rSize = matrix.row_size
    cSize = matrix.column_size
     
    0.upto(rSize-1) do |rVal|
      next if matrix[rVal,0] =~ /Lineage/
      0.upto(cSize-1) do |cVal|
        if file != nil
          if cVal == 0
            w.print "#{matrix[rVal,cVal]}"
          else
            w.print "\t#{matrix[rVal,cVal]}"
          end
        else
          if cVal == 0
            print "#{matrix[rVal,cVal]}"
          else
            print "\t#{matrix[rVal,cVal]}"
          end
        end
      end
      if file != nil
        w.puts
      else
        puts
      end
    end
  
    w.close() if file != nil
  end

  #todo
  def usage()
    prints "need to write up usage when script is further developed"
  end

  def getColSums(matrix)
    rSize = matrix.row_size
    cSize = matrix.column_size

    startCol = 0
    startRow = 0

    if !isNumeric(matrix[0,0])
      startCol = 1
      startRow = 1
    end

    returnArr = []

    startCol.upto(cSize-1) do |cVal|
      tempSum = 0
      startRow.upto(rSize-1) do |rVal|
        tempSum += matrix[rVal, cVal].to_i
        #print "#{cVal}:#{rVal}:"
        #puts matrix[rVal,cVal].to_i
      end
      returnArr.push(tempSum)
    end

    return returnArr
  end

  #function takes in a matrix, (optional) file, amount of decimal points
  #  to round by, and a multiplier
  def normalize(matrix, file, round, mult, binary)
    w = File.open(file, "w") if file != nil
    rSize = matrix.row_size
    cSize = matrix.column_size

    #array to hold column sums
    sumArr = getColSums(matrix)
    
    #if matrix[0,0] is numeric it is likely that we do not have headers
    #  becasue most matrices are either header-less or have a blank entry
    #  in the 0,0 location in which we've already made a "___"

    startCol = 0
    startRow = 0

    #set header flag based on presence of headers
    headerFlag = 0
    headerFlag = 1 if !isNumeric(matrix[0,0])

    lineageFlag = 0

    if headerFlag == 1 
      startCol = 1
      startRow = 1
     
      #print matrix position 0,0
      if file != nil
        w.print matrix[0,0].gsub(/\#/, "")
      else
        print matrix[0,0].gsub(/\#/, "")
      end

      #print column headers
      1.upto(cSize) do |rVal|
        if file != nil
          w.print "\t#{matrix[0, rVal]}" if matrix[0, rVal] != nil
        else
          print "\t#{matrix[0, rVal]}" if matrix[0, rVal] != nil
        end
      end
      if file!= nil
        w.puts
      else
        puts
      end
    end

    returnArr = []
    pos = 0    

    startRow.upto(rSize-1) do |rVal|
      tempSum = 0
      internalLoopCount = 0
 
=begin      
      stopPosition = 1
      if matrix[rVal, 0] =~ /Lineage/
        lineageFlag = 1
        stopPosition = 1
      end
=end

      next if matrix[rVal, 0] =~ /Lineage/      

      #print out row label if applicable
      if headerFlag == 1
        if file != nil
          w.print matrix[rVal, 0]
        else
          print matrix[rVal, 0]
        end
      end

      startCol.upto(cSize-1) do |cVal|
        #puts val = matrix[rVal, cVal]
        val = matrix[rVal, cVal]
        if isNumeric(val) && val != "0"
          calculatedColSum = sumArr[internalLoopCount].to_i
          normVal = val.to_i
          normVal = matrix[rVal, cVal].to_i/calculatedColSum.to_f * mult if binary == nil
          if internalLoopCount == 0 && headerFlag == 0
            if file != nil
        
              w.printf("%\.#{round}f", normVal)
            else
              printf("%\.#{round}f", normVal)
            end
          else
            if file != nil
              w.printf("\t%\.#{round}f", normVal)
            else
              printf("\t%\.#{round}f", normVal)
            end
          end
          #internalLoopCount += 1
        else
          if file != nil
            w.print "\t#{val}"
          else  
            print "\t#{val}"
          end
          #internalLoopCount += 1
        end
        internalLoopCount += 1
      end
     
      
      if file != nil
        w.puts
      else
        puts 
      end
      pos += 1
    end
 
    w.close() if file != nil
  end

  def taxHash(matrix)
    h = Hash.new(0)
    rSize = matrix.row_size
    cSize = matrix.column_size
    1.upto(rSize-1) do |rVal|
      #puts "#{matrix[rVal, 0]}:"
      #puts "#{matrix[rVal, cSize-1]}:"
      h[matrix[rVal, 0]] = matrix[rVal, cSize-1]
    end

    return h
  end

  def addMetaCol2(matrix, title, mapFile)
    startCol = 1
    startRow = 1

    rSize = matrix.row_size
    cSize = matrix.column_size

    elems = []
    elems.push(title)
    
    #loop through rows, get sample name, store into array
    startRow.upto(rSize-1) do |rVal|
      tempSum = 0
      internalLoopCount = 0
      elems.push(matrix[rVal, 0])
    end

    r = File.open(mapFile, "r")
   
    colTitles = r.gets.split("\t")
    puts pos = colTitles.index(title)
    #pos = getColPos(title, arr)

    #hsh

    #puts elems
  end

  def getColPos(title, arr)
    hsh = Hash.new(0)
    

  end

  def addMetaCol(matrix, metaCMDfile, currentMapFile, rerunsFile)
    arrsHolder = []
    metaCallNames = []
    metaANDarrsHolder = [] 

    File.open(metaCMDfile, "r").each{ |line|
      returnArr = []
      #puts line
      next if line =~ /\#/
      tmpArr = []
      puts spl = line.split("\t")

      exe = spl[0]
      puts len = spl.length
      cmd = ""
      returnArr.push(spl[3].strip)
      if len == 4
        cmd = "ruby #{exe} #{spl[1]} #{rerunsFile} #{currentMapFile} #{spl[2]}"
        cmd = "ruby #{exe} #{spl[1]} #{rerunsFile} #{currentMapFile} #{spl[2]} #{spl[3]}" if exe =~ /getColMetaDataGEN/
        metaCallNames.push(spl[3].strip)
        puts cmd
        tmpArr = `#{cmd}`.split("\n")
        #puts tmpArr.length
      elsif len == 5
        cmd = "ruby #{exe} #{spl[1]} #{rerunsFile} #{currentMapFile} #{spl[2]} #{spl[4]}"
        metaCallNames.push(spl[3].strip)
        puts cmd
        #metaCallNames.push(spl[4].strip)
        #cmd = cmd.gsub(/\"/, '\'')
        #tmpArr = `#{cmd}`.to_a
        tmpArr = `#{cmd}`.split("\n")
        #puts tmpArr.length
      end
      tmpArr.each{ |val|
        val.gsub!(/\</, "l")
        val.gsub!(/\>/, "g")
        val.gsub!(/\./, "p")
        val.gsub!(/\=/, "e")
        val.gsub!(/NA/, "notapp")
       
        #special cases for combining adult and child data 
        # if we are looking at affection we want healthy adults to be an H
        if spl[2] =~ /Affection/
          val.gsub!(/0/,"H")
        #makeshift fix for adult vs. child meta data column
        elsif spl[2] =~ /Treatment/
          valI = val.to_i
          if valI == 0
            val.gsub!(/0/, "Adult")
          else
            val.gsub!(/[0-9]+/, "Child")
          end
        #elsif spl[2] =~ /IBS[C][D][U]/
        elsif spl[2] =~ /IBS[CDU]/
          val.gsub!(/0/, "No")
          val.gsub!(/1/, "Yes")
        end


      }
      arrsHolder << tmpArr
    }
    #puts "arr 0"
    #puts arrsHolder[0] 
    
    metaANDarrsHolder << metaCallNames
    metaANDarrsHolder << arrsHolder
    return metaANDarrsHolder    
  end

  def outOfBagOLD(file)
    File.open(file, "r").each{ |line|
      if line =~ /error\ rate/
        #puts err = line.split(": ")[1].split("%")[0]
        puts line.strip
      end
    } 
  end

  def outOfBag(file)
    err = 0
    File.open(file, "r").each{ |line|
      if line =~ /error\ rate/
        err = line.split(": ")[1].split("%")[0].to_f
        #puts line.strip
      end
    }
    return err
  end

  #sort importance file based on column (1, 2, 3 or 4)
  # provide taxonomic lookup hash for tax printing
  # print up to 'numberToPrint' entries
  def sortImportance(file, col, tax, numberToPrint, outFile, fileType)
    numberToPrint = 9999999 if numberToPrint == nil

    w = File.open(outFile, "w")

    r = File.open(file, "r")
    header = r.gets
    w.puts "\t#{header}"
    headerArr = header.split
    #linesArr = []
    lastElem = ""

    #if we have meandecreasegini index half way down into file
    if fileType == 2
      r.each{ |line|
        break if line =~ /MeanDecreaseGini/
      }
    end

    sortHash = Hash.new(0)
    lineHash = Hash.new(0)
    #store each line minus headers into array
    arrLines = []
    r.each{ |line|
      #linesArr.push(line.strip)
      spl = line.split
      sortHash[spl[0].gsub(/X/, "")] = spl[col].to_f
      lineHash[spl[0].gsub(/X/, "")] = line.strip
      lastElem = spl[0].gsub(/X/, "")
    }
    r.close()

    count = 0
    #exit(1) if sortHash == nil
 
    #if we only have 1's and 0's it's going to only have 2 columns
    # for output because it thinks its censor data
    #puts sortHash[lastElem]
    #puts sortHash
    if sortHash[lastElem] != nil
      sortHash.sort{|k,v| v[1]<=>k[1]}.each { |val|
        #puts "#{val[1]}:#{val[0]}"
        #puts "#{val[0]}:#{tax[val[0]]}"
        #puts "#{lineHash[val[0]]}\t#{tax[val[0]]}"
        if tax != nil
          w.puts "#{tax[val[0]]}\t#{lineHash[val[0]]}"
        else
          w.puts "#{lineHash[val[0]]}"
        end

        count += 1
        break if count == numberToPrint
      }
    end
    w.close()
  end

  def filter(inFile, outFile, cutoff)
    w = File.open(outFile, "w")
    r = File.open(inFile, "r")
 
    len = 0

    header = r.gets
    #if we have an OTU table we need to re-print first line and then
    # the column header
    if header =~ /#Full\ OTU\ Counts/
      w.puts header
      header = r.gets
      w.puts header
      len = header.split("\t").size
    #else if we have a prepared matrix we need to take care of first
    # two lines, the second being the feature
    else
      w.puts header
      len = header.split("\t").size
      w.puts r.gets
    #else
    #  w.puts header  
    #  len = header.split("\t").size
    end

    #if arbitrary cutoff is not sent in as a parameter, set it to
    # number of elements / 3 
    cutoff = len / 3 if cutoff == nil

    count = -1
    numElements = 0
    r.each{ |line|
      count += 1
      #next if count == 0
      spl = line.split("\t")
      #delete the first and last elements if we have an OTU table
      #  will have to revisit this down the road for non-OTU tables 
      spl.delete_at(0)
      spl.delete_at(len-2)

      sum = 0
      spl.each{ |val|
        sum += val.to_i
      }
      
      if sum >= cutoff
        w.puts line
        numElements += 1
      end
    }

    r.close()
    w.close()
  end

  def work()
    #puts @inputFile
    #puts @outputFile

    #x = file2matrix(@inputFile)
    x = file2matrix()
    printMatrix(x, nil)

    taxLookup = taxHash(x)
    #puts taxLookup["1"]

    #exit
    #we need to determine the best way to figure out if we have headers
    # for the row and column names and the only 
 
    #transpose matrix
    transX = x.t
    #print transposed matrix to screen
    #printMatrix(transX, nil)
    #puts 
    #exit
    #print transposed matrix to file
    #printMatrix(transX, @outputFile)
    #puts
    #print normalized matrix to screen
    #normalize(transX, nil)
    #puts
    #print normalized matrix to file
    #normalize(transX, @outputFile)
 
    

  end

end  

########################################################
# MAIN
########################################################
  
#mtx = MatrixWork.new(*ARGV)
#mtx.work()

#exit(0);
