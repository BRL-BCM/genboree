require 'win32ole'

# * *Author*: Matthew Linnell
# * *Class*: WIN32OLE (additions)
# * *Desc*: Extra funcationality added to the WIN32OLE library. 
class WIN32OLE
    module Constants
    end

    ########################################################################
    # * *Function*:  Prints all the WIN32OLE constants for this object (self).
    # 
    # * *Usage*   : <tt>  WIN32OLE.new('excel.application').constants()  </tt>  
    # * *Args*    : 
    #   - +none+ 
    # * *Returns* : 
    #   - +none+ 
    # * *Throws* :
    #   - +none+ 
    ########################################################################
    def constants( )
        WIN32OLE.const_load( self, WIN32OLE::Constants)
        
        print <<END
        
        class WIN32OLE
          module WORD_CONST
END
        WIN32OLE::Constants.constants.each { |v|
          print '    ', v, ' = ', eval("WIN32OLE::Constants::#{v}"), "\n"
        }
        
        print <<END
          end
        end
END
    end
    
    ########################################################################
    # * *Function*:  Returns the VB style RGB value for the given (r, g, b) values.
    # 
    # * *Usage*   : <tt>  WIN32OLE.new('excel.application').rgb(255,100,20)  </tt>  
    # * *Args*    : 
    #   - +r+ -> Of type fixnum, the "red" value for this color, 0-255.
    #   - +g+ -> Of type fixnum, the "green" value for this color, 0-255.
    #   - +b+ -> Of type fixnum, the "blue" value for this color, 0-255.
    # * *Returns* : 
    #   - +color+ -> The VB style RGB color.
    # * *Throws* :
    #   - +none+ 
    ########################################################################
    def rgb(r, g, b)
            return r | g << 8 | b << 16
    end
end
