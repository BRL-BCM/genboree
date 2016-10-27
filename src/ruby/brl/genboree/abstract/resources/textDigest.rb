#!/usr/bin/env ruby
require 'brl/util/util'
require 'brl/genboree/dbUtil'

# List of fdata2 fields that are required
module BRL ; module Genboree ; module Abstract ; module Resources
  class TextDigest
    INIT_DIGEST_SIZE = 6
    MAX_DIGEST_SIZE = 30
    def self.getTextByDigest(dbu, digest)
      retVal = nil
      if(dbu)
        resultSet = dbu.selectTextDigestByDigest(digest)
        if(resultSet and !resultSet.empty?)
          row = resultSet.first
          retVal = row['value']
          resultSet.clear
        end
      end
      return retVal
    end

    def self.getCreationTimeByDigest(dbu, digest)
      retVal = nil
      if(dbu)
        resultSet = dbu.selectTextDigestByDigest(digest)
        if(resultSet and !resultSet.empty?)
          row = resultSet.first
          retVal = row['creationTime']
          retVal = Time.parse(retVal.to_s)
          resultSet.clear
        end
      end
      return retVal
    end

    def self.alreadyStored?(dbu, text, digest)
      retVal = false
      if(dbu)
        resultSet = dbu.selectTextDigestByDigest(digest)
        if(resultSet and !resultSet.empty?)
          row = resultSet.first
          if(digest == row['digest'] and text == row['value'])
            retVal = true
          end
          resultSet.clear
        end
      end
      return retVal
    end

    def self.digestValueInUse?(dbu, digest)
      retVal = false
      if(dbu)
        resultSet = dbu.selectTextDigestByDigest(digest)
        if(resultSet and !resultSet.empty?)
          retVal = true
          resultSet.clear
        end
      end
      return retVal
    end

    def self.createUniqueDigest(dbu, text, initDigestSize=INIT_DIGEST_SIZE)
      retVal = nil
      if(dbu)
        created = false
        digestSize = initDigestSize
        while(!created)
          digest = text.xorDigest(digestSize)
          # Is our digest in use?
          resultSet = dbu.selectTextDigestByDigest(digest)
          row = ( (resultSet and !resultSet.empty?) ? resultSet.first : nil )
          if(row.nil? or row['value'] == text)
            # Then either in use by SAME text or not in use at all.
            # Regardless, insert with update of creation time if existing record found.
            dbu.insertTextDigestRec(digest, text)
            retVal = digest
            created = true
          else
            # Digest in use by some other text. Create new digest that is a bit longer.
            digestSize += 1
            # Check that we're not going over the max digest size storable in table
            raise "ERROR: tried to get unique digests of size #{initDigestSize} through #{MAX_DIGEST_SIZE} and could NOT FIND A UNIQUE ONE! FATAL BUG!" if(digestSize > MAX_DIGEST_SIZE)
          end
        end
      end
      return retVal
    end
  end
end ; end ; end ; end  # module BRL ; module Genboree ; module Abstract ; module Resources
