#!/usr/bin/env ruby
require 'json'
require 'fileutils'
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'gsl'
require 'brl/genboree/rest/apiCaller'
require 'brl/normalize/index_sort'

include GSL
include BRL::Genboree::REST


class SignalSimilarity

   def initialize(optsHash)
        @inputFile      = optsHash['--file']
        @scratch        = optsHash['--scratch']
        @output         = optsHash['--output']
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
        @outputDirW = "#{@scratch}/signal-search/#{@output}"
        @outputDir = "#{@scratch}/signal-search/#{@runName}"
        system("mkdir -p #{@outputDir}")
        system("mkdir -p #{@outputDirW}")
        @filewrite = File.open("#{@outputDirW}/summary.txt","w+")
        @inputFileArray[0] = CGI.escape(@inputFileArray[0])
        $stdout.puts @inputFileArray[0]
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
        
        for i in 1 ...@inputFileArray.size
          @overlappedRegion = ""
          common = ["empty"]
          @inputFileArray[i] = CGI.escape(@inputFileArray[i])
          @filewrite.print "#{CGI.unescape(@inputFileArray[i])}\t"
          size2 = %x{wc -l #{@outputDir}/#{(@inputFileArray[i])}}.split.first.to_i
          @mVec1 = @mVecOriginal
          $stdout.puts @inputFileArray[i]
          ##Condition one, if the size of wig is not eqaul
          if(size2 != size1 and @format == "Wig")
            common = findCommonRegioninWig(@inputFileArray[i])
            sizeA = %x{wc -l #{@outputDirW}/#{(@inputFileArray[i])}_common}.split.first.to_i
            sizeB = %x{wc -l #{@outputDirW}/#{(@inputFileArray[0])}_common}.split.first.to_i
            if(sizeA == sizeB and sizeA.to_i > 0)
              @mVec1 = GSL::Vector.alloc(sizeA)
              @mVec2 = GSL::Vector.alloc(sizeA)
              file1 = File.open("#{@outputDirW}/#{(@inputFileArray[i])}_common")
              file2 = File.open("#{@outputDirW}/#{(@inputFileArray[0])}_common")
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
             File.delete("#{@outputDirW}/#{(@inputFileArray[i])}_common")
             File.delete("#{@outputDirW}/#{(@inputFileArray[0])}_common")
              filterVector(common)
              
            elsif(sizeA != sizeB )
              $stdout.puts "error: Sizes are not equal for #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
            else
                $stdout.puts "error: No common region found #{@inputFileArray[i]}"
              @filewrite.write "NaN\t(No data points in common region)\n"
            end
            #  File.delete("#{@outputDir}/#{(@inputFileArray[i])}.wig")
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
          
        #  File.delete("#{@outputDir}/#{(@inputFileArray[i])}")
        end
        
        @filewrite.close
        system("sort #{@outputDirW}/summary.txt -t$'\t' -k2,2rn > #{@outputDirW}/temp.txt")
        system("mv #{@outputDirW}/temp.txt #{@outputDirW}/summary.txt")
        rescue => err
           $stderr.puts "Details: #{err.message}"
    end
    
  end
    
    ##Finding common chromosomes between two tracks if they are not equal in size(when there is no ROI) 
   def findCommonRegioninWig(fileName)
         file1 = File.open("#{@outputDir}/#{@inputFileArray[0]}.wig")
         file2 = File.open("#{@outputDir}/#{fileName}.wig")
         tempFile1 = File.open("#{@outputDirW}/#{@inputFileArray[0]}_common","w+")
         tempFile2 = File.open("#{@outputDirW}/#{fileName}_common","w+")
         
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
                       
                                 tempFile1.write("#{@lffClass}\t#{@inputFileArray[0]}\t#{@lffType}\t#{@lffSubType}\t#{@chr}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}\n")
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
                       
                                 tempFile2.write("#{@lffClass}\t#{@inputFileArray[0]}\t#{@lffType}\t#{@lffSubType}\t#{@chr}\t#{@startPoint}\t#{@endPoint}\t+\t0\t#{score}\n")
                                 @startPoint = @endPoint
                         end
         end     
         file2.close
         tempFile2.close
         return common
    end
    
    
    ## Removin0g noise from the data by removing "NAN" values and those entry points have zero in same position
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
         @mVec11 = @mVec1
         @mVec22 = @mVec2
       end
        ## flushing out memory
         @mVec1 = 0
         @mVec2 = 0
      
     
      
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
        puts cor
        puts @mVec11
        puts @mVec22
        puts @mVec22.size
          @filewrite.printf("%6f\n","#{cor}")
                
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
          --file         | -f => Input files comma sperated
          --scratch      | -s => Scratch directory
          --output       | -o => Output directory
          --format       | -F => Format of input files (Wig|Lff)
          --filter       | -c => Filter the vectors (true|false)
          --analysis     | -a => Analysis name
          --resolution   | -r => Resolution
          --quantileNormalized |-q => QuantileNormalization (true|false)
          --help         | -h => [Optional flag]. Print help info and exit.
      
       usage:
       
      ruby removeAdaptarsWrapper.rb -f jsonFile  
      
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
