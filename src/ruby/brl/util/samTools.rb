#!/usr/bin/env ruby
require 'brl/genboree/genboreeUtil'

module BRL ; module Util 

#############################################################################
# This class is used to run sam tools
#
# Usage:
# require 'brl/util/samTools'
# BRL::Util::SamTools.bam2sam("NA19143.SLX.MOSAIK.SRP000033.2009_11.bam", "NA19143.SLX.MOSAIK.SRP000033.2009_11.sam") # For converting bam to sam
# BRL::Util::SamTools.sam2bam("NA19143.SLX.MOSAIK.SRP000033.2009_11.sam", "NA19143.SLX.MOSAIK.SRP000033.2009_11_2.bam", sort=false) # For converting sam to bam (no sorting)
# BRL::Util::SamTools.sam2bam("NA19143.SLX.MOSAIK.SRP000033.2009_11.sam", "NA19143.SLX.MOSAIK.SRP000033.2009_11_2.bam", sort=true) # For converting sam to bam (with sorting)
# BRL::Util::SamTools.sortBam("NA19143.SLX.MOSAIK.SRP000033.2009_11_2.bam", fileBaseName=nil) # For just sorting bam file

# Notes:
# The sort method will automatically add .bam extension to 'fileBaseName'. If nil, .bam will be replaced by .sorted and then .bam suffix will be added
# So the sorted bam file for NA19143.SLX.MOSAIK.SRP000033.2009_11_2.bam will be NA19143.SLX.MOSAIK.SRP000033.2009_11_2.sorted.bam if fileBaseName=nil
#############################################################################
class SamTools

  MODULE_LOAD_CMD = "module load samtools;"
  
  
  # Converts bam file to sam file
  # [+bamFile+]
  # [+samFile+]
  def self.bam2sam(bamFile, samFile)
    begin
      raise "Input bam file: #{bamFile.inspect} does not have '.bam' suffix" if(bamFile !~ /\.bam$/i)
      cmd = "#{MODULE_LOAD_CMD} samtools view -h #{bamFile} > #{samFile}"
      exitStatus = system(cmd)
      @statusObj = $?.dup()
      if(!exitStatus)
        raise "Command: #{cmd.inspect} failed. \n ExitStatus: #{@statusObj.inspect}"
      end      
    rescue => err
      raise err
    end
  end
  
  # Converts sam file to bam file
  # [+samFile+]
  # [+bamFile+]
  def self.sam2bam(samFile, bamFile, sortBam=false)
    begin
      raise "Output bam file: #{bamFile.inspect} does not have '.bam' suffix" if(bamFile !~ /\.bam$/i)
      cmd = "#{MODULE_LOAD_CMD} samtools view -S -b #{samFile} > #{bamFile}"
      exitStatus = system(cmd)
      @statusObj = $?.dup()
      if(!exitStatus)
        raise "Command: #{cmd.inspect} failed. \n ExitStatus: #{@statusObj.inspect}"
      end
      self.sortBam(bamFile, nil) if(sortBam)
    rescue => err
      raise err
    end
  end
  
  # sorts bam file
  # if outputFileBase=nil, base on bamFile by stripping off ".bam" and then adding ".sorted"
  # [+bamFile+]
  # [+outputFileBase+]
  # [+returns+] sorted bam file
  def self.sortBam(bamFile, outputFileBase=nil)
    begin
      raise "bam file: #{bamFile.inspect} does not have '.bam' suffix" if(bamFile !~ /\.bam$/i)
      if(outputFileBase.nil?)
        bamBaseName = File.basename(bamFile)
        outputFileBase = bamBaseName.gsub(".bam", ".sorted")
      end
      cmd = "#{MODULE_LOAD_CMD} samtools sort #{bamFile} #{outputFileBase}"
      exitStatus = system(cmd)
      @statusObj = $?.dup()
      if(!exitStatus)
        raise "Command: #{cmd.inspect} failed. \n ExitStatus: #{@statusObj.inspect}"
      end
    rescue => err
      raise err
    end
  end
  
  # checks if input bam file is sorted
  # [+bamFile+]
  # [+returns+] true or false
  def self.isBamSorted?(bamFile)
    sorted = false
    begin
      raise "bam file: #{bamFile.inspect} does not have '.bam' suffix" if(bamFile !~ /\.bam$/i)
      cmd = "#{MODULE_LOAD_CMD} samtools view -H #{bamFile}"
      cmdOut = `#{cmd}`
      @statusObj = $?.dup()
      if(cmdOut.nil? or cmdOut.empty?)
        raise "Command: #{cmd.inspect} failed. \n ExitStatus: #{@statusObj.inspect}"
      end
      cmdOut.each_line { |line|
        line.strip!
        next if(line.nil? or line.empty? or line =~ /^\s*$/ or line =~ /^#/)
        if(line =~ /^@HD/ and line =~ /SO:coordinate/i)
          sorted = true
          break
        end
      }
    rescue => err
      raise err
    end
    return sorted
  end
  
  def self.generateIndex(bamFile)
    begin
      raise "Input bam file: #{bamFile.inspect} does not have '.bam' suffix" if(bamFile !~ /\.bam$/i)
      cmd = "#{MODULE_LOAD_CMD} samtools index #{bamFile}"
      exitStatus = system(cmd)
      @statusObj = $?.dup()
      if(!exitStatus)
        raise "Command: #{cmd.inspect} failed. \n ExitStatus: #{@statusObj.inspect}"
      end
    rescue => err
      raise err
    end
  end
  
end

end ; end
