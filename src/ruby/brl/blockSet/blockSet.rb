require 'brl/blockSet/block'
require 'brl/util/textFileUtil'
include BRL::Util
include BRL::BlockSet

module BRL ; module BlockSet 

class BlockSet < Array
    
    def initialize(  )
        super()
    end

    def clear
        self.each{ |ii| ii.clear }
        super()
    end
    #---------------------------------------------------------------------------
    # Takes the multiple alignment file (maf) and converts into blockset, self
    #---------------------------------------------------------------------------
    def load_maf_file( file_name )
        f = TextReader.new( file_name )
        # Chop off comment lines, load file into TBA structure
        blk = nil
        f.each{ |line| 
            next if( line[0..0] == "#" || line=="\n" )
            if line.split( "=" )[0] =="a score"
                blk = Block.new
                # Parse out the score for this block
                blk.score = line.split( "=" )[1].strip.to_i
                self.add_block blk
                next
            end
            
            # Create block.  First seq is reference sequence, all others supplimentary
            temp = line.split
            blk.add_seq( temp[1], temp[2], temp[3], temp[4], temp[6] )
        }
        f.close
        
        # Since we are working with only 2 species from an 8 species alignment, 
        # We want to eleminate 1-block_element blocks
        self.delete_if{ |i| i.size <= 1 }
    end
    
    def load_axt_file( file_name, species_1, species_2 )
        f = TextReader.new( file_name )
        # Chop off comment lines, load file into TBA structure
        blk = nil
        tmp_arr = []
        seq = []
        f.each{ |line|
            next if( line[0..0] == "#" || line.strip.size == 0 )
            if line.split( " " ).size > 1
                blk = Block.new
                # Parse out the score for this block 
                tmp, chrA, entry1, stop1, chrB, entry2, stop2, sense, score = line.strip.split(" ")
                size1 = stop1.to_i - entry1.to_i
                size2 = stop2.to_i - entry2.to_i
                tmp_arr = [ "#{species_1}.#{chrA}", entry1, stop1, sense, "#{species_2}.#{chrB}", entry2, stop2 ]
                blk.score = score
                self.add_block blk
                next 
            else
                seq.push line.strip
            end
    
            # Create block.  First seq is reference sequence, all others supplimentary
            if seq.size == 2
                blk.add_seq( tmp_arr[0], tmp_arr[1], tmp_arr[2], tmp_arr[3], seq[0] )
                blk.add_seq( tmp_arr[4], tmp_arr[5], tmp_arr[6], tmp_arr[3], seq[1] )
                seq.clear
            end
        }
        f.close   

        # Since we are working with only 2 species from an 8 species alignment,
        # We want to eleminate 1-block_element blocks
        self.delete_if{ |i| i.size <= 1 }
    end

    #---------------------------------------------------------------------------
    # Takes the PASH alignment file and converts into blockset, self
    #---------------------------------------------------------------------------
    #ARJ: 3/21/2005 12:48PM
    #    Block only has 5 elements right now...losing the "chromosome" (lff field 4)
#    def load_pash_file( file_name )
#        f = TextReader.new( file_name )
#        # Chop off comment lines, load file into TBA structure
#        blk = nil
#        f.each{ |line| 
#            blk = Block.new
#            temp = line.split
#            # Parse out the score for this block
#            blk.score = temp[9]
#            self.add_block blk
#            blk.add_seq( temp[3], temp[5], temp[6].to_i-temp[5].to_i, temp[7], "", temp[4] )
#            blk.add_seq( temp[3], temp[10], temp[11].to_i-temp[10].to_i, temp[7], "", temp[4] )
#        }
#        f.close
#        
#        # Since we are working with only 2 species from an 8 species alignment, 
#        # We want to merge single element neighboring block elements
#        self.merge_contiguous!
#    end
    
    #---------------------------------------------------------------------------
    # Adds new block to this thread.
    #---------------------------------------------------------------------------
    def add_block( new_block )
        self.push( new_block )
    end
    
    #---------------------------------------------------------------------------
    # Merge contiguous single element blocks, and pack! single element blocks (remove "-")
    #---------------------------------------------------------------------------
    # ARJ: 3/21/2005 12:57PM
    # No more 1 block_element blocks currently, so merging in this way is meaningless.
    # If we need merging, this will need rewriting for species-based block_element access within blocks.
#    def merge_contiguous!()
#        # Merge 2 blocks if:
#        #  A) They are both 1 element blocks
#        #  B) When merged, represent 1 contiguous sequence.
#        new_arr = []
#        previous_block = nil
#        self.each{ |block|
#            previous_block = new_arr.last
#            if block.size != previous_block.nil?
#                new_arr.push block
#            elsif previous_block.size == 1 && block.start( 0 ) == (previous_block.start( 0 ) + previous_block.length( 0 ))
#                # Merge
#                # Update length (start posotion is the same)
#                new_arr.last[0][2] = new_arr.last[0][2] + block.length( 0 )
#                # Update sequence information
#                new_arr.last[0][4] += block[0][4]
#                # Update score (simple addition)
#                new_arr.last.score += block.score
#            else
#                new_arr.push block
#            end
#        }
#        self.replace new_arr
#    end
      
    #---------------------------------------------------------------------------
    # Generate LFF output string
    #---------------------------------------------------------------------------
    def generate_lff( file_prefix, opt_seq_output=true, drop_single_unit_blocks=true )
        output_hsh = Hash.new( )
        
        klass   = "TBA"
        type    = "TBA"
        header  = "[annotations]\n#class\tname\ttype\tsubtype\tref\tstart\tstop\tstrand\tphase\tscore\ttstart\ttend\topt-freeform\topt-seq\n"
        count = 1
        self.each{ |block|
            next if block.size == 1 && drop_single_unit_blocks
            score = block.score
            phase, tstart, tend, opt_freeform = ".",".",".","."
            block.each { |element|
                # We do not want random data (ie mm5 chrUn_random)
                next if element[0].include?("random")
                name    = "#{element[0].split(".")[1]}.#{count}"
                subtype = "#{element[0].split(".")[0]}.tba"
                ref     = element[0].split(".")[1]
                strand  = element[3]
                start   = element[1]
                stop    = element[1] + element[2]
                opt_seq_output ? opt_seq = element[4] : opt_seq = "."
                
                # Decide which file to output to
                if output_hsh.has_key?( "#{file_prefix}#{subtype}.#{ref}" ) 
                    output_hsh["#{file_prefix}#{subtype}.#{ref}"] << "#{klass}\t#{name}\t#{type}\t#{subtype}\t#{ref}\t#{start}\t#{stop}\t#{strand}\t#{phase}\t#{score}\t#{tstart}\t#{tend}\t#{opt_freeform}\t#{opt_seq}\n"
                else
                    output_hsh["#{file_prefix}#{subtype}.#{ref}"] = File.open( "#{file_prefix}#{subtype}.#{ref}", File::CREAT|File::APPEND|File::RDWR, 0644 )
                    output_hsh["#{file_prefix}#{subtype}.#{ref}"] << header
                end 
            }
            count += 1
        }
        
        # Close all the files we opened for writing.
        output_hsh.each_key{ |k|
            output_hsh[k].close
        }        
        return output_hsh
    end
    
    #---------------------------------------------------------------------------
    # Prints out blockset (thread)
    #---------------------------------------------------------------------------
    def display
        self.each{ |i|
            puts "Score=#{i.score}"
            puts "#{i}\n"
        }
    end
end

end ; end
