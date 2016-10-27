#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'
require 'brl/genboree/helpers/expander'

include GSL
include BRL::Genboree::REST


class SignalSimilarity

   def initialize(optsHash)
        @inputFile      = optsHash['--file']
        @scratch        = optsHash['--scratch']
        @outputDir      = optsHash['--output']
        @format         = optsHash['--format']
        @filter         = optsHash['--filter']
        @resolution     = optsHash['--resolution']
        @runName        = CGI.escape(optsHash['--analysis'])
        @quantileNormalized = optsHash['--quantileNormalized']
        @inputFileArray = @inputFile.split(',')
   end
   
    
   ## Reading files and making vectors
  def readFiles()
    begin
      Dir.chdir(@scratch)
      @outputDir = "#{@scratch}/signal-search/#{@runName}"
      system("mkdir -p #{@outputDir}")
      @filewrite = File.open("#{@outputDir}/summary.txt","w+")
      @filewrite.puts "Track\tCorrelation\tSum of Sqaure of Residual\tIntercept\tSlope\tChiSqaure\tRMSEA\tF-Value"
      @inputFileArray[0] = CGI.escape(@inputFileArray[0])
      $stdout.puts @inputFileArray[0]
      
      ##Checks if files are compressed and then uncompressed
      expanderObj = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/#{@inputFileArray[0]}")
      if(compressed = expanderObj.isCompressed?("#{@outputDir}/#{@inputFileArray[0]}"))
         expanderObj.extract('text')
         fullPathToUncompFile = expanderObj.uncompressedFileName
         system("rm #{@outputDir}/#{@inputFileArray[0]}")
         @inputFileArray[0] = File.basename(fullPathToUncompFile)
      end

      size1 = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}}.split.first.to_i
      @mVecOriginal = GSL::Vector.alloc(size1)
      file = File.open("#{@outputDir}/#{(@inputFileArray[0])}")
      track = 0
      while ( line = file.gets )
         columns = line.split(/\t/)
         @mVecOriginal[track] = columns[9].to_f
         track += 1
      end
      file.close()
      for i in 1 ... @inputFileArray.size
         @inputFileArray[i] = CGI.escape(@inputFileArray[i])
         expanderObj = BRL::Genboree::Helpers::Expander.new("#{@outputDir}/#{@inputFileArray[i]}")
         if(compressed = expanderObj.isCompressed?("#{@outputDir}/#{@inputFileArray[i]}"))
            expanderObj.extract('text')
            fullPathToUncompFile = expanderObj.uncompressedFileName
            system("rm #{@outputDir}/#{@inputFileArray[i]}")
            @inputFileArray[i] = File.basename(fullPathToUncompFile)
         end
         @overlappedRegion = ""
         common = ["empty"]
         @inputFileA = CGI.unescape(@inputFileArray[i])
          @inputFileA = @inputFileA.gsub(/_N(\d)+N/,"")
          @filewrite.print "#{@inputFileA}\t"
          size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}}.split.first.to_i
          @mVec1 = @mVecOriginal
       
          ##Condition one, if the size of wig is not eqaul
          if(size2 != size1 and @format == "Wig")
            common = findCommonRegioninWig(@inputFileArray[i])
            sizeA = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}_common}.split.first.to_i
            sizeB = %x{wc -l #{@outputDir}/#{(@inputFileArray[0])}_common}.split.first.to_i
            if(sizeA == sizeB and sizeA.to_i > 0)
              @mVec1 = GSL::Vector.alloc(sizeA)
              @mVec2 = GSL::Vector.alloc(sizeA)
              file1 = File.open("#{@outputDir}/#{(@inputFileArray[i])}_common")
              file2 = File.open("#{@outputDir}/#{(@inputFileArray[0])}_common")
              track = 0
              while ( line1 = file1.gets and line2 = file2.gets)
                columns1 = line1.split(/\t/)
                columns2 = line2.split(/\t/)
                @mVec1[track] = columns1[9].to_f
                @mVec2[track] = columns2[9].to_f
                track += 1
              end
              
              file1.close
              file2.close
             File.delete("#{@outputDir}/#{(@inputFileArray[i])}_common")
             File.delete("#{@outputDir}/#{(@inputFileArray[0])}_common")
              filterVector(common)
              
            elsif(sizeA != sizeB )
              $stdout.puts "error: Sizes are not equal for #{@inputFileArray[i]}, query = #{sizeA} and target = #{sizeB}"
              @filewrite.write "NaN\t(No data points in common region)\n"
             File.delete("#{@outputDir}/#{(@inputFileArray[i])}_common")
             File.delete("#{@outputDir}/#{(@inputFileArray[0])}_common")
            else
               $stdout.puts "error: No common region found #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
            end
              File.delete("#{@outputDir}/#{(@inputFileArray[i])}.wig")
            ##Condition one, if the size of Lff is not eqaul
          elsif (size2 != size1 and @format == "Lff")
              $stdout.puts "error: Sizes are not equal for #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
          else
            @mVec2 = GSL::Vector.alloc(size2)
            file = File.open("#{@outputDir}/#{(@inputFileArray[i])}")
            track = 0
            while ( line = file.gets )
              columns = line.split(/\t/)
              @mVec2[track] = columns[9].to_f
              track += 1
            end
            
            file.close()
            filterVector(common)
          end
          
          File.delete("#{@outputDir}/#{(@inputFileArray[i])}")
          if(File.exists?("#{@outputDir}/#{(@inputFileArray[i])}.wig"))
              File.delete("#{@outputDir}/#{(@inputFileArray[i])}.wig")
          end
        end
        
        @filewrite.close
        system("sed '1q' #{@outputDir}/summary.txt > #{@outputDir}/temp.txt")
        system("sed '1,1d' #{@outputDir}/summary.txt |sort -t$'\t' -k2,2rn >> #{@outputDir}/temp.txt")
        system("mv #{@outputDir}/temp.txt #{@outputDir}/summary.txt")
        rescue => err
           $stderr.puts "Details: #{err.message}"
    end
    
  end
  
    
    ##Finding common chromosomes between two tracks if they are not equal in size(when there is no ROI) 
   def findCommonRegioninWig(fileName)
         file1 = File.open("#{@outputDir}/#{@inputFileArray[0]}.wig")
         file2 = File.open("#{@outputDir}/#{fileName}.wig")
         tempFile1 = File.open("#{@outputDir}/#{@inputFileArray[0]}_common","w+")
         tempFile2 = File.open("#{@outputDir}/#{fileName}_common","w+")
         
         ##Greping all the chromomosomes
         result1 = %x{grep 'chrom=' #{@outputDir}/#{@inputFileArray[0]}.wig}
         result2 = %x{grep 'chrom=' #{@outputDir}/#{fileName}.wig}
         
         @chr1 = []
         @chr2 = []
         temp = result1.split(/\n/)
         temp1 = result2.split(/\n/)
        
         for i in 0 ...temp.size
          @chr1[i]  =temp[i].split(/chrom=/)[1].split(/span/)[0].strip!
         end
         
         for i in 0 ...temp1.size
          @chr2[i] = temp1[i].split(/chrom=/)[1].split(/span/)[0].strip!
         end
         
        
         ##Intserection of two arrays
          common = @chr1 & @chr2
         @lffClass =""
         @lffType =""
         @lffSubType =""
         @chr =""
         @startPoint = 0
         @endPoint = 0
         ##Making new files for common 
         while( line1 = file1.gets )
                 if(line1 =~/variable/)
                         @chr  =line1.split(/chrom=/)[1].split(/span/)[0].strip!	
                 end
                         if(common.include?(@chr) and line1 !~ /variable/)
                         
                                 columns = line1.split(/\s/)
                                 score = columns[1]
                                 @endPoint = columns[0].to_i + @resolution.to_i
                       
                                 tempFile1.write("#{@lffClass}\t\t\t\t\t\t\t\t\t#{score}\n")
                                 @startPoint = @endPoint
                         end
         
         end
         file1.close
         tempFile1.close
         
         @startPoint = 0
         @chr =""
         while( line1 = file2.gets )
                 if(line1 =~/variable/)
                         @chr  =line1.split(/chrom=/)[1].split(/span/)[0].strip!
                 end
                         if(common.include?(@chr) and line1 !~ /variable/)
                                 columns = line1.split(/\s/)
                                 score = columns[1]
                                 @endPoint = columns[0].to_i + @resolution.to_i
                       
                                 tempFile2.write("#{@lffClass}\t\t\t\t\t\t\t\t\t#{score}\n")
                                 @startPoint = @endPoint
                         end
         end     
         file2.close
         tempFile2.close
         return common
    end
    
    
    ## Removing noise from the data by removing "NAN" values and those entry points have zero in same position
    def filterVector(common)
      begin
         mVec11 = GSL::Vector.alloc(@mVec1.size)
         mVec22 = GSL::Vector.alloc(@mVec1.size)
      
       if(@filter == "true")
         $stdout.puts" filtering"
          track = 0
          for i in 0 ... @mVec1.size
            unless((@mVec1[i].to_f == 0.0 and @mVec2[i].to_f == 0.0) or (@mVec1[i].to_f == 4290772992 or @mVec2[i].to_f == 4290772992))
              mVec11[track] = @mVec1[i]
              mVec22[track] = @mVec2[i]
              track += 1
            end 
          end
          if(track ==0)
            $stderr.puts "Cannt proceed further. Only #{track} data points to make model"
           @filewrite.write "NaN\t(No data points in common region)\n"
           raise " Cannt proceed further. Only #{track} data points to make model"
        elsif(track < 6)
          $stderr.puts "Cannt proceed further. Only #{track} data points to make model"
          @filewrite.write "NaN\t(Not enough data points)\n"
           raise " Cannt proceed further. Only #{track} data points to make model"
        end
          @mVec11 = GSL::Vector.alloc(track)
          @mVec22 = GSL::Vector.alloc(track)
          for i in 0...track
           @mVec11[i] = mVec11[i]
           @mVec22[i] = mVec22[i]
          end
          mVec11 = 0
          mVec22 = 0
       
       else
         $stdout.puts "no-filtering"
         @mVec11 = GSL::Vector.alloc(@mVec1.size)
         @mVec22 = GSL::Vector.alloc(@mVec1.size)
         for ij in 0 ...@mVec1.size
            if(@mVec1[ij].to_f == 4290772992)
               @mVec1[ij]  = 0.0
              
            end
            if(@mVec2[ij].to_f == 4290772992)
               @mVec2[ij]  = 0.0
            end
      
            @mVec11[ij] = @mVec1[ij]
            @mVec22[ij] = @mVec2[ij]
         end
        # @mVec11 = @mVec1
        # @mVec22 = @mVec2 
         
       end
        ## flushing out memory
         @mVec1 = 0
         @mVec2 = 0
      
      
      ##Checking if the data has more than 5 unique data points
      hashTable = {}
      continueCheck1 = false
      for ij in 0...@mVec11.size
         hashTable[@mVec11[ij]] = @mVec22[ij]
         if(hashTable.size>6)
            continueCheck1 = true
            break
         end
      end
       hashTable2 = {}
      continueCheck2 = false
      for ij in 0...@mVec11.size
         hashTable2[@mVec22[ij]] = @mVec11[ij]
         if(hashTable2.size>6)
            continueCheck2 = true
            break
         end
      end
      if(continueCheck1 == false and continueCheck2 ==false)
         $stderr.puts "Cannt proceed further. Only #{track} unique data points to make model"
         @filewrite.write "NaN\t(Not enough unique data points)\n"
         raise " Cannt proceed further. Only #{track} unique data points to make model"
        end
      
       ## Quantile normalization
        if( @quantileNormalized == "true")
          $stdout.puts "normalizing"
         temp = IndexSort.new(@mVec11,@mVec22)
         tempArray = []
         temp.sort_index()
         tempArray =  temp.newQuantileNormalized()
         @mVec11 = tempArray[0]
         @mVec22 = tempArray[1]
        end
        
        
        ##Calculating linear regression\
        
        lr  = GSL::Fit::linear(@mVec11,@mVec22)
        cor = GSL::Stats::correlation(@mVec11,@mVec22)
        mean = @mVec11.mean
        mean2 = @mVec22.mean
        sd = @mVec11.sd
        chiSqaure = 0.0
        stotal = 0
        serror = 0
        for ii in 0 ...@mVec22.size
           stotal  = stotal + (mean2.to_f - @mVec22[ii])*(mean2.to_f - @mVec22[ii])
        end
          @filewrite.printf("%6f\t","#{cor}")
          @filewrite.printf("%6f\t","#{lr[5]}")
          @filewrite.printf("%6f\t","#{lr[0]}")
          @filewrite.printf("%6f\t","#{lr[1]}")
          
         for i in 0...@mVec11.size
           predictedValue = lr[0]+lr[1]*@mVec11[i].to_f
           residual = predictedValue.abs - @mVec22[i].to_f.abs
           serror = serror + residual*residual
           residual = residual.abs
           chiSqaure = chiSqaure + residual*residual/predictedValue
         end
        rSqaure = 1 - lr[5]/stotal 
        df = @mVec11.size - 1
        a = (chiSqaure*chiSqaure)/df-1
        
        @filewrite.printf("%6f\t", chiSqaure)
        if(a>0)
         rmsea = Math.sqrt(((chiSqaure*chiSqaure)/df-1)/(df))
         @filewrite.printf("%6f\t", rmsea)
        else
           @filewrite.printf("NaN\t")
        end
         fValue = rSqaure/(1-rSqaure)
         @filewrite.printf("%6f\n", fValue)
      
                
        #if( common[0] != "empty" or common[0] =~ /chr/)
        #  @filewrite.write "\t(Overlapped regions "
        #  for i in 0...common.size
         #   @filewrite.write "#{common[i]} "
         # end
         # @filewrite.puts ")"
       # elsif (common[0] == "empty")
        #  @filewrite.puts ""
        #end
      rescue => err
         $stderr.puts "Details: #{err.message}"
         $stderr.puts err.backtrace.join("\n")
      end
      
        
  end
  
   def SignalSimilarity.usage(msg='')
          unless(msg.empty?)
            puts "\n#{msg}\n"
          end
          puts "
      
        PROGRAM DESCRIPTION:
           Pairwise epigenome comparison tool
        COMMAND LINE ARGUMENTS:
          --file         | -f => Input files comma sperated, last ROI track(optional)
          --scratch      | -s => Scratch directory
          --output       | -o => Output directory
          --format       | -F => Format of input files (Wig|Lff)
          --filter       | -c => Filter the vectors (true|false)
          --analysis     | -a => Analysis name
          --resolution   | -r => Resolution
          --quantileNormalized |-q => QuantileNormalization (true|false)
          --help         | -h => [Optional flag]. Print help info and exit.
      
       usage:
       
    
      
        ";
            exit;
        end # 
      
      # Process Arguements form the command line input
      def SignalSimilarity.processArguements()
        # We want to add all the prop_keys as potential command line options
         optsArray = [ ['--file'  ,    '-f', GetoptLong::REQUIRED_ARGUMENT],
                       ['--scratch',   '-s', GetoptLong::REQUIRED_ARGUMENT],
                       ['--output',    '-o', GetoptLong::REQUIRED_ARGUMENT],
                       ['--format',    '-F', GetoptLong::REQUIRED_ARGUMENT],
                       ['--filter',    '-c', GetoptLong::REQUIRED_ARGUMENT],
                       ['--analysis' , '-a', GetoptLong::REQUIRED_ARGUMENT],
                       ['--resolution','-r', GetoptLong::REQUIRED_ARGUMENT],
                       ['--quantileNormalized' ,'-q', GetoptLong::REQUIRED_ARGUMENT],
                       ['--help'      ,'-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      SignalSimilarity.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
    
      Coverage if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
      end 

end

optsHash = SignalSimilarity.processArguements()
performQCUsingFindPeaks = SignalSimilarity.new(optsHash)
performQCUsingFindPeaks.readFiles()
