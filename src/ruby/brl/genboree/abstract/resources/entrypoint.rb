#!/usr/bin/env ruby

# Define comparison functions for false and true (each has its own class; weird and related to Ruby performance)
class FalseClass
  def <=>(op)
    opAsBool = !!op
    return (opAsBool ? -1 : 0)
  end
end

class TrueClass
  def <=>(op)
    opAsBool = !!op
    return (opAsBool ? 0 : 1)
  end
end

# Add variables to the String class to implement the Scwartzian Transform without an additional array.
class Hash
  attr_accessor :shwtzWord, :shwtzNum, :shwtzDone, :shwtzUnderScore
end

module BRL ; module Genboree ; module Abstract ; module Resources

  # Abstraction of a Genboree Entrypoint/Chromosome (fref). Implements some fundamental
  # behaviors concerning entrypoints.
  #
  class Entrypoint

    def self.getFrefRows(dbu, genbDBName, naturalSorted=true, verbose=false)
      intTime = startTime = Time.now

      # This method compares to Hash objects that contain an element with the key 'refname'
      # This will also work on DBI::Row objects but is SLOWER so use hashes if possible.
      #
      # It is specific to sorting chromosomes 'naturally'
      #
      # Example: (for Srings)
      #   cc = [ "chr1", "chr10", "chr11", "chr2", "chr2_random" ]
      # woud be sorted as
      #   ["chr1", "chr2", "chr10", "chr11", "chr2_random"]
      #
      # Do as much of the expensive stuff as possible only once.  This includes [], index, =~, to_i, downcase
      # Store the proceessed vars in the object that's being sorted.
      shwtzCmpHash = Proc.new { |xx, yy|
        if(!xx.shwtzDone)
          xxRefName = xx['refname']
          xx.shwtzUnderScore = !xxRefName.index('_').nil?
          xxRefName =~ /(\D+)?(\d+)?/
          xx.shwtzWord = $1.downcase unless($1.nil?)
          xx.shwtzNum = $2.to_i unless($2.nil?)
          xx.shwtzDone = true
        end
        if(!yy.shwtzDone)
          yyRefName = yy['refname']
          yy.shwtzUnderScore = !yyRefName.index('_').nil?
          yyRefName =~ /(\D+)?(\d+)?/
          yy.shwtzWord = $1.downcase unless($1.nil?)
          yy.shwtzNum = $2.to_i unless($2.nil?)
          yy.shwtzDone = true
        end

        retVal = (xx.shwtzUnderScore <=> yy.shwtzUnderScore)
        if(retVal == 0)
          if(xx.shwtzWord and yy.shwtzWord)
            retVal = (xx.shwtzWord <=> yy.shwtzWord)
          end
          if(retVal == 0 and xx.shwtzNum and yy.shwtzNum)
            retVal = (xx.shwtzNum <=> yy.shwtzNum)
          end
        end
        retVal
      }

      # This compare function does 'natural sorting' but isn't ideal because it does the regex everytime.  Should use Shwartzian transform approach
      cmp = Proc.new {|xxRow, yyRow|
        xx = xxRow['refname']
        yy = yyRow['refname']
        xx_ = !xx.index("_").nil?
        yy_ = !yy.index("_").nil?
        retVal = (xx_ <=> yy_)
        if(retVal == 0)
          xx =~ /(\D+)?(\d+)?/
          xxWord = $1
          xxNum = $2
          yy =~ /(\D+)?(\d+)?/
          yyWord = $1
          yyNum = $2
          if(xxWord and yyWord)
            retVal = (xxWord.downcase <=> yyWord.downcase)
          end
          if(retVal == 0 and xxNum and yyNum)
            retVal = (xxNum.to_i <=> yyNum.to_i)
          end
        end
        retVal
      }

      if(!genbDBName.nil?)
        # Get entrypoints in the user database
        dbu.setNewDataDb(genbDBName)
        frefRows = []
        # This methond will build an array of Hashes which is more efficient that DBI::Row objects
        dbu.eachBlockOfCols(:userDB, 'fref', 'rid, refname, rlength, gname') { |block|
          frefRows.concat(block)
        }
        frefRows = frefRows.sort(&shwtzCmpHash)
      else
        frefRows = nil
      end
      return frefRows
    end
  end
end ; end ; end ; end # module BRL ; module Genboree ; module Abstract ; module Resources
