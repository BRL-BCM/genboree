#!/usr/bin/env ruby

require 'brl/util/util'
require 'popen4'

module BRL; module Net

  # Provide functions for asking questions of machines on the (usually local) network
  class NetUtil

    attr_accessor :debug

    # @param [String] host the host to query; for use in scripts the user of this class
    #   must have SSH keys setup for this user@host or have a password provided in a dbrc file
    # @param [String] user the user to use for the query to host, @see host
    def initialize(host, user)
      @host = host
      @user = user
    end

    # Query a remote machine for its system time as the number of seconds since the epoch Jan 1 1970 00:00:00
    # @todo allow formatting of time string through opts parameter?
    # @param [Hash] opts options interface for future
    # @return [NilClass, Time] a time object for the remote system time or nil if the command failed
    def systemTime(opts={}) 
      # retVal will either be nil (if error occurs) or will be system time (in Time's easy-to-read format)
      retVal = nil
      # Construct command to send over SSH
      dateCmd = "date +%s"
      cmd = "ssh -o NumberOfPasswordPrompts=0 #{@user}@#{@host} \"#{dateCmd}\""
      # Send command using popen4Wrapper
      status, out, err = popen4Wrapper(cmd, false, false)
      # If command successful, then retVal is set to time (in Time's easy-to-read format). Otherwise, we print error
      if(status.exitstatus == 0)
        retVal = Time.at(out.to_i)
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not retrieve system time: #{err[0...500]}")
      end
      return retVal
    end

    # Method that tells us the local modification time(s) for given file paths 
    # @param [String or Array] paths file paths for which we are computing the local modification time(s)
    # @return [NilClass, Hash<String, Time>] hash which contains path keys associated with local modification times (Time objects), or nil if the command failed
    def modTime(paths)
      # retVal will either be nil (if error occurs) or will be a hash that holds paths (keys) associated with local modification times (Time objects)
      retVal = {}
      # If paths is a single path string, then we'll convert it to an array
      unless(paths.is_a?(Array))
        paths = [paths]
      end
      # Make paths safe
      safePaths = paths.map{|xx| Shellwords.escape(xx)}
      # Construct command to send over SSH
      statPrefix = "stat -c %Y"
      cmd = "ssh -o NumberOfPasswordPrompts=0 #{@user}@#{@host} #{statPrefix} \"#{safePaths.join(" ")}\""
      # Send command using popen4Wrapper
      status, out, err = popen4Wrapper(cmd, false, false)
      # If command successful, then we proceed - otherwise, we print error and set retVal to nil
      if(status.exitstatus == 0)
        # Grab modification times from output
        mtimes = out.split("\n")
        # If the total number of modification times does not match the total number of input paths, then we have a problem
        if(mtimes.size != paths.size)
          $stderr.debugPuts(__FILE__, __method__, "NET_UTIL", "number of modification times retrieved does not match the number of files sent")
          retVal = nil
        else
          # Traverse each path, grab its corresponding mtime, and then save the key-value pair in our retVal hash
          paths.each_index{|ii|
            path = paths[ii]
            mtime = mtimes[ii]
            retVal[path] = Time.at(mtime.to_i)
          } 
        end
      else
        $stderr.debugPuts(__FILE__, __method__, "ERROR", "Could not retrieve local modification times for given paths #{paths.inspect}: #{err[0...500]}")
        retVal = nil
      end
      return retVal
    end

    # Method that tells us the SHA1(s) for given file paths 
    # @param [String or Array] paths file paths for which we are computing the SHA1(s)
    # @return [NilClass, Hash<String, String>] hash which contains path keys associated with SHA1s, or nil if the command failed
    def computeSHA1(paths)
      # retVal will either be nil (if error occurs) or will be a hash that holds paths (keys) associated with SHA1s
      retVal = {}
      # If paths is a single path string, then we'll convert it to an array
      unless(paths.is_a?(Array))
        paths = [paths]
      end
      # Make paths safe
      safePaths = paths.map{|xx| Shellwords.escape(xx)}
      # Construct command to send over SSH
      sha1command = "sha1sum"
      cmd = "ssh -o NumberOfPasswordPrompts=0 #{@user}@#{@host} #{sha1command} \"#{safePaths.join(" ")}\""
      status, out, err = popen4Wrapper(cmd, false, false)
      # If command successful, then we proceed - otherwise, we print error and set retVal to nil
      if(status.exitstatus == 0)
        # Grab SHA1s
        sha1sums = out.split("\n")
        # If number of SHA1s doesn't match number of input paths, then we have a problem
        if(sha1sums.size != paths.size)
          $stderr.debugPuts(__FILE__, __method__, "NET_UTIL", "number of SHA1 sums retrieved does not match the number of files sent")
          retVal = nil
        else
          # Traverse each path, grab its corresponding SHA1, and then save the key-value pair in our retVal hash 
          paths.each_index{|ii|
            path = paths[ii]
            sha1sum = sha1sums[ii].split("  ")[0]
            retVal[path] = sha1sum
          }
        end
      else
        retVal = nil
      end
      return retVal
    end


    # Return a time offset in number of seconds from local time to utc time
    # @param [Hash] opts @todo for future use
    # @return [Integer] number of seconds system's local time is offset from utc time
    def timeZoneOffset(opts={})
      retVal = nil
      begin
        dateCmd = "date +%z"
        cmd = "ssh -o NumberOfPasswordPrompts=0 #{@user}@#{@host} \"#{dateCmd}\""
        status, out, err = popen4Wrapper(cmd, false, false)
        if(status.exitstatus == 0)
          out.gsub!("\n", "")
          if(out.size == 4)
            sign = 1
            hh, mm = out[0..1].to_i, out[2..3].to_i
            retVal = sign * (hh * 3600 + mm * 60)
          elsif(out.size == 5)
            sign = (out[0..0] == "+" ? 1 : -1)
            hh, mm = out[1..2].to_i, out[3..4].to_i
            retVal = sign * (hh * 3600 + mm * 60)
          else
            retVal = nil
          end
        else
          retVal = nil
        end
      rescue => err
        $stderr.debugPuts(__FILE__, __method__, "DEBUG", err.message) if(@debug)
        retVal = nil
      end
      return retVal
    end

    # ---------------------------------------------------------------
    # (non-explicitly) protected methods
    # ---------------------------------------------------------------

    # Provide a wrapper around Open4::popen to print out the command, stdout, and stderr with the usual
    #   BRL logging utility, to ensure that processes do not hang due to unprocessed out or err,
    #   which may be the case with some commands, and to close file handles opened by popen
    # @return [Array] 
    #   [Process::Status] a status object with helpful methods #pid and #exitstatus
    #   [String] stdout from the process
    #   [String] stderr from the process
    def popen4Wrapper(cmd, out=true, err=true)
      $stderr.debugPuts(__FILE__, __method__, "CMD", cmd) if(@debug)
      pid = outStr = errStr = nil
      status = POpen4::popen4(cmd){|stdout, stderr, stdin, pid|
        stdin.close()
        outStr = ""; stdout.each{|line| outStr << line}
        errStr = ""; stderr.each{|line| errStr << line}
        $stderr.debugPuts(__FILE__, __method__, "CMD-OUT", outStr[0...50]) if(out and @debug)
        $stderr.debugPuts(__FILE__, __method__, "CMD-ERR", errStr) if(err and @debug)
      }
      $stderr.debugPuts(__FILE__, __method__, "CMD-EXIT_CODE", "exitstatus=#{status.exitstatus}") if((out or err) and @debug)
      return status, outStr, errStr
    end

  end
end; end
