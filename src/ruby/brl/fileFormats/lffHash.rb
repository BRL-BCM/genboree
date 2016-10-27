require 'rein'
require 'interval'

# TODO: move to brl/fileFormats or something
class LFFHash < Rein::ObjectTemplate
  attr_accessor :lffClass, :lffType, :lffSubtype, :lffName
  attr_accessor :lffChr, :lffStart, :lffStop, :lffLength, :lffStrand
  attr_accessor :lffPhase, :lffScore, :lffQStart, :lffQStop
  attr_accessor :lffSeq, :lffFreeComments
  attr_accessor :asInterval
  
  # useful for Rein rule engine and others
  attr_accessor :passed, :rulesPassed
  
  def initialize(lffRec=nil, *args)
    @passed = 0
    @rulesPassed = {}
    if(lffRec.nil?)
      @lffClass, @lffType, @lffSubtype, @lffName, @lffChr, @lffStart, @lffStop, @lffLength, @lffStrand,
                 @lffPhase, @lffScore, @lffQStart, @lffQStop, @lffSeq, @lffFreeComments, @asInterval = nil
    elsif(lffRec.kind_of?(Array) or lffRec.kind_of?(String))
      aa = lffRec.split(/\t/) unless(lffRec.kind_of?(Array))
      unless(aa.length >= 10)
        raise ArgumentError, "ERROR: LFFHash#initialize(lffRec) => lffRec must be an lff annotation record of at least 10 fields as a string or an array"
      end
      aa.map!{|xx| xx.strip}
      @lffClass = aa[0].to_sym
      @lffType = aa[2].to_sym
      @lffSubtype = aa[3].to_sym
      @lffName = aa[1].to_sym
      @lffChr = aa[4].to_sym
      @lffStart = aa[5].to_i
      @lffStop = aa[6].to_i
      if(@lffStop < @lffStart)
        @lffStart, @lffStop = @lffStop, @lffStart
      end
      @lffLength = (@lffStop - @lffStart).abs + 1
      @lffStrand = aa[7].to_sym
      @lffPhase = ((aa[8] == '.' or aa[8] == '') ? nil : aa[8])
      @lffScore = aa[9].to_f
      @lffQStart = ((aa[10].nil? or aa[10] == '.' or aa[10] == '') ? nil : aa[10].to_i)
      @lffQStop = ((aa[11].nil? or aa[11] == '.' or aa[11] == '') ? nil : aa[11].to_i)
      @lffSeq = ((aa[13].nil? or aa[13] == '.' or aa[13] == '') ? nil : aa[13])
      @lffFreeComments = ((aa[14].nil? or aa[14] == '.' or aa[14] == '') ? nil : aa[14])
      
      # Do AVPs as hash keys=values, where keys are attributes as symbols
      unless(aa[12].nil? or aa[12].empty?)
        aa[12].scan(/[^=;]+=[^;]*;?/) { |avp|
          avp.strip!
          avp =~ /^([^=;]+)=([^;]*)/
          if(!$2.nil? and !$2.empty?)
            attr, val = $1.strip, $2.strip
          else
            attr, val = $1.strip, :AttributePresentButBlank
          end
          self[attr.to_sym] = val.to_sym 
        }
      end
    else
      raise ArgumentError, "LFFHash.new(...) first argument must be String, Array, or nil. Not this:  #{lffRec.inspect}"
    end   
    super(*args) # For hash stuff to be passed along
  end
  
  def replace(lffRec)
    @passed = 0
    @rulesPassed = {}
    self.update(lffRec)
    return self
  end
  
  def update(lffRec)
    self.clear()
    if(lffRec.nil?)
      @lffClass, @lffType, @lffSubtype, @lffName, @lffChr, @lffStart, @lffStop, @lffLength, @lffStrand,
                 @lffPhase, @lffScore, @lffQStart, @lffQStop, @lffSeq, @lffFreeComments = nil
    elsif(lffRec.kind_of?(Array) or lffRec.kind_of?(String))
      aa = lffRec.split(/\t/) unless(lffRec.kind_of?(Array))
      unless(aa.length >= 10)
        raise ArgumentError, "ERROR: LFFHash#update(lffRec) => lffRec must be an lff annotation record of at least 10 fields as a string or an array"
      end
      aa.map!{|xx| xx.strip}
      @lffClass = aa[0].to_sym
      @lffType = aa[2].to_sym
      @lffSubtype = aa[3].to_sym
      @lffName = aa[1].to_sym
      @lffChr = aa[4].to_sym
      @lffStart = aa[5].to_i
      @lffStop = aa[6].to_i
      if(@lffStop < @lffStart)
        @lffStart, @lffStop = @lffStop, @lffStart
      end
      @lffLength = (@lffStop - @lffStart).abs + 1
      @lffStrand = aa[7].to_sym
      @lffPhase = ((aa[8] == '.' or aa[8] == '') ? 0 : aa[8])
      @lffScore = aa[9].to_f
      @lffQStart = ((aa[10].nil? or aa[10] == '.' or aa[10] == '') ? nil : aa[10].to_i)
      @lffQStop = ((aa[11].nil? or aa[11] == '.' or aa[11] == '') ? nil : aa[11].to_i)
      @lffSeq = ((aa[13].nil? or aa[13] == '.' or aa[13] == '') ? nil : aa[13])
      @lffFreeComments = ((aa[14].nil? or aa[14] == '.' or aa[14] == '') ? nil : aa[14])
      
      # Do AVPs as hash keys=values, where keys are attributes as symbols
      unless(aa[12].nil? or aa[12].empty?)
        aa[12].scan(/[^=;]+=[^;]*;?/) { |avp|
          avp.strip!
          avp =~ /^([^=;]+)=([^;]*)/
          if(!$2.nil? and !$2.empty?)
            attr, val = $1.strip, $2.strip
          else
            attr, val = $1.strip, :AttributePresentButBlank
          end
          self[attr.to_sym] = val.to_sym
        }
      end
    else
      raise ArgumentError, "LFFHash.update(...) argument must be String, Array, or nil. Not this:  #{lffRec.inspect}"
    end   
    return self
  end
  
  def inspect()
    baseStr = super()
    extraStr =  "@lffClass=#{@lffClass.inspect}, " +
                "@lffName=#{@lffName.inspect}, " +
                "@lffType=#{@lffType.inspect}, " +
                "@lffSubtype=#{@lffSubtype.inspect}, " +
                "@lffChr=#{@lffChr.inspect}, " +
                "@lffStart=#{@lffStart.inspect}, " +
                "@lffStop=#{@lffStop.inspect}, " +
                "@lffLength=#{@lffLength.inspect}, " +
                "@lffStrand=#{@lffStrand.inspect}, " +
                "@lffPhase=#{@lffPhase.inspect}, " +
                "@lffScore=#{@lffScore.inspect}, " +
                "@lffQStart=#{@lffQStart.inspect}, " +
                "@lffQStop=#{@lffQStop.inspect}, " +
                "@lffSeq=#{@lffSeq.inspect}, " +
                "@lffFreeComments=#{@lffFreeComments.inspect}, "
   baseStr.gsub(/\{/, "{#{extraStr}")
  end
  
  def to_s()
    baseStr = super()
    extraStr =  "@lffClass=#{@lffClass.inspect}, " +
                "@lffName=#{@lffName.inspect}, " +
                "@lffType=#{@lffType.inspect}, " +
                "@lffSubtype=#{@lffSubtype.inspect}, " +
                "@lffChr=#{@lffChr.inspect}, " +
                "@lffStart=#{@lffStart.inspect}, " +
                "@lffStop=#{@lffStop.inspect}, " +
                "@lffLength=#{@lffLength.inspect}, " +
                "@lffStrand=#{@lffStrand.inspect}, " +
                "@lffPhase=#{@lffPhase.inspect}, " +
                "@lffScore=#{@lffScore.inspect}, " +
                "@lffQStart=#{@lffQStart.inspect}, " +
                "@lffQStop=#{@lffQStop.inspect}, " +
                "@lffSeq=#{@lffSeq.inspect}, " +
                "@lffFreeComments=#{@lffFreeComments.inspect}, "
    baseStr + " " + extraStr
  end
  
  def to_lff()
    baseStr = "#{@lffClass}\t#{@lffName}\t#{@lffType}\t#{@lffSubtype}\t#{@lffChr}\t#{@lffStart}\t#{@lffStop}\t#{@lffStrand}\t" + 
              "#{(@lffPhase.to_s.empty? or @lffPhase.to_s=='.') ? 0 : @lffPhase}\t" +
              "#{@lffScore}\t" +
              "#{(@lffQStart.to_s.empty?) ? '.' : @lffQStart}\t" +
              "#{(@lffQStop.to_s.empty?) ? '.' : @lffQStop}\t"
    avpStr = ''
    self.keys.sort.each { |attr|
      if(self[attr] == :AttributePresentButBlank)
        avpStr += "#{attr}=; "
      else
        avpStr += "#{attr}=#{self[attr]}; "
      end
    }
    return baseStr + avpStr + "\t#{@lffSeq}\t#{@lffFreeComments}"
  end
  
  def to_interval(recalc=false)
    retVal = @asInterval
    if(recalc or retVal.nil?)
        retVal = @asInterval = Interval[@lffStart, @lffStop]
    end
    return retVal
  end
end
