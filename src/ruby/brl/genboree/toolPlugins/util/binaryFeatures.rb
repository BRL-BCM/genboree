# Matthew Linnell
# January 11th, 2006
#-------------------------------------------------------------------------------
# Convert a given sequence into a binary vector of features
#-------------------------------------------------------------------------------

module BRL
  module Genboree
    module ToolPlugins
      module Util
        # Basic support for generating all possible kmers
        module Kmers
            #---------------------------------------------------------------------------
            # * *Function*: Gets all possible kmers of size specified
            #
            # * *Usage*   : <tt> get_kmers( 6 ) </tt>  
            # * *Args*    : 
            #   - +size+ -> The integer value for the size of kmers requested  
            # * *Returns* : 
            #   - +Array+ -> An Array of all possible kmers of the specified size 
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            def get_kmers( size )
                size = size.to_i
                arr = add_a( "", size ), add_c( "", size ), add_g( "", size ), add_t( "", size )
                return arr.flatten
            end

            def add_a( str, size )
                str = str.clone
                str << "a"
                return recurse( str, size )
            end
            
            def add_t( str, size )
                str = str.clone
                str << "t"
                return recurse( str, size )
            end
            
            def add_c( str, size )
                str = str.clone
                str << "c"
                return recurse( str, size )
            end
            
            def add_g( str, size )
                str = str.clone
                str << "g"
                return recurse( str, size )
            end

            def recurse( str, size )
                if str.size == size
                    return str
                else
                    return [ add_a( str, size ),
                             add_c( str, size ),
                             add_g( str, size ),
                             add_t( str, size ) ]
                end
            end
        end

        class BinaryFeatures
            #-------------------------------------------------------------------
            # * *Function*: Returns a list of availble "functions" (types of binary features) availabll.  Register new functions here.
            #
            # * *Usage*   : <tt> BinaryFeatres.functions() </tt>  
            # * *Args*    : 
            #   - +none+ ->  
            # * *Returns* : 
            #   - +Hash+ -> A Hash of avaiable binary representations with the description and input requirements
            # * *Throws* :
            #   - +none+     
            #-------------------------------------------------------------------
            def self.functions()
                return {
                    :basic_kmer=>{
                        :desc=>"Basic kmer representation of sequence.", 
                        :inputs=>{ :kmer=>"The kmer size for the binary representation." } 
                    }
                }
            end

            #---------------------------------------------------------------------------
            # * *Function*: Basic Kmer.  The most basic binary representation where the 
            # binary features represent kmers present in the given sequence
            # The sequence_text follows the output format from SeqExtractor.  NOTE: {options} is used because
            # the sender does not know what is is calling or what options are needed in said call,
            # so we just pass the options around
            #
            # * *Usage*   : <tt> BinaryFeatures.basic_kmer( { :kmer=>6 }, "ATCGTACGTACT" ) </tt>  
            # * *Args*    : 
            #   - +options+ -> A Hash of options for the execution of this tool.  For this function, options must contain :kmer=>{integer value}  
            #   - +sequence_text+ -> A string where each sample is composed of 2 newline delimeted parts, 1) Sample defline (chr, start, stop, etc), 2) Sequence.  So each sample is 2 lines.  This was designed for use in conjunction with seqRetreiver library, where we have a defline and a sequence line 
            # * *Returns* : 
            #   - +String+ -> Returns a string comprised of the sample definition and the corresponding binary representation of the sequence 
            # * *Throws* :
            #   - +none+     
            #-------------------------------------------------------------------
            def self.basic_kmer( options, sequence_text )
                size = options[:kmer].to_i
                # Create all possible 6mers (or Xmers the size of {win})
                all_possible = Kmers.get_kmers( size )
                hsh = MyHash.new
                all_possible.each{ |ii| hsh[ii] = 0 }
                hsh.freeze_keys = true # We don't want to allow any additional keys
                str = ""
                sequence_text.each_line do |line|
                    if line[0,1] == ">"
                        str << line[1..-2] + "\t"
                    else
                        binary_vector = hsh.clone
                        line.strip!
                        0.upto(line.strip.size - size){ |ii|
                            binary_vector[ line[ii,size].downcase ] = 1
                        }
                        bv = binary_vector
                        bv.sort.each{ |jj| str << jj[1].to_s }
                        str << "\n"
                    end
                end
                return str
            end

            #---------------------------------------------------------------------------
            # * *Function*: Returns a string array representing the header (for use in .wnw definition files) 
            #
            # * *Usage*   : <tt> BinaryFeatures.basic_kmer_attributes( { :kmer=>6} ) </tt>  
            # * *Args*    : 
            #   - +options+ -> Much like basic_kmer(), we pass options around because sender is not aware of what it is calling
            # * *Returns* : 
            #   - +Array+ -> An Array of all possible kmers of size {:kmer=>somesize} 
            # * *Throws* :
            #   - +none+     
            #---------------------------------------------------------------------------
            # Returns a string array representing the header (for use in .wnw files)
            # based on the basic_kmer representation
            # Options:
            #   :kmer => Size of the Kmer to be used
            def self.basic_kmer_attributes( options )
                Kmers.get_kmers( options[:kmer] )
            end

        end
      end
    end
  end
end
