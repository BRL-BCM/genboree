
module BRL ; module BlockSet

class Block
    attr_reader :score, :index
    attr_writer :score
    
    def initialize
        @index = Hash.new
    end
    
    def clear
        @index.clear
    end
    #---------------------------------------------------------------------------
    # Add additional alignments for this particular block
    #---------------------------------------------------------------------------
    def add_seq( name, entry, size, sense, seq)
        species,chrom = name.split('.')
        @index[species] = [name, entry.to_i, size.to_i, sense, seq ]
    end
    
    #---------------------------------------------------------------------------
    # Returns the number of elements in this block
    #---------------------------------------------------------------------------
    def size()
        return @index.size
    end
        
    #---------------------------------------------------------------------------
    # Stringify this block for printing
    #---------------------------------------------------------------------------
    def to_s
        str = ""
        len1, len2, len3, len4 = 0, 0, 0, 0, 0
        @index.each_value{ |v| 
            len1 = v[0].size if v[0].size > len1
            len2 = v[1].to_s.size if v[1].to_s.size > len2
            len3 = v[2].to_s.size if v[2].to_s.size > len3
            len4 = v[3].size if v[3].size > len4
        }
        @index.each_pair{ |k,v|
            str << "#{v[0]}:".ljust(len1+2)
            str << "#{v[1]}".ljust(len2+2)
            str << "#{v[2]}".ljust(len3+2)
            str << "#{v[3]}".ljust(len4+2)
            str << "#{v[4]}"#[0..50] + "..."
            str << "\n"
        }
        str
    end
    
    #---------------------------------------------------------------------------
    # Iterator.  Returns @index[i], or the [name, entry, size, sense, seq] for
    #            each block element.
    #---------------------------------------------------------------------------
    def each( )
        @index.each_key{ |i|
            yield( @index[i] )
        }
    end
    
    def []( i )
        return @index[ i ]
    end
end

end ; end
