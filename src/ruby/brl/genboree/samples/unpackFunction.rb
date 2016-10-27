# 
# input: two appropriate arrays from the expDataFields table, 
# sorted by fieldOrder
#
# fieldType: column = dataType
# fieldSize: column = size

require 'brl/util/util'

# returns the correct unpack string to be used like:
# array.unpack("string")
def returnUnpackString(fieldType,fieldSize)
  outString = "";
  0.upto(fieldType.length-1) do |i|
    case fieldType[i]
      
      # #  type  (if null)
      #
      # 0 = text ("")
      # 1 = float (Float::MAX)
      # 2 = int32 (Integer::MAX32)
      # 3 = int64 (Integer::MAX64)
      # 4 = bool (\a)
      # 5 = date ("")
            
      when 0 then
        outString = outString + "A" + "#{fieldSize[i]}"
      when 1 then
        outString = outString + "d"
      when 2 then
        outString = outString + "i"
      when 3 then
        outString = outString + "N"
      when 4 then
        outString = outString + "A1"                  
    when 5 then
        outString = outString + "A10"
    end
  end
  return outString
end



#
# returns an array with the unpacked data
#
def doUnpack(filename,fieldType,fieldSize)
  packedFile = File.new(filename)
  unpackedArray = packedFile.gets.chomp.unpack(returnUnpackString(fieldType,fieldSize))
  puts unpackedArray

  #now, correct any of the edge cases we used for nil field markers
  0.upto(unpackedArray.length) do |i|
    case fieldType[i]
      when 1 then
        if (unpackedArray[i] == Float::MAX)
          unpackedArray[i] = nil
        end
      when 2 then
        if (unpackedArray[i] == Integer::MAX32)
           unpackedArray[i] = nil
        end
      when 3 then
        if (unpackedArray[i] == Integer::MAX64)
           unpackedArray[i] = nil
        end
      when 4 then
        if (unpackedArray[i] == "\a")
          unpackedArray[i] = nil
        end
    end
  end
  return unpackedArray
end
