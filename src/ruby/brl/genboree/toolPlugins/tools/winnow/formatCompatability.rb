require 'brl/genboree/toolPlugins/util/binaryFeatures'

module BRL ; module Genboree ;  module ToolPlugins ;  module Tools ;
module WinnowTool

module FormatCompatability
#-------------------------------------------------------------------------------
# This module provides compatability with Weka specific constructs, such as the ARFF file
#-------------------------------------------------------------------------------
  
    #---------------------------------------------------------------------------
    # Loads ARFF format file for use in building model.  The ARFF format is 
    # described by the Weka standard, http://www.cs.waikato.ac.nz/ml/weka/.  This
    # method will return the feature_list, the two classes, and an array of instances
    #   file = String or File object
    #---------------------------------------------------------------------------
    def load_arff( file,sample_no=nil )
        # If not given file, open file
      file = File.open( file ) unless file.class == File
        # First line is descriptor, we don't do anything with that (yet)
      file.rewind  
      file.readline
        # The following lines are the attribute descriptors
        # They look like this: @attribute(space)sunny_day(space){0,1}\n
        feature_list = []
        file.each_line{ |line| feature_list.push( line.strip.split(" ")[1,2] ); break if line.split(" ")[1] == "class" }
        t_class, f_class = feature_list.pop[1][1..-2].split( "," )
        # Now, load up training data/instances
        instances = []
        tmp = false
        line_no=0
        file.each_line{ |line|
        next if line.strip.size == 0
        if tmp
          binary_vector = line.strip.split(",")
          classified = binary_vector.pop == "true" ? true : false
          binary_vector.map!{ |ii| ii = ii == "1" ? true : false } # convert string to binary vals
          instances.push( Instance.new( binary_vector , classified ) )
          line_no+=1
          if sample_no!=nil&&line_no>=sample_no
            break
          end
        end
        tmp = true if (line.strip == "@data" || line.strip == "@DATA")
      }
      $stderr.puts("initialized from #{line_no} samples")
      return feature_list, t_class, f_class, instances,line_no
    end
 
    def shuffle_insts(insts)
      
      index=[]
      for ii in 0...insts.size
        index.push(ii)
      end

      shuffled=[]
      tmp_index=[]

      while index
        tt=rand(index.size-1)
        shuffled.push(insts[index[tt]])
        index.delete(index[tt])
      end
      
      return shuffled

    end


def convert_to_wnw( options, positives, negatives="" )
          str = ""
          # Create all possible 6mers (or Xmers the size of {kmer})
          all_possible = BinaryFeatures.send( "#{options[:binary]}_attributes", options )
          all_possible.sort!
          arr = []
          # Positive cases
          positives.each_line do |line|
              arr.push( line.split("\t")[0] + "\t" + line.strip.split("\t")[1].split("").join(",") + ",true")
          end
          # Negative cases (negative control)
          negatives.each_line do |line|
              arr.push( line.split("\t")[0] + "\t" + line.strip.split("\t")[1].split("").join(",") + ",false")
          end
          
          str << all_possible.join(",")
          str << ",class\n"
          str << arr.join("\n")
          str
        end


def readlff(lffIO)
  allSeq=[]
  lffIO.each_line { |line|
    next if (line =~ /^\s*$/ or line =~ /^\s*\[/ or line =~ /^\s*#/) # 
    fields = line.strip.split(/\t/)
    allSeq.push(">#{fields[1]}\t#{fields[13]}")
  }
  return allSeq
end

end;end;end;end;end;end;
