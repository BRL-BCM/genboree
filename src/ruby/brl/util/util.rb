#!/usr/bin/env ruby

# Turn off extra warnings and such
$VERBOSE = nil

require 'getoptlong'
require 'fcntl'
require 'zlib'
require 'cgi'
require 'net/ftp'
require 'shellwords'
require 'popen4'
require 'time'
# To ensure both 1.8 and 1.9 availability of SHA1 and MD5 classes
require 'digest/sha1'
require 'digest/md5'
class SHA1 < Digest::SHA1 ; end
class MD5 < Digest::MD5 ; end

module BRL ; module Util
  FATAL, OK, OK_WITH_ERRORS, FAILED, USAGE_ERR = 1,0,10,20,16
  BLANK_RE = /^\s*$/
  COMMENT_RE = /^\s*#/
  COLOR_MAP_HASH = {
      "Maroon"=>"#800000",
      "LightBlue"=>"#ADD8E6",
      "MediumAquaMarine"=>"#66CDAA",
      "Aquamarine"=>"#7FFFD4",
      "SeaShell"=>"#FFF5EE",
      "SandyBrown"=>"#F4A460",
      "HoneyDew"=>"#F0FFF0",
      "BurlyWood"=>"#DEB887",
      "LightSeaGreen"=>"#20B2AA",
      "Yellow"=>"#FFFF00",
      "RoyalBlue"=>"#4169E1",
      "RosyBrown"=>"#BC8F8F",
      "Navy"=>"#000080",
      "Cornsilk"=>"#FFF8DC",
      "LavenderBlush"=>"#FFF0F5",
      "Silver"=>"#C0C0C0",
      "FloralWhite"=>"#FFFAF0",
      "Bisque"=>"#FFE4C4",
      "Plum"=>"#DDA0DD",
      "Aqua"=>"#00FFFF",
      "Azure"=>"#F0FFFF", "BlueViolet"=>"#8A2BE2",
      "LightPink"=>"#FFB6C1", "Indigo"=>"#4B0082",
      "Beige"=>"#F5F5DC", "LawnGreen"=>"#7CFC00",
      "LightSkyBlue"=>"#87CEFA", "DarkGreen"=>"#006400",
      "LemonChiffon"=>"#FFFACD", "Black"=>"#000000",
      "IndianRed"=>"#CD5C5C", "LightCoral"=>"#F08080",
      "LightSteelBlue"=>"#B0C4DE", "Turquoise"=>"#40E0D0",
      "DarkViolet"=>"#9400D3", "YellowGreen"=>"#9ACD32",
      "WhiteSmoke"=>"#F5F5F5", "FireBrick"=>"#B22222",
      "DarkSalmon"=>"#E9967A", "Chartreuse"=>"#7FFF00",
      "Violet"=>"#EE82EE", "SkyBlue"=>"#87CEEB",
      "LimeGreen"=>"#32CD32", "DarkOliveGreen"=>"#556B2F",
      "HotPink"=>"#FF69B4", "SteelBlue"=>"#4682B4",
      "DarkGray"=>"#A9A9A9", "DarkKhaki"=>"#BDB76B",
      "Gray"=>"#808080", "DarkMagenta"=>"#8B008B",
      "GreenYellow"=>"#ADFF2F", "MediumSpringGreen"=>"#00FA9A",
      "LightSlateGray"=>"#778899", "Chocolate"=>"#D2691E",
      "MediumBlue"=>"#0000CD", "DeepPink"=>"#FF1493",
      "MediumSeaGreen"=>"#3CB371", "DodgerBlue"=>"#1E90FF",
      "LightGoldenRodYellow"=>"#FAFAD2", "OliveDrab"=>"#6B8E23",
      "LightGreen"=>"#90EE90", "SlateGray"=>"#708090",
      "DarkGoldenRod"=>"#B8860B", "Orchid"=>"#DA70D6",
      "GoldenRod"=>"#DAA520", "DarkSeaGreen"=>"#8FBC8F",
      "DeepSkyBlue"=>"#00BFFF", "Teal"=>"#008080",
      "SaddleBrown"=>"#8B4513", "Peru"=>"#CD853F", "Orange"=>"#FFA500",
      "Tomato"=>"#FF6347", "BlanchedAlmond"=>"#FFEBCD",
      "Crimson"=>"#DC143C", "NavajoWhite"=>"#FFDEAD",
      "Snow"=>"#FFFAFA", "Cyan"=>"#00FFFF", "Wheat"=>"#F5DEB3",
      "Tan"=>"#D2B48C", "MediumOrchid"=>"#BA55D3", "Red"=>"#FF0000",
      "Gainsboro"=>"#DCDCDC", "LightYellow"=>"#FFFFE0", "DarkOrchid"=>"#9932CC",
      "Blue"=>"#0000FF", "Coral"=>"#FF7F50", "Purple"=>"#800080",
      "DarkTurquoise"=>"#00CED1", "DarkBlue"=>"#00008B",
      "DarkOrange"=>"#FF8C00", "MediumTurquoise"=>"#48D1CC", "Moccasin"=>"#FFE4B5",
      "Ivory"=>"#FFFFF0", "SlateBlue"=>"#6A5ACD", "LightGray"=>"#D3D3D3",
      "GhostWhite"=>"#F8F8FF", "Khaki"=>"#F0E68C", "Thistle"=>"#D8BFD8",
      "SpringGreen"=>"#00FF7F", "MistyRose"=>"#FFE4E1", "CornflowerBlue"=>"#6495ED",
      "PaleGoldenRod"=>"#EEE8AA", "AliceBlue"=>"#F0F8FF", "DarkSlateBlue"=>"#483D8B",
      "ForestGreen"=>"#228B22", "DarkCyan"=>"#008B8B", "Magenta"=>"#FF00FF",
      "PaleTurquoise"=>"#AFEEEE", "MediumPurple"=>"#9370DB", "OldLace"=>"#FDF5E6",
      "SeaGreen"=>"#2E8B57", "Green"=>"#008000", "MintCream"=>"#F5FFFA",
      "MidnightBlue"=>"#191970", "Sienna"=>"#A0522D", "CadetBlue"=>"#5F9EA0",
      "MediumVioletRed"=>"#C71585", "Brown"=>"#A52A2A", "DarkSlateGray"=>"#2F4F4F",
      "PeachPuff"=>"#FFDAB9", "PowderBlue"=>"#B0E0E6", "Fuchsia"=>"#FF00FF",
      "OrangeRed"=>"#FF4500", "Salmon"=>"#FA8072", "Linen"=>"#FAF0E6",
      "LightCyan"=>"#E0FFFF", "DimGray"=>"#696969", "AntiqueWhite"=>"#FAEBD7",
      "White"=>"#FFFFFF", "Pink"=>"#FFC0CB", "MediumSlateBlue"=>"#7B68EE",
      "Gold"=>"#FFD700", "PaleVioletRed"=>"#DB7093", "LightSalmon"=>"#FFA07A",
      "Lime"=>"#00FF00", "DarkRed"=>"#8B0000", "PapayaWhip"=>"#FFEFD5",
      "PaleGreen"=>"#98FB98", "Lavender"=>"#E6E6FA", "Olive"=>"#808000"
    }

  def setLowPriority()
    begin
      Process.setpriority(Process::PRIO_USER, 0, 19)
    rescue
    end
    return
  end

  class FileUtil
    def FileUtil::isemptyFile?(file)
      nonBlank  = false
      fileHandle = File.open(file, "r")
      fileHandle.each {| line|
        if(line =~ /\S/)
          nonBlank = true
          break
        end
        }
      return nonBlank
    end
  end

  class Job
    def Job::makeJobTicket()
      pid = Process.pid
      time = Time::now.to_i
      return "#{time}-#{pid}"
    end
  end

  class MemoryInfo
    @@procStatusFH = nil

    def MemoryInfo.getMemUsageStr()
      memStr = ''
      if(@@procStatusFH.nil?)
        begin
          @@procStatusFH = File.open("/proc/#{$$}/status")
        rescue
          memStr = nil
        end
      end
      if(@@procStatusFH.is_a?(File))
        @@procStatusFH.rewind rescue nil
        @@procStatusFH.readlines.each { |line|
          line.strip!
          if(line =~ /^VmSize:\s+(.*)$/)
            memStr = $1
            break
          end
        } rescue nil
        memStr = memStr.strip.commify
      else
        memStr = nil
      end
      return memStr
    end

    def MemoryInfo.getMemUsagekB()
      memStr = MemoryInfo.getMemUsageStr()
      return -1 if(memStr.nil? or memStr.empty?)
      matchData = /^([\d,]+)\s+(\S+)$/.match(memStr)
      memUsage, units = matchData[1].gsub(",", "").to_i, matchData[2].strip.downcase
      if(units =~ /kb/)
        return memUsage
      elsif(units =~ /mb/)
        return memUsage * 1000
      elsif(units =~ /gb/)
        return memUsage * 1000 * 1000
      else # bytes? wtf
        return -1
      end
    end
  end

  module Bzip2
    BZIP2_EXE = 'bzip2 -t '

    def Bzip2.isBzippedFile?(fileStr)
      fullFilePath = File.expand_path(fileStr)
      return false if((!fullFilePath.kind_of?(String)) or !FileTest.exists?(fullFilePath) or !FileTest.readable?(fullFilePath))
      fullFilePath.gsub!(/\"/, '\\"')
      cmdStr1 = "#{BRL::Util::Bzip2::BZIP2_EXE} \"#{fullFilePath}\" > /dev/null 2> /dev/null"
      begin
        system(cmdStr1)
        exitCode = $?
        return (exitCode == 0) ? true : false
      rescue
        raise "\n\nERROR: can't execute sub-processes??? (BRL::Util.Util#Bzip.isBzippedFile?)\n\n"
      end
    end

  end  # module Bzip2

  module Gzip

    GZIP_EXE = 'gzip -t '
    GZIP_INFO = 'gzip -l'
    GZIP_INFO_RE = /\s*compressed\s*uncompressed\s*ratio\s*uncomp\S+\s*\r?\n\s*(\d+)\s*(\d+)\s*([0-9\.]+)\%\s*(\S+)/

    def Gzip.isGzippedFile?(fileStr)
      fullFilePath = File.expand_path(fileStr)
      return false if((!fullFilePath.kind_of?(String)) or !FileTest.exists?(fullFilePath) or !FileTest.readable?(fullFilePath))
      fullFilePath.gsub!(/\"/, '\\"')
      cmdStr1 = "#{BRL::Util::Gzip::GZIP_EXE} \"#{fullFilePath}\" > /dev/null 2> /dev/null "
      begin
        system(cmdStr1)
        exitCode = $?
        return (exitCode == 0) ? true : false
      rescue Exception => err
        raise "\n\nERROR: can't execute sub-process '#{BRL::Util::Gzip::GZIP_EXE}' (BRL::Util.Util#Gzip.isGzippedFile?)\nBACKTRACE:#{err.message}\n" + err.backtrace.join("\n") + "\n\n"
      end
    end

    def Gzip.getInfo(fileStr)
      fullFilePath = File.expand_path(fileStr)
      return nil if((!fileStr.kind_of?(String)) or !FileTest.exists?(fullFilePath) or !FileTest.readable?(fullFilePath))
      fullFilePath.gsub!(/\"/, '\\"')
      cmdStr = "#{BRL::Util::Gzip::GZIP_INFO} \"#{fullFilePath}\" "
      begin
        cmdOutput = `#{cmdStr}`
      rescue => err
        raise(SystemCallError, "\nERROR: 'gzip -l' doesn't work! do you have it installed and reachable from sh? Is your gzip up to date?\nThis command returned:]\n  #{cmdOutput}\nError details: #{err.message}\n" + err.backtrace.join("\n")) if(cmdOutput.nil? or cmdOutput.empty?)
        raise(SystemCallError, "\nERROR: '#{fileStr}' is not a valid gzipped file!") if(cmdOutput =~ /not in gzip format/)
      end
      if(cmdOutput =~ BRL::Util::Gzip::GZIP_INFO_RE)
        return [$1, $2, $3.to_f/100.0, $4]
      else
        raise(SystemCallError, "\nERROR: 'gzip -l' doesn't work! do you have it installed and reachable from sh? Is your gzip up to date?\nThis command returned:\n>>\n#{cmdOutput}\n<<")
      end
    end

    def Gzip.empty?(fileStr)
      fullFilePath = File.expand_path(fileStr)
      if((!fileStr.kind_of?(String)) or !FileTest.exists?(fullFilePath) or !FileTest.readable?(fullFilePath))
        raise(SystemCallError, "\nERROR: the file isn't the name of a gzippe file or the file doesn't exist or you don't have permission to read it!\n    Bad file: #{fileStr}\nBACKTRACE:#{err.message}\n" + err.backtrace.join("\n") + "")
      end
      testByte = nil
      begin
        # Try to read just 1 byte from gzip file
        # If fails, that's because the compressed file was empty!
        gzIo = Zlib::GzipReader.open(fullFilePath)
        testByte = gzIo.readchar
      rescue
      end
      return testByte.nil? # yes, compressed file was empty!
    end

    def Gzip.getCompressedSize(fileStr)
      return BRL::Util::Gzip::getInfo(fileStr)[0]
    end

    def Gzip.getUncompressedSize(fileStr)
      return BRL::Util::Gzip::getInfo(fileStr)[1]
    end

    def Gzip.getRatio(fileStr)
      return BRL::Util::Gzip::getInfo(fileStr)[2]
    end

    def Gzip.getFileName(fileStr)
      return BRL::Util::Gzip::getInfo(fileStr)[3]
    end
  end # module Gzip

  # Provide a wrapper around Open4::popen to print out the command, stdout, and stderr with the usual
  #   BRL logging utility, to ensure that processes do not hang due to unprocessed out or err,
  #   which may be the case with some commands, and to close file handles opened by popen
  # @param [String] cmd the command to run
  # @param [Fixnum] outBytes a bound on the amount of stdout to include in the log
  # @param [Fixnum] errBytes a bound on the amount of stderr to include in the log
  # @param [Boolean] log whether or not we should include outBytes and errBytes portion of their
  #   respective streams in the log
  # @return [Array]
  #   [Process::Status] a status object with helpful methods #pid and #exitstatus
  #   [String] stdout from the process
  #   [String] stderr from the process
  def self.popen4Wrapper(cmd, opts={})
    $stderr.debugPuts(__FILE__, __method__, "CMD", cmd)
    supOpts = { :outBytes => 256, :errBytes => 256, :log => true }
    opts = supOpts.merge(opts)
    pid = outStr = errStr = out = err = nil
    status = POpen4::popen4(cmd){|stdout, stderr, stdin, pid|
      stdin.close()
      out = ""; stdout.each{|line| out << line}
      err = ""; stderr.each{|line| err << line}
      outStr = out[0...opts[:outBytes]]
      errStr = err[0...opts[:errBytes]]
    }
    $stderr.debugPuts(__FILE__, __method__, "CMD-EXIT_CODE", "exitstatus=#{status.exitstatus}")
    $stderr.debugPuts(__FILE__, __method__, "CMD-OUT", outStr) if(!outStr.empty? and opts[:log])
    $stderr.debugPuts(__FILE__, __method__, "CMD-ERR", errStr) if(!errStr.empty? and opts[:log])
    return status, out, err
  end

  # Modify non-iterable values occuring anywhere recursively within obj by applying
  #   some function to it
  # @param [Hash, Array, Object] some object composed of things responding to :each_key or :each_index
  # @param [Proc] pp anonymous function to transform non-iterable
  # @param [Hash] params named keyword parameters:
  #   @param [Array<Symbol>] iterators list of functions that can be used to iterate
  #     through obj; must take a block with one argument which provides
  #     the association between the parent and child (e.g. a Hash has keys associating
  #     to values)
  #   @param [Boolean] mutate if true then update parent reference to child with result from pp
  # @param [Object] some self, child, grand child, etc. object of object
  # @param [Object] kk some pointer name from parent to object
  # @todo rename
  def self.dfs!(obj, pp, params={:iterators => [:each_key, :each_index], :mutate => true}, parent=nil, kk=nil)
    respToAny = false
    params[:iterators].each{|iter|
      if(obj.respond_to?(iter))
        respToAny = true
        parent = obj
        obj.send(iter) { |kk|
          obj2 = obj[kk]
          self.dfs!(obj2, pp, params, parent, kk)
        }
      end
    }
    if(!respToAny)
      if(!params[:mutate])
        # then we should not mutate, just call the proc
        pp.call(obj)
      elsif(!parent.nil? and parent.respond_to?(:[]=))
        # then we should mutate and we can do so
        parent[kk] = pp.call(obj)
      end
    end
    # @todo else obj may be a scalar and we should call proc on it?
    return nil
  end

  def self.dfs(obj, pp, params={:iterators=>[:each_key, :each_index]})
    self.dfs!(obj, pp, params.merge(:mutate => false))
  end

  # Define BRL::Util::KeyError for Hash to raise if key is missing
  class KeyError < RuntimeError
  end

end ; end # module BRL ; module Util

# ##############################################################################
# ADD TO EXISTING CLASSES/MODULES
# ##############################################################################

class Object
  def eputs(*args)
    eprint(*args)
    $stderr.print "\n"
    return
  end

  def eprint(*args)
    args.each { |arg| $stderr.print arg }
    return
  end

  def dputs(*args)
    if($DEBUG)
      eputs(*args)
    end
    return
  end

  def dprint(*args)
    if($DEBUG)
      eprint(*args)
    end
    return
  end

  def initAttributes(attrList)
    attrList.each { |attrSym|
      tmpSelfClass = class << self
                       self
                     end
      tmpSelfClass.module_eval { attr_accessor(attrSym) }
      self.send("#{attrSym}=", nil)
    }
    return
  end

  def getCallingMethodName(frame)
    methodName = '<unknown>'
    frame = frame + 1 # account for new frame introduced by calling this method
    frames = caller(frame)
    if(frames and !frames.empty?)
      callingFrame = frames.first
      if(callingFrame =~ /in\s+\`([^\`\']+)'?/)
        methodName = $1
      end
    end
    return methodName
  end

  ########################################################################
  # * *Function*: A deep copy mechanism.
  #
  # * *Usage*   : <tt>  deep_clone( [ ["a"], ["b", "c"]] )  </tt>
  # * *Args*    :
  #   - +Object+ -> The object to clone
  # * *Returns* :
  #   - +Object+ -> A clone of the given object.
  # * *Throws* :
  #   - +none+
  ########################################################################
  def deep_clone
      Marshal::load(Marshal.dump(self))
  end
end

class Symbol
  def <=>(otherSym)
    (retVal = (self.to_s.downcase <=> otherSym.to_s.downcase))
    (retVal = (self.to_s <=> otherSym.to_s)) if(retVal == 0)
    retVal
  end
end

class Struct
  # Converts the Struct instance to a hash of member=>value
  def to_h()
    retVal = {}
    self.members.each { |mem|
      retVal[mem] = self.send(mem)
    }
    return retVal
  end
  alias_method :'to_hash', :'to_h'

  # Clears all the defined members/fields of their values by assigning member to nil. Useful for reusing a single Struct instance.
  # @return [void]
  def clear()
    self.members.each { |member|
      self[member] = nil
    }
    return self
  end
end

# We'd like the options available in some Hash object we can query at any time
class GetoptLong
  def to_hash
    return @asHash if(self.instance_variables.include?("@asHash") and !@asHash.nil?)
    saveSettings()
    retHash = {}
    self.each { |optName, optValue|
      retHash[optName] = optValue
    }
    # Do url-unescaping if it looks like the value has at least one actual %-style url encoded value.
    retHash.each_key { |kk| retHash[kk] = CGI.unescape(retHash[kk]) if(retHash[kk] =~ /%[0-9a-fA-F][0-9a-fA-F]/) ; }
    restoreSettings()
    @asHash = retHash
    return retHash
  end

  def getMissingOptions(butRequired=true)
    retVal = []
    self.to_hash()
    self.getCanonicalNames().each { |optName|
      if(butRequired)
        retVal << optName if(!@asHash.key?(optName) and @argument_flags[optName] == REQUIRED_ARGUMENT)
      else # any missing
        retVal << optName unless(@asHash.key?(optName))
      end
    }
    return retVal
  end

  def getCanonicalNames()
    retVal = {}
    @canonical_names.each_value { |optName|  retVal[optName] = nil }
    return retVal.keys
  end

  def saveSettings()
    @old_canonical_names = @canonical_names unless(@canonical_names.nil?)
    @old_argument_flags = @argument_flags unless(@argument_flags.nil?)
    @old_non_option_arguments = @non_option_arguments unless(@non_option_arguments.nil?)
    @old_rest_singles = @rest_singles unless(@rest_singles.nil?)
    return
  end

  def restoreSettings()
    @canonical_names = @old_canonical_names unless(@old_canonical_names.nil?)
    @argument_flags = @old_argument_flags unless(@old_argument_flags.nil?)
    @non_option_arguments = @old_non_option_arguments unless(@old_non_option_arguments.nil?)
    @rest_singles = @old_rest_singles unless(@old_rest_singles.nil?)
    return
  end

end # class GetoptLong

# Add overlap detection and length/size to Range object
class Range
  def size
    self.last - self.first + (self.exclude_end?() ? 0 : 1)
  end

  def exclude_max?()
    if(exclude_end?())
      if(self.first < self.last)
        return true
      end
    end
    return false
  end

  def exclude_min?()
    if(exclude_end?())
      if(self.first > self.last)
        return true
      end
    end
    return false
  end

  def <=>(aRange)
    selfMin = (self.first < self.last ? self.first : self.last)
    arMin = (aRange.first < aRange.last ? aRange.first : aRange.last)
    selfMax = (self.first > self.last ? self.first : self.last)
    arMax = (aRange.first > aRange.last ? aRange.first : aRange.last)
    selfExclMax, arExclMax = self.exclude_max?(), aRange.exclude_max?()
    selfExclMin, arExclMin = self.exclude_min?(), aRange.exclude_min?()

    # Compare min sentinals
    retVal = selfMin <=> arMin
    # Resolve ties where exclude_mins differs
    if( retVal == 0 )
      if( selfExclMin and !arExclMin )
        retVal = 1
      elsif( !selfExclMin and arExclMin )
        retVal = -1
      end
    end
    # If *still* a tie, then min sentinals are equal and exclude_mins are same
    if( retVal == 0 )
      retVal = selfMax <=> arMax
      # Resolve ties where exlcude_max differs
      if(retVal == 0 )
        if( selfExclMax and !arExclMax )
          retVal = -1
        elsif( !selfExclMax and arExclMax )
          retVal = 1
        end
      end
    end
    return retVal
  end

  def contains?(aRange)
    raise(TypeError, "\nERROR: containsRange?() requires Range-like methods to be available: first(), last(), ===, exclude_end?") unless(aRange.respond_to?("===") and aRange.respond_to?("first") and aRange.respond_to?("last") and aRange.respond_to?("exclude_end?"))
    selfMin, arMin = (self.first < self.last ? self.first : self.last), (aRange.first < aRange.last ? aRange.first : aRange.last)
    selfMax, arMax = (self.first > self.last ? self.first : self.last), (aRange.first > aRange.last ? aRange.first : aRange.last)

    # Check smaller (min) end of aRange
    if( self.exclude_min?() )
      if( aRange.exclude_min?() )
        return false unless(arMin >= selfMin)
      else
        return false unless(arMin > selfMin)
      end
    else
      return false unless(arMin >= selfMin)
    end
    # Check larger (max) end of aRange
    if( self.exclude_max?() )
      if( aRange.exclude_max?() )
        return false unless(arMax <= selfMax)
      else
        return false unless(arMax < selfMax)
      end
    else
      return false unless(arMax <= selfMax)
    end
    # Must contain aRange
    return true
  end

  def within?(aRange)
    raise(TypeError, "\nERROR: argument must respond to contains?() and other range-like methods.") unless(aRange.respond_to?("===") and aRange.respond_to?("first") and aRange.respond_to?("last") and aRange.respond_to?("exclude_end?") and aRange.respond_to?('contains?') )
    return aRange.contains?(self)
  end

  def overlaps?(aRange)
    raise(TypeError, "\nERROR:rangesOverlap?() requires Range-like methods to be available: first(), last(), ===, exclude_end?") unless(aRange.respond_to?("===") and aRange.respond_to?("first") and aRange.respond_to?("last") and aRange.respond_to?("exclude_end?"))
    selfMin, arMin = (self.first < self.last ? self.first : self.last), (aRange.first < aRange.last ? aRange.first : aRange.last)
    selfMax, arMax = (self.first > self.last ? self.first : self.last), (aRange.first > aRange.last ? aRange.first : aRange.last)

    # Check smaller (min) end of aRange
    if( self.exclude_max?() )
      return false unless(arMin < selfMax)
    else
      return false unless(arMin <= selfMax)
    end
    # Check smaller (min) of self
    if( aRange.exclude_max?() )
      return false unless(selfMin < arMax)
    else
      return false unless(selfMin <= arMax)
    end
    # Must overlap
    return true
  end

  # Only works for methods seen so far
  alias_method :length, :size
  alias_method :containsRange?, :contains?
  alias_method :rangesOverlap?, :overlaps?
end # class Range

class Numeric
  def commify()
    return self.to_s.commify
  end
end

# Add NaN class variable to Float
class Float
  NaN = 0.0 / 0.0

  def to_noSciNotationStr()
    retVal = self.to_s
    if(retVal =~ /\.(\d+)e\-(\d+)/i) # then sci notation for small abs number
      mantissaSize = $1.size
      exponent = $2.to_i
      formatFieldSize = ( mantissaSize + exponent )
      retVal = ("%0.#{formatFieldSize}f" % self)
    elsif(retVal =~ /\.(\d+)e\+?(\d+)/i) # then sci notiation for large abs number
      mantissaSize = $1.size
      exponent = $2.to_i
      formatFieldSize = ( mantissaSize + exponent )
      retVal = ("%#{formatFieldSize}f" % self)
    end
    return retVal
  end
end

# Add machine-specific native Integer sizes (before Bignum gets involved)
class Fixnum
  MAX32 = 2**31 - 1
  MIN32 = -MAX32 - 1
  MAX64 = 2**63 - 1
  MIN64 = -MAX64 - 1
  N_BYTES_NATIVE =[42].pack('i').size
  N_BITS_NATIVE = N_BYTES_NATIVE * 8
  MAX_NATIVE = 2 ** (N_BITS_NATIVE - 1) - 1
  MIN_NATIVE = -MAX_NATIVE - 1
end

class Integer
  MAX32 = Fixnum::MAX32
  MIN32 = Fixnum::MIN32
  MAX64 = Fixnum::MAX64
  MIN64 = Fixnum::MIN64
  N_BYTES_NATIVE = Fixnum::N_BYTES_NATIVE
  N_BITS_NATIVE = Fixnum::N_BITS_NATIVE
  MAX_NATIVE = Fixnum::MAX_NATIVE
  MIN_NATIVE = Fixnum::MIN_NATIVE
end

# Add safeMkdir to Dir class
class Dir
  def Dir.safeMkdir(dirToMake)
    Dir.mkdir(dirToMake) unless(File.exist?(dirToMake))
  end

  def Dir.recursiveSafeMkdir(dirToMake)
    dirNodes = dirToMake.split('/')
    currDir = ''
    dirNodes.each {
      |dirNode|
      currDir << "#{dirNode}/"
      Dir.mkdir(currDir) unless(File.exist?(currDir))
    }
  end
end

class File
  # NFS-Safe flock()
  # By Matz, with small robustification by ARJ
  alias __flock flock
  def flock(cmdFlags)
    # We trying to block or what?
    icmd = ((cmdFlags & LOCK_NB) == LOCK_NB) ? Fcntl::F_SETLK : Fcntl::F_SETLKW
    type =
      case(cmdFlags & ~LOCK_NB)
        when LOCK_SH
          Fcntl::F_RDLCK
        when LOCK_EX
          Fcntl::F_WRLCK
        when LOCK_UN
          Fcntl::F_UNLCK
        else
          raise ArgumentError, cmd.to_s
      end
    flock = [type, 0, 0, 0, 0].pack("ssqqi")
    begin
      fcntl(icmd, flock)
    rescue Errno::EBADF => err
      raise ArgumentError, "this file is not open for writing. Cannot LOCK_EX files open for reading only.\n\n"
    end
  end

  # [+filePath+] full path to file to open
  # [+mode+] mode of the file to open with
  # [+returns+] fh: file handler
  def self.openWithLock(filePath, mode='a+')
    fh = File.open(filePath, mode)
    loop {
      gotLock = fh.getLock(1280, 2, true, false)
      if(gotLock)
        break
      else
        fh.close()
        fh = File.open(filePath, mode)
      end
    }
    return fh
  end

  def getLock(maxRetries=1280, retrySleep=2, addRandomExtra=true, blocking=true)
    retVal = false
    retryCount = 0
    loop {
      retryCount += 1
      begin
        flock(File::LOCK_EX | File::LOCK_NB)
        retVal = true
        break
      rescue Errno::EAGAIN => err   # This is ok, the resource is in use
        if(blocking == false)
          retVal = false
          break
        elsif(retryCount < maxRetries) # If haven't exhausted max retries:
          sleepSec = retrySleep * retryCount
          sleepSec += rand(sleepSec/2) if(addRandomExtra) # Adding a random extra amount reduces lock-step effects for 100s-1000s simultaneously launched processes vying for the same lock file
          sleep(sleepSec)
        else # Too long waiting to get a lock on this file, perhaps something wrong. Let caller decide.
          retVal = false
          break
        end
      end
    }
    return retVal
  end

  def releaseLock()
    flock(LOCK_UN) unless(self.closed?)
    return true
  end

  def self.makeSafeSymlink(path, destDir)
    retVal = path
    destDir = File.expand_path(destDir)
    # Create a safe basename for the file (which can be used in shell command prompt commands)
    basename = File.basename(path)
    safeBasename = basename.makeSafeStr(:ultra)
    # Did we actually change anything? If not, just return path.
    dirname = File.dirname(path)
    unless(dirname == destDir and basename == safeBasename)
      retVal = destFile = "#{destDir}/#{safeBasename}"
      ii = 6
      loop {
        # avoid existing dest symlink with same name using digest
        uniqDestFile = (destFile + "_#{basename.xorDigest(ii)}")
        ok = File.symlink(File.expand_path(path), uniqDestFile) rescue false
        if(ok)
          puts ok.inspect
          retVal = uniqDestFile
          break
        else
          ii += 1
        end
      }
    end
    return retVal
  end

  def self.makeSafePath(path,mode=nil)
    retVal = ''
    if(path)
      if(mode == :underscore)
        retVal = path.split(/\//).map{|xx| xx.gsub(/[+&()`'\^:"?$%\|_]+/,"_")}.join("/")
      elsif(mode == :ultra)
        retVal = path.split(/\//).map{|xx| xx.makeSafeStr(:ultra)}.join("/")
      else
        retVal = path.split(/\//).map{|xx| CGI.escape(xx)}.join("/")
      end
    end
    return retVal
  end

  def self.md5Shorten(name, maxSize=200)
      if (name.size >= maxSize) then
        return "#{name[0,maxSize-32]}#{Digest::MD5.hexdigest(name)}"
      else
        return name
      end
  end
end

class Time
  # ------------------------------------------------------------------
  # CONSTANTS
  # ------------------------------------------------------------------
  DAY_SECS  = (24 * 60 * 60)
  WEEK_SECS = (7 * DAY_SECS)

  # ------------------------------------------------------------------
  # INSTANCE METHODS
  # ------------------------------------------------------------------
  def to_rfc822()
    if(Time.instance_methods.include?('rfc822'))
      return self.rfc822()
    else
      return self.strftime("%a, %d %b %Y %H:%M:%S ") + sprintf("%+03i00", (self.utc_offset / 60 / 60))
    end
  end

  # Keep clock time the same but change time zone i.e. apply inverse utc offset to self
  # @param [String] tz time zone as from Time#zone
  # @return [Time] returns a new time object with the timezone set to the desired timezone
  def setTimezone(tz)
    tokens = self.to_a
    tokens[-1] = tz
    return (tz == "UTC") ? Time.utc(*tokens) : Time.local(*tokens)
  end

  # 1.8.7 has no time initializer that respects both UTC and local times
  def self.gbMktime(*timeTokens)
    zoneIndex = 9
    tz = timeTokens[zoneIndex] rescue nil
    return (tz == "UTC") ? Time.utc(*timeTokens) : Time.local(*timeTokens)
  end
end

#class StringIO
#  def clear()
#    begin
#      self.close()
#      self.truncate(0)
#      self.rewind()
#    rescue => err
#      # no-op for failed clear
#    end
#    return self.size()
#  end
#end

class String
  @@globalSaltCounter = 0

  def commify()
    # To support floats and avoid weird things happening to decimal portion,
    # best to do from back to front...
    return self.reverse.gsub(/(\d{3,3})(?=\d)(?!\d*\.)/,'\1,').reverse
  end

  def toUnix()
    return self.gsub(/\r/, "\n").gsub(/[\n]{2,}/, "\n")
  end

  alias_method(:orig_ord, :ord) if(self.method_defined?(:ord))
  def ord(idx=0)
    haveOrd = self.respond_to?(:orig_ord)
    # Deal with 1.9 & default special (for speed)
    if(haveOrd and idx == 0)
      retVal = self.orig_ord()
    else # either no ord() and/or have idx!=0
      # (We could do this shorter, but it would make an unnessary call to this ord() method again.)
      valAtIdx = self[idx]
      retVal = (valAtIdx.is_a?(Fixnum) ? valAtIdx : valAtIdx.orig_ord) # Handle different returns for 1.8 vs 1.9
    end
    return retVal
  end

  alias_method(:orig_chr, :chr) if(self.method_defined?(:chr))
  def chr(idx=0)
    haveChr = self.respond_to?(:orig_chr)
    # Deal with 1.9 & default special (for speed)
    if(haveChr and idx == 0)
      retVal = self.orig_chr()
    else # either no ord() and/or have idx!=0
      # (We could do this shorter, but it would make an unnessary call to this ord() method again.)
      valAtIdx = self[idx]
      retVal = (valAtIdx.is_a?(Fixnum) ? valAtIdx.chr : valAtIdx) # Handle different returns for 1.8 vs 1.9
    end
    return retVal
  end

  def decapitalize()
    return self.gsub(/^(.)/) { |matchArray| matchArray.first.downcase }
  end

  def decapitalize!()
    return self.gsub!(/^(.)/) { |matchArray| matchArray.first.downcase }
  end

  ALPHABET_INTS_ONLY  = ('0'..'9').to_a
  ALPHABET_UPPER_ONLY = ('A'..'Z').to_a
  ALPHABET_LOWER_ONLY = ('a'..'z').to_a
  ALPHABET_LIMITED_SPECIAL_ONLY = %w(- _)
  def xorDigest(digestSize=8, alphabet=:full)
    alphabetChars = case alphabet
      when :full
        ALPHABET_UPPER_ONLY + ALPHABET_INTS_ONLY + ALPHABET_LIMITED_SPECIAL_ONLY + ALPHABET_LOWER_ONLY
      when :int
        ALPHABET_INTS_ONLY
      when :alpha
        ALPHABET_UPPER_ONLY + ALPHABET_LOWER_ONLY
      when :alphaNum
        ALPHABET_UPPER_ONLY + ALPHABET_INTS_ONLY + ALPHABET_LOWER_ONLY
      when :alphaLower
        ALPHABET_LOWER_ONLY
      when :alphaUpper
        ALPHABET_UPPER_ONLY
    end
    alphaBase = alphabetChars.size
    result = Array.new(digestSize)
    result.fill('0')
    self.size.times { |ii|
      rIdx = ii % digestSize
      currValue = result[rIdx].ord
      xorValue = (currValue ^ self.ord(ii))
      alphaIdx = (xorValue % alphaBase)
      result[rIdx] = alphabetChars[alphaIdx]
    }
    return result.join('')
  end

  def self.generateUniqueString(salt='')
    retVal = "#{$$}#{salt}#{@@globalSaltCounter+=1}#{Time.now.to_f}#{rand(64*1024*1024)}"
    SHA1.hexdigest(retVal)
  end

  def generateUniqueString(salt=self)
    return self.class.generateUniqueString(salt)
  end

  # Conservatively escape a string for use on command-line
  def self.makeSafeStr(str, mode=:ultra)
    retVal = str.to_s
    if(retVal)
      retVal = CGI.escape(retVal)
      if(mode==:ultra)
        retVal = retVal.gsub(/(?:%[a-f0-9]{2,2})+/i, "_")
      end
    end
    return retVal
  end

  def makeSafeStr(mode=:ultra)
    return self.class.makeSafeStr(self, mode)
  end

  # Check/validate self looks like a certain kind of String .
  # @param [Symbol] type The type of String to validate. :float, :int, :posInt,
  #   :negInt, :boolean, :enhancedBoolean, :symbol
  # @param [Boolean] allowPadding Indicating whether to allow whitespace padding
  #   on the ends of the string. It will be stripped off prior to detection. If @false@
  #   then a more stringent check is done which doesn't allow any whitespace padding.
  # @return [Boolean] indicating whether the string contains a valid representation of @type@.
  def valid?(type, allowPadding=true)
    testStr = (allowPadding ? self.strip : self)
    retVal = case type
      when :negInt
        testStr =~ /^-\d+$/
      when :posInt
        testStr =~ /^\+?\d+$/
      when :int
        testStr =~ /^(?:\+|\-)?\d+$/
      when :float
        # Handle 66. nicely (as 66) but reject 66.e-7...which to_f will get wrong
        testStr = testStr.chomp('.')
        testStr =~ /^(?:-|\+)?[0-9]*\.?[0-9]+(e(?:-|\+)?[0-9]+)?$/i
      when :boolean
        testStr =~ /^(?:true|false)$/i
      when :enhancedBoolean
        testStr =~ /^(?:yes|true|no|false)$/i
      when :symbol
        testStr =~ /^:\w+$/
      else
        raise "ERROR: Bug: #{type.inspect} is not a known validation type."
    end
    retVal = (retVal ? true : false)
  end

  # Attempt to best-guess cast this String to some other type of object like
  #   {Fixnum}, {Float}, {Boolean}, {Symbol} etc. Uses a best-guess approach...
  # @param [Boolean] allowEnhancedBoolean Indicating whether all of true, false, yes, no
  #   should be converted to respective boolean values (@true@ or @false@) or only
  #   true and false. Allowing this is useful for USER provided data but generally NOT
  #   for formal language data like JSON or something.
  # @return [Object] the result of the casting or a duplicate of this String
  #   object if no cast done.
  def autoCast(allowEnhancedBoolean=false)
    retVal = self.dup
    if(self.valid?(:int))
      retVal = self.to_i
    elsif(self.valid?(:float))
      retVal = self.to_f
    elsif(allowEnhancedBoolean and self.valid?(:enhancedBoolean))
      retVal = (self.strip =~ /^(?:true|yes)$/i ? true : false)
    elsif(self.valid?(:boolean))
      retVal = (self.strip =~ /^true$/i ? true : false)
    elsif(self.valid?(:symbol))
      self =~ /^:(\w+)$/
      retVal = $1.to_sym
    end
    return retVal
  end

  # Convert String to boolean: If string is a recognized "true" synonym, return true;
  #   otherwise, return false
  # @param [Boolean] forceCast if false will not cast self to a boolean
  def to_bool(forceCast=true)
    retVal = nil
    if(!forceCast)
      if(self.valid?(:enhancedBoolean))
        if(self.strip =~ /^(?:true|yes)$/i)
          retVal = true
        end
        if(self.strip =~ /^(?:false|no)$/i)
          retVal = false
        end
      else
        retVal = self
      end
    else
      retVal = (self.valid?(:enhancedBoolean) and self.strip =~ /^(?:true|yes)$/i ? true : false)
    end
    return retVal
  end

  def self.fillTemplate(str, varMap)
    filledStr = str.dup
    unless(varMap.nil? or varMap.empty?)
      varMap.each_key { |variable|
        varValue = varMap[variable]
        # Do any convenience preprossing for known types
        newVarValue = ''
        if(varValue.is_a?(Array))
          varValue.each_index { |ii|
            val = varValue[ii]
            newVarValue << CGI.escape(val)
            newVarValue << ',' unless(ii >= (varValue.size - 1))
          }
          varValue = newVarValue
        else
          varValue = CGI.escape(varValue)
        end
        # Note: the code below should allow users to use +Symbols+ or +Strings+
        # as their URL template variable names.
        filledStr.gsub!(%r@\{#{variable.to_s}\}@, varValue)
      }
    end
    return filledStr
  end

  def fillTemplate(varMap)
    return self.class.fillTemplate(self, varMap)
  end

  # Commonly used sorting function for human (not ascii!) sort order
  def self.ignoreCaseSort(sortable)
    sortable.sort{|xx, yy|
      retVal = xx.downcase <=> yy.downcase
      retVal = xx <=> yy if(retVal == 0)
      retVal
    }
  end

  ########################################################################
  # * *Function*: A fuzzy matching mechanism (still a bit rough)
  #
  # * *Usage*   : <tt>  "Alexsander".fuzzy_match( "Aleksander" )  </tt>
  # * *Args*    :
  #   - +str_in+ -> The string to compare against
  # * *Returns* :
  #   - +score+ -> A score from 0-1, based on the number of shared edges (matches of a sequence of characters of length 2 or more)
  # * *Throws* :
  #   - +none+
  ########################################################################
  def fuzzy_match( str_in )
  # The way this works:
  #   Converts each string into a "graph like" object, with edges
  #       "alexsander" - > [ alexsander, alexsand, alexsan ... lexsand ... san ... an, etc ]
  #       "aleksander" - > [ aleksander, aleksand ... etc. ]
  #   Perform match, then remove any subsets from this matched set (i.e. a hit on "san" is a subset of a hit on "sander")
  #       Above example, once reduced -> [ ale, sander ]
  #   See's how many of the matches remain, and calculates a score based
  #   On how many matches, their length, and compare to the length of the larger of the two words
    return 0 if str_in == nil
    return 1 if self == str_in
    # Make a graph of each word (okay, so its not a true graph, but is similar
    graph_A = Array.new
    graph_B = Array.new

    # "graph" self
    last = self.length
    (0..last).each{ |ff|
        loc  = self.length
        break if ff == last - 1
        wordB = (1..(last-1)).to_a.reverse!
        wordB.each{ |ss|
            break if ss == ff
            graph_A.push( "#{self[ff..ss]}" )
        }
    }

    # "graph" input string
    last = str_in.length
    (0..last).each{ |ff|
        loc  = str_in.length
        break if ff == last - 1
        wordB = (1..(last-1)).to_a.reverse!
        wordB.each{ |ss|
            break if ss == ff
            graph_B.push( "#{str_in[ff..ss]}" )
        }
    }

    # count how many of these "graph edges" we have that are the same
    matches = Array.new
    graph_A.each{ |aa|
        matches.push( aa ) if( graph_B.include?( aa ) )
    }

    matches.sort!{ |x,y| x.length <=> y.length }  # For eliminating subsets, we want to start with the smallest hits

    # eliminate any subsets
    mclone = matches.dup
    mclone.each_index { |ii|
        reg = Regexp.compile( mclone[ii] )
        count = 0.0
        matches.each{ |xx|
            count += 1 if xx =~ reg
        }
        matches.delete(mclone[ii]) if count > 1
    }

    score = 0.0
    matches.each{ |mm| score += mm.length }

    self.length > str_in.length ? largest = self.length : largest = str_in.length
    return score/largest
  end
end

class Array
  def lastIndex()
    return nil if self.empty?
    return (self.size-1)
  end

  def uniq_by
    hash, array = {}, []
    each { |i| hash[yield(i)] ||= (array << i) }
    array
  end
end # class Array

class Hash
  def to_h()
    self
  end

  # Get a nested hash attribute specified by dot-delimited string
  # @param [Object] hh the hash-like object (must respond to :[])
  # @param [String] path specify a nested hash key with a string delimited by delim
  # @param [String] delim delimiter of path
  # @return [NilClass, Object] nil if property given by path cannot be found,
  #   otherwise, the object specified by that path
  # @note path may also include array indexes
  def self.getNestedAttr(hh, path, delim=".")
    tokens = path.split(delim)
    obj = hh
    tokens.each { |token|
      obj = obj[token] rescue nil
      break if(obj.nil?)
    }
    return obj
  end

  # @see self.getNestedAttr
  def getNestedAttr(path, delim=".")
    self.class.getNestedAttr(self, path, delim)
  end

  # Rather than retreiving as in getNestedAttr, update the parent and return the
  #   entire, updated object
  # @return [Hash] updated copy of hh or nil if failure
  # @see self.getNestedAttr
  def self.setNestedAttr(hh, path, value, delim=".")
    tokens = path.split(delim)
    hh = hh.deep_clone
    obj = hh
    tokens[0..-2].each { |token|
      obj = obj[token] rescue nil
      break if(obj.nil?)
    }

    # at termination, obj is parent
    rv = nil
    if(obj.respond_to?(:[]))
      obj[tokens[-1]] = value
      rv = hh
    else
      rv = nil
    end
    return rv
  end

  def setNestedAttr(path, value, delim=".")
    self.class.setNestedAttr(self, path, value, delim)
  end

  # With non-unique values Hash#invert will keep only the last avp it visits, instead we
  #   collect the keys of duplicate values into an array
  # @return [Hash<Object, Array<Object>>] the inverted hash
  # @note we keep singleton array values for uniformity
  def invertDups()
    inverted = Hash.new { |hh, kk| hh[kk] = [] }
    self.each_key { |kk|
      vv = self[kk]
      inverted[vv].push(kk)
    }
    return inverted
  end

  # Performs a recursive Hash merge or "deep merge". The Ruby Hash {#merge} just does a shallow
  #   non-recursive merge. If the value a given key is a @Hash@ in both @self@ and the argument
  #   Hash, the new value will be the #{deepMerge} of those two Hashes. Otherwise, the new value
  #   for a given key will be the value in the argument Hash *if* it has that key.
  # @param [Hash] otherHash The Hash to merge into this one. Key-values from this argument Hash will
  #   replace existing key-values.
  # @return [Hash] A new Hash resulting from the deep-merge
  def deepMerge(otherHash)
    retVal = self.dup
    otherHash.each_key { |kk|
      newVal  = otherHash[kk]
      myVal   = retVal[kk]
      if(myVal.is_a?(Hash) and newVal.is_a?(Hash))
        retVal[kk] = myVal.deepMerge(newVal)
      else
        retVal[kk] = newVal
      end
    }
    return retVal
  end

  # @return [Boolean] true if self contains all keys in reqKeys
  def keys?(reqKeys)
    hasKeys = true
    key = nil
    reqKeys.each { |key|
      unless(self.key?(key))
        hasKeys = false
        break
      end
    }
    return hasKeys
  end

  # @param [Hash] hh
  # @param [Object] reqKeys keys that must appear in self
  # @raise BRL::Util::KeyError if self does not contain a key in reqKeys
  def self.errIfMissingKey(hh, reqKeys)
    raise BRL::Util::KeyError.new("First argument hh is not a hash") unless(hh.is_a?(Hash))
    hasKeys = true
    key = nil
    reqKeys.each { |key|
      unless(hh.key?(key))
        hasKeys = false
        break
      end
    }
    raise BRL::Util::KeyError.new("Missing key #{key.inspect}") unless(hasKeys)
  end
end # class Hash

# Read data from the IO (socket, stream, whatever) as it comes in.
# - Why not use read(length)?
#   . When you call IO#read(length) it will block until either the socket
#     is closed from the other side or it has read length bytes from the socket.
#   . In some cases this is ok, but a lot of the time it�s not what you want; for
#     example, what if MOST of length bytes comes right away, but then the last
#     of length bytes comes 5 minutes later? Then IO#read takes ~5 minutes! Why
#     can't we just have MOST of the bytes now? We can, with readpartial.
#   . readpartial will return immediately with whatever data is available.
#     If there is no data available it will wait until any amount of data becomes
#     available and return it immediately.
#   . Thing is, when readpartial notices the stream is closed, it raises an EOFError.
# The liveRead + readpartial_rescue below hide that little weirdness.
class IO
  def liveRead(data=nil, buffSize=4096)
    while(buff = self.readpartial_rescued(buffSize))
      data << buff if(data)
      yield buff if(block_given?)
    end
    data
  end

  def readpartial_rescued(size)
    readpartial(size)
  rescue EOFError
    nil
  end

  # IO knows about a file descriptor, but not necessarily the filepath, ask the OS
  def path
    File.readlink("/proc/self/fd/#{self.fileno}") rescue nil
  end

  def debugPuts(file, method, tag="DEBUG", msg="<Dev didn't put a msg :( >")
    file = "<Unknown File?>" unless(file)
    # Certain Ruby 1.8.7 patchlevels have a bug where the __method__ variable is not properly defined
    # for in a class context (especially in a "class << self" context) but it IS a "true" value just not usable.
    # We will try to compensate automatically for this:
    begin # test
      tmp = "#{method}"
      method = "<Outside of a Method>" unless(method)
    rescue Exception => err
      method = "<Outside of a Method>"
    end
    now = Time.now.strftime("[%d %b %Y %H:%M:%S]")
    memStr = BRL::Util::MemoryInfo.getMemUsageStr()
    self.puts "#{now} [#{memStr}] #{File.basename(file)}:#{method}() -> #{tag.upcase}: #{msg}"
    self.flush() if(self.respond_to?(:flush))
  end
end

module URI
  def findDiffComponents(otherUri, components=component())
    diffComps = []
    components.each { |cc| diffComps << cc if(self.send(cc).to_s != otherUri.send(cc).to_s) ; }
    return diffComps
  end

  def equivalent?(otherUri, bases=[:scheme, :userinfo, :host, :port, :path])
    return (self.findDiffComponents(otherUri, bases).size <= 0)
  end
end

class CGI
  class << self
    # TODO: have these response headers printed when (if, given erubis) result printed
    attr_reader :respHeaders

    alias :escape_orig :escape unless(method_defined?(:escape_orig))
    def escape(string)
      retVal = CGI::escape_orig(string.to_s)
      retVal.gsub!(/\+/, '%20')
      return retVal
    end

    alias :escapeHTML_orig :escapeHTML unless(method_defined?(:escapeHTML_orig))
    def escapeHTML(arg)
      return escapeHTML_orig(arg.to_s) # Protection again original not handling nil values
    end

    def setRespHeader(hdrKey, hdrVal)
      unless(hdrKey.nil? or hdrKey.empty?)
        hdrVal = '' if(hdrVal.nil?)
        @respHeaders = {} if(@respHeader.nil?)
        @respHeaders[hdrKey] = hdrVal
      end
    end

    def stripHtml(str)
      return str.gsub(/<\/?[^>]*>/, '')
    end
  end
end

class Net::FTP
  # This is a solid and highly portable test compatible with many FTP
  # servers, including crappy Windows ones with non-Unix type dir/ls output
  # (which is easier/faster to use for finding directories).
  #
  # It tries to chdir to path and captures the exception throw in path is
  # actually a file. This means it will follow symlinks.
  #
  # It is slow, so code doing recursion or processing all entries in a
  # directory should probably *try* to use lsRecLooksLike(lsStrRec)
  # on all the entries within the dir first, rather than calling this on each
  # entry. Unfortunately, we can't do a sort of "ls -d" on a path via ftp...ls gives
  # the *contents* of dir, never the dir.
  def directory?(path)
    retVal = false
    begin
      self.chdir(path)  # Throws Net::FTPPermError ("550 Failed to change directory") exception if not actually a dir.
      self.chdir('..')  # Chdir succeeded, so restore current directory
      retVal = true
    rescue
      retVal = true
    end
    return retVal
  end

  def file?(path)
    return !directory?(path)
  end

  # lsStrRec *must* be the UNIX-like string record for the listing of a specific file/dir/link.
  # - Generally you get this from MOST ftp servers via "ls" and its alias "dir".
  # - ("nlst" gives just the names) not full ls record
  # - Windows servers or other crappy ftp implementations may not should the entry type & permissions
  # - Records expected to look vaguely like this:
  #
  #      drwxr-s---    5 ftp      ftp          4096 Dec 13  2011 HGSC-NCI
  #      -rw-r-----    1 ftp      ftp           365 Jun 03  2010 README
  #      lrwxrwxrwx    1 ftp      ftp            11 Jun 12 16:52 Current-Release -> ./Release-7
  #
  # Will return one of: :dir, :file, :link. Defaults to :file, including when the lsStrRec doesn't have required type/perm info
  def lsRecLooksLike(lsStrRec)
    retVal = :file
    lsStrRec = lsStrRec.strip
    if(lsStrRec =~ /^d/)
      retVal = :dir
    elsif(lsStrRec =~ /^l/)
      retVal = :link
    end
    return retVal
  end

  # Recurses over all entries in path, calling the block on each entry.
  # Will be a naive depth-first-search. The implementation is stack-based not actual recursion.
  # - The |entry| variable will be the basename of entry.
  # - Recall that the current working directory during the recursion will
  #   be available via pwd()
  # - Implemented with a stack of entries, rather than actual recursive calls to self
  #   so this uses some memory rather than calls.
  # - More memory: also keeps track of dirs that have been visited so that we don't return to them
  #   again via symlinks (best if server yields *true* path for PWD rather than synlink based paths)
  #
  # Yields to the callback an FtpEntry struct--the same instance is used over and over for efficiency--
  # containing the full path to the entry (ftpEntry.path), a string containing the ls record details
  # (ftpEntry.lsStrRec), and the entry type (ftpEntry.type, which is one of :dir, :file, :link)
  FtpEntry = Struct.new(:path, :lsStrRec, :type)
  # This sed internally for a ~Schwartzian transform to speed sorting
  FtpInternalFileRec = Struct.new(:strRec, :basename, :basenameLowerCase)
  def recurse(path, yieldEntryTypes={:dir => true, :file => true, :link => true}, followSymlinks=true)
    linkRemoveRE = /^(.+?)(?:\s*->\s*.+)?$/
    splitLsRecRE = /\s+/
    if(!block_given?)
      raise ArgumentError, "ERROR: must provide block."
    elsif(!self.directory?(path))
      raise ArgumentError, "ERROR: path argument must be a directory"
    else
      # So we can return to the current directory when done
      originalPwd = self.pwd
      self.chdir(path)
      # Other init
      seenDirs = {}
      ftpEntry = FtpEntry.new
      # Start off with visiting path.
      dirStack = [ path ]
      # Continue visiting entries in dirStack until it's empty (all visited)
      while(!dirStack.empty?)
        # Get next dir to visit and cd to it
        currDir = dirStack.pop
        self.chdir(currDir)
        pwd = self.pwd
        # pwd is now normalized to full physical path (even if path and/or currDir are relative, and
        # even if it involves a symlink). So we can use it to determine if we've seen it before (including throuhg alternative symlink route)
        # So now check if we want to process pwd's entries or not
        unless(seenDirs.key?(pwd))
          seenDirs[pwd] = true
          # Get list of entries within currDir. Get both simple paths and lsStrRecs
          entries = self.nlst(currDir)
          lsStrRecs = self.list(currDir)
          raise "FATAL: Incompatible => The LIST and NLST commands are not returning the same number of entries from the server!??!!" unless(entries.size == lsStrRecs.size)
          # We can't rely on these two lists being sorted the same. So we need to sort them. Very expensive parsing and such
          # to do to each pair of records within the comparator (O(NlogN) transformations. So we'll make the comparator a bit
          # cheaper by transforming the two files lists into FtpInternalFileRec objects and do O(N) transformations upfront
          entries.map! { |entry|
            entryBasename = File.basename(entry)
            retVal = FtpInternalFileRec.new(entry, entryBasename, entryBasename.downcase)
          }
          lsStrRecs.map! { |lsStrRec|
            # Remove any " -> {actual file}" suffix if present becase entry is a softlink
            lsStrRec =~ linkRemoveRE
            noLinkStrRec = $1
            # Parse rec to get at just the file name portion
            entryBasename = File.basename(noLinkStrRec.split(splitLsRecRE).last)
            retVal = FtpInternalFileRec.new(lsStrRec, entryBasename, entryBasename.downcase)
          }
          entries.sort! { |aa, bb|
            retVal = (aa.basenameLowerCase <=> bb.basenameLowerCase)
            retVal = (aa.basename <=> bb.basename) if(retVal == 0)
            retVal
          }
          lsStrRecs.sort! { |aa, bb|
            retVal = (aa.basenameLowerCase <=> bb.basenameLowerCase)
            retVal = (aa.basename <=> bb.basename) if(retVal == 0)
            retVal
          }
          # Process each entry, yielding its full path to given block
          entries.each_index { |ii|
            entry = entries[ii].strRec
            basename = File.basename(entry)
            lsStrRec = lsStrRecs[ii].strRec
            raise "FATAL: Incompatible => The LIST and NLST commands are returning entries in different orders from the server!??!!\n    PWD: #{pwd.inspect}\n    NLST NAME AT IDX #{ii}: #{basename.inspect}\n    LIST STR AT IDX #{ii}: #{lsStrRec.inspect}" unless(lsStrRec.index(basename))
            entryType = self.lsRecLooksLike(lsStrRec)
            fullEntryPath = "#{pwd}/#{basename}"
            # Is it a dir? If so, add it to the currDir stack
            dirStack.push(fullEntryPath) if(entryType == :dir)
            # Yield it to the callback block, if asked for
            ftpEntry.path, ftpEntry.lsStrRec, ftpEntry.type = fullEntryPath, lsStrRec, entryType
            yield(ftpEntry) if(yieldEntryTypes[entryType])
          }
        end
      end
    end
    # Cleanup & restore
    self.chdir(originalPwd)
    dirStack = seenDirs = nil
    return path
  end
end


module Erubis
  # Compatible namespacing important when in Erubis environment:
  module Basic ; end
  class Engine ; end
  class Basic::Engine < Engine ; end
  # Now extend Eruby class
  class Eruby < Basic::Engine
    def self.includeFile(fileName, context={})
      eruby = Erubis::Eruby.load_file(fileName)
      return eruby.evaluate(context)
    end
  end
end

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end
