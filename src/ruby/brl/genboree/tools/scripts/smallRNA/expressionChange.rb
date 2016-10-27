#!/usr/bin/env ruby
#Script for transposing a gene expression and filter it by a set og genes

require 'rubygems'
require 'brl/util/textFileUtil'
require 'brl/util/util'
require 'stringio'
require 'zlib'


class ExpChange
  
  def initialize(optsHash)
    @file1      = optsHash['--file1']
    @file2      = optsHash['--file2']
    if( optsHash['--outputFile'])
      @outputFile = optsHash['--outputFile']
    else
      @outputFile = "output.txt"
    end
    @compressed = optsHash['--doGzipOutput']
    
  end
  
  ## Reading two files and making a matrix from the expression data file
  ## It makes the hash table for the genes from the gene file for quick search
  ## Then it filters those genes which are not present in the hash and remove the
  ## whole expression data related to that particular gene
  def fileRead()
        # 2-D array for epression data
        expArray =[]
        inputFileHandle1 = BRL::Util::TextReader.new(@file1)        
        inputFileHandle2 = BRL::Util::TextReader.new(@file2)
        outputFileHandle = File.open(@outputFile, "w+")
        
        ## Counter for making array                             
        ii = 0
        inputFileHandle1.each_line { | line|
            line = line.split(/\s/)
            expArray[ii] = line
            ii += 1
        }
         

        ## hash for genes from the gene file
        geneHash = {}
        inputFileHandle2.each_line { |line2|
          line2 = line2.strip!
          geneHash[line2] = 0
          }
      
        
        hh = 1
        tempArray = []
        ## Filtering the columns of 2-D matrix
        tempArray[0] = expArray[0]
        for ele in (1... expArray.size)
            if(geneHash.key?(expArray[ele][0]))
              tempArray[hh] = expArray[ele]
              #puts expArray[ele][]
              hh  += 1
            end
          end
          
        
        ## Transposing the matrix
        expArrayTrans =[] 
        expArrayTrans = tempArray.transpose
        trackHashone = {}
        trackHashMone = {}
        
        ## Making changes in the matrix. Removing entries where the value is 0
        outputFileHandle.print "Sample\tGene Name\tNumber of Genes\n"
        for col in (1 ...expArrayTrans.size)
          outputFileHandle.print expArrayTrans[col][0] +"\t"
          countGene = 0
          checkComa = 0
          for num in (1 ... expArrayTrans[col].size)
            if( expArrayTrans[col][num].to_i != 0)
              if (checkComa == 1 )
                outputFileHandle.print ", "
              end
              
              ## Making hash of genes expression
              ## Over expressed genes
              if(expArrayTrans[col][num].to_i == 1)
                if(trackHashone.key?(expArrayTrans[0][num]))
                  tempVa = 0
                  tempVa = trackHashone[expArrayTrans[0][num]]
                  trackHashone[expArrayTrans[0][num]] = tempVa.to_i + 1
                else
                   trackHashone[expArrayTrans[0][num]] = 1
                end
              end
              ## Undee expressed genes
              if(expArrayTrans[col][num].to_i == -1)
                if(trackHashMone.key?(expArrayTrans[0][num]))
                  tempVa = 0
                  tempVa = trackHashMone[expArrayTrans[0][num]].to_i + 1
                  trackHashMone[expArrayTrans[0][num]] = tempVa 
                else
                  trackHashMone[expArrayTrans[0][num]] = 1
                end
              end
              
              outputFileHandle.print expArrayTrans[0][num]
              checkComa =1
              countGene += 1
            end
          end
          outputFileHandle.print  " \t#{countGene}\n"
        end
        
        outputFileHandle.print "\n\n\n"
        
        outputFileHandle.print " UnderExpressed Genes\n"
        trackHashMone.each { |k,v|
          outputFileHandle.print "#{k}\t#{v}\n"
        }
        outputFileHandle.print "\n\n\n"
        outputFileHandle.print " OverExpressed Genes\n"
        trackHashone.each { |k,v|
          outputFileHandle.print "#{k}\t#{v}\n"
        }
        
        ## If compressed output is required
        if(@compressed.eql?('T'))
		system("gzip #{@outputFile}")	
        end
        
        inputFileHandle1.close
        inputFileHandle2.close
        outputFileHandle.close
  end
  
  
  # Process Arguements form the command line input
  def ExpChange.processArguements()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--file1'  ,   '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--file2'    , '-F', GetoptLong::REQUIRED_ARGUMENT],
                    ['--outputFile','-o', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--doGzipOutput','-z',GetoptLong::OPTIONAL_ARGUMENT],
                    ['--help'     , '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      ExpChange.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
    
      ExpChange if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
  end
  
  
  # Display usage info and quit.
  def ExpChange.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    Transposes a gene expression matrix and filter it by a set of genes
   
  COMMAND LINE ARGUMENTS:
    --file1        | -f => Expression file name. It also accepts zipped files
    --file2        | -F => Gene list file name.
    --outputFile   | -o => [Optional] outputFile name. By default, its 'output.txt'
    --doGzipOutput | -z => [Optional] Compressed form of output
    --help         | -h => [Optional flag]. Print help info and exit.

 usage:
 
 expressionChange.rb -f file1.txt -F file2.txt


  ";
      exit;
  end # 
end

 # Process command line options
 optsHash = ExpChange.processArguements()
 exp = ExpChange.new(optsHash)
  exp.fileRead()    
  
