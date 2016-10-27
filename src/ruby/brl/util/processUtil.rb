#!/usr/bin/env ruby

# ##############################################################################
# REQUIRED CLASSES/MODULES
# ##############################################################################

require 'brl/util/util'

module BRL ; module Util
  # This class provides useful process related utilities.
  # Currently, this class provides:
    # A method for grabbing specific information about ipc facilities like shared memory via process ID
    # A method for grabbing process ids of child processes via parent process ID
    # A method for removing shared memory segments via shared memory ID
  class ProcessUtil
    
    # Returns ipcs Shared Memory Creator/Last-op for a given pid
    # @param [String] pid process id we're checking
    # @return [String] ipcs output (empty string if none found)
    def self.ipcShmsByPid(pid)
      ipcsOutput = nil
      # Only first 10 characters of user name are displayed - have to search for those, since if user name is longer than 10 chars, search will fail!
      user = `echo $USER`.chomp
      user = user[0..9]
      ipcsOutput = `ipcs -pm | grep -P \"^\\S+\\s+#{user}\\s+#{pid}\"`
      #$stderr.debugPuts(__FILE__, __method__, "STATUS", "\n*******\n**********\nIPCS OUTPUT for #{pid}: \n#{ipcsOutput}\n*******\n**********\n")
      return ipcsOutput
    end

    # Returns info for a specific shmid (used largely to figure out whether a given shmid exists)
    # @param [String] shmid shared memory ID
    # @retunr [String] ipcs output (empty string if none found)
    def self.shmidExist?(shmid)
      ipcsOutput = nil
      # Only first 10 characters of user name are displayed - have to search for those, since if user name is longer than 10 chars, search will fail!
      user = `echo $USER`.chomp
      user = user[0..9]
      ipcsOutput = `ipcs -pm | grep -P \"^#{shmid}\\s+#{user}\"`
      return ipcsOutput
    end
    
    # Returns the child pids if a parent pid is given
    # @param [String] ppid parent pid
    # @return [Array] child pids (empty array if none found)
    def self.childPidByPpid(ppid)
      childPid = `ps o pid= --ppid #{ppid}`.split("\n").map! {|xx| xx.strip }      
      return childPid
    end

    # Removes a shared memory segment by its shared memory ID
    # @param [String] shmid shared memory ID
    # @return [nil]
    def self.removeShmByShmid(shmid)
      removedShmid = `ipcrm -m #{shmid}`
      return removedShmid
    end
  end
end; end