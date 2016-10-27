require 'brl/util/util'
require 'brl/net/netUtil'
require 'brl/genboree/genboreeUtil'
require 'brl/db/dbrc' #@todo remove
require 'brl/net/netUtil'
require 'brl/db/dbrc'
require 'popen4'

module BRL ; module Genboree ; module Pipeline ; module FTP ; module Helpers

# @note this class assumes that the (literal, linux) user of this library has
#   generated RSA keys for use with ssh using ssh-keygen and copied their public key
#   to the file storing authorized keys on the @host
class Rsync

  PREFIX = "/usr/local/brl/data/ftp/home"
  # shared areas are bind in /etc/fstab to user_area

  # changing user freely is dangerous due to path prefixing
  attr_reader :user

  attr_accessor :host
  attr_accessor :fileData
  attr_accessor :offset # time zone offset vs GMT/UTC e.g. -500 for CDT

  attr_accessor :debug

  def setOffset(offset=nil)
    @offset = nil
    if(offset.nil?)
      net = BRL::Net::NetUtil.new(@host, @remoteUser)
      @offset = net.timeZoneOffset
    else
      @offset = offset.to_f
    end
    return @offset
  end

  # @param [String] host OPTIONAL with config (use nil or "") the host name to pull from the dbrc and use for rsync
  # @param [String] user the user directory to use for rsync operations. NOTE
  #   this is NOT the same as the user used to perform the rsync command, which comes from dbrc
  # @param [NilClass] password DEPRECATED
  # @raise ArgumentError if no host is provided and none is set in the configuration file
  # @todo method signature needs to be updated
  def initialize(host=nil, user="clusterUser", password=nil)
    user = "clusterUser" if(user.nil? or user.empty?)
    genbConf = BRL::Genboree::GenboreeConfig.load()
    host = genbConf.send(:remotePollerHost) if(host.nil? or host.empty?)
    raise ArgumentError.new("host argument not provided and none is set in the configuration file!") if(host.nil? or host.empty?)
    @host = host
    @user = user

    @dbrc = BRL::DB::DBRC.new()
    dbrcRec = @dbrc.getRecordByHost(@host, :poller) # this is not safe to put in an instance variable!
    raise ArgumentError.new("unable to extract login information from dbrc for host #{@host.inspect} and record type #{:poller}") if(dbrcRec.nil?)
    # @todo password isnt used because ssh keys are assumed but it could be used with popen by detecting the password prompt
    # e.g. "user@host's password:", regexp matching on that, checking dbrc, and writing to stdin the pw from dbrc
    @remoteUser = dbrcRec[:user]

    if(@offset.nil?)
      setOffset()
    end

    @debug = false
    @fileData = {}
  end

  # Provide ls style output for a remote filepath via rsync 
  # @param [String] path the file path to execute ls on
  # @param [Array<String>] patterns list of Perl style regular expression strings to filter files with
  # @return [Array<String>] if path is a directory, a list of filenames in that directory, 
  #   otherwise an array containing path
  # @set @fileData, a Hash<String, Hash> with some more detailed information about the files
  # @see parseList for documentation on @fileData
  def ls(path, patterns=nil)
    retVal = nil
    fileData = nil
    prefixedPath = prefixPath(path)
    cmd = "rsync --list-only -R --no-implied-dirs #{@remoteUser}@#{@host}:\"#{Shellwords.escape(prefixedPath)}\""
    status, stdout, stderr = popen4Wrapper(cmd)
    fileData = parseList(stdout)
    @fileData.merge!(fileData)

    # rsync --list-only will only list the directory file and not its contents
    # but it includes an option to append terminal slash to path name to get contents
    dirStr = "d"
    if(fileData.keys.size == 1 and !fileData[prefixedPath].nil? and 
       fileData[prefixedPath][:permissions][0..0] == dirStr)
      # then get the directory contents instead of just ls -l output for only the directory file
      cmd += "/"
      status, stdout, stderr = popen4Wrapper(cmd)
      fileData = parseList(stdout)
      @fileData.merge!(fileData)
      fileData.delete(prefixedPath) # linux ls doesnt include directory in output
    end

    fullPaths = fileData.keys()
    if(!patterns.nil? and !patterns.empty? and patterns.respond_to?(:each))
      if(patterns.is_a?(String))
        patterns = [patterns]
      end
      matchingPaths = []
      fullPaths.each{|path|
        basename = File.basename(path)
        patterns.each{|pattern|
          regexp = Regexp.compile(pattern)
          matchData = regexp.match(basename)
          unless(matchData.nil?)
            matchingPaths.push(path) 
            break
          end
        }
      }
      fullPaths = matchingPaths
    end
    retVal = fullPaths.map{|path| relativePath(path)}
    return retVal
  end

  # Get file modification times for each filepath in paths
  # @param [Array<String>] paths the filepaths to get modification times for
  # @return [Hash<String, ::Time>] a mapping of a path in paths to its modification time
  #   as a Ruby Time object
  # @todo ls on path can fail then @fileData[path] is nil
  def mtimes(paths)
    if(@offset.nil?)
      raise ArgumentError, "offset is nil, cannot provide reliable modification times; try calling #setOffset"
    end
    retVal = {}
    # perhaps shorter paths are directories containing later paths, save requests
    paths = paths.sort{|aa, bb| (aa.respond_to?(:size) ? aa.size : 0) <=> (bb.respond_to?(:size) ? bb.size : 0)}
    paths.map!{|path| prefixedPath = prefixPath(path)}
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "paths=#{paths.inspect}") if(@debug)
    paths.each{|path|
      unless(@fileData.key?(path))
        ls(path)
      end
      dateTokens = @fileData[path][:modDate].split("/").map{|xx| xx.to_i}
      timeTokens = @fileData[path][:modTime].split(":").map{|xx| xx.to_i}
      retVal[relativePath(path)] = Time.utc(*(dateTokens + timeTokens)) + @offset
    }
    return retVal
  end

  # provide "mkdir -p"-like functionality since rsync cannot create arbitrary directories on 
  #   a remote server
  # @param [String] path the directory path to create
  # @return [nil, String] nil if failure, otherwise a String representing the directory created 
  def mkdir(path)
    reeVal = nil
    prefixedPath = prefixPath(path)
    cmd = "ssh #{@remoteUser}@#{@host} mkdir -p \"#{Shellwords.escape(prefixedPath)}\""
    status, stdout, stderr = popen4Wrapper(cmd)
    if(status.exitstatus == 0)
      retVal = relativePath(path)
    else
      retVal = nil
    end
    return retVal
  end 
  
  # Rename a remote file
  # @param [String] src the source filepath to move/rename from
  # @param [String] dest the destination filepath to rename to
  # @return [String] the renamed file path
  # @raise [RsyncError] if the directory specified in dest does not exist and cannot be created
  # @todo arbitrary commands may be able to be appended to dest, probably want to prevent that
  #   but Shellwords may handle it
  def rename(src, dest)
    retVal = nil
    # assume that arguments are rooted within the PREFIX subtree
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "src=#{src}, dest=#{dest}") if(@debug)
    prefixedSrc = prefixPath(src)
    prefixedDest = prefixPath(dest)
    $stderr.debugPuts(__FILE__, __method__, "DEBUG", "src=#{prefixedSrc}, dest=#{prefixedDest}") if(@debug)

    # setup dest directory
    if(prefixedDest[-1..-1] == "/")
      preDirname = prefixedDest
    else
      preDirname = File.dirname(prefixedDest)
    end
    relDirname = mkdir(preDirname)
    if(relDirname.nil?)
      raise RsyncError.new("Unable to rename #{src} to #{dest} because #{relativePath(preDirname)} does not exist on #{@host} and we could not create it")
    end

    cmd = "ssh #{@remoteUser}@#{@host} rsync --remove-sent-files #{Shellwords.escape(prefixedSrc)} #{Shellwords.escape(prefixedDest)}"
    status, stdout, stderr = popen4Wrapper(cmd)
    if(status.exitstatus != 0)
      retVal = nil
    else
      renamedPaths = ls(prefixedDest)
      retVal = relativePath(renamedPaths.first)
    end
    return retVal
  end

  # Upload file found at src to remote location dest
  # @param [String] src the local files to upload
  # @param [String] dest the location to put them, terminating in slash if dest is a directory
  # @param [TrueClass, FalseClass] safe if false, ignore existing files at dest (overwrite them)
  # @return [nil, String] uploaded filepath or nil if failure
  def upload(src, dest, safe=false)
    retVal = nil
    prefixedDest = prefixPath(dest)
    cmd = "rsync --times --recursive #{Shellwords.escape(src)} #{@remoteUser}@#{@host}:#{Shellwords.escape(prefixedDest)}"
    status, stdout, stderr = popen4Wrapper(cmd)
    if(status.exitstatus == 0)
      retVal = relativePath(dest)
    else
      retVal = nil
    end
    return retVal
  end

  # Parse ls -l style output from rsync
  # @param [String] listStr the ls -l style output in a single string
  # @return [Hash<String, Hash>] a mapping of filepaths to information about them
  #   :permissions [String] Unix-style file permission String e.g. -rw-rw-r--
  #   :size [String] the file size in bytes
  #   :modDate [String] a YYYY/MM/DD style string
  #   :modTime [String] a HH:MM:SS style string
  def parseList(listStr)
    numColumns = 5 # in ls -l style out from rsync
    fileData = {}
    lsLines = listStr.split(/\n/)
    lsLines.each{|line|
      tokens = line.split(/\s+/, numColumns)
      permissions, size, modDate, modTime, fileName = *tokens
      # rsync escapes scary characters to oct sequences like \#012 for newline (ASCII 10)
      fileName.gsub!(/\\#(\d+)/){|match| $1.to_i(8).chr}
      # for some reason -R and --no-implied-dirs removes "/" from filepath in output
      fileData["/#{fileName}"] = {
        :permissions => permissions,
        :size => size,
        :modDate => modDate,
        :modTime => modTime
      }
    }
    return fileData
  end

  # Prefix path with PREFIX unless PREFIX has already been applied
  # @param [String] path the file path to append PREFIX to
  # @return [String] the prefixed path
  def prefixPath(path)
    retVal = nil
    matchData = /^#{PREFIX}\/#{@user}\/(.*)/.match(path)
    if(matchData.nil?)
      retVal = File.join(PREFIX, @user, path)
    else
      retVal = path
    end
    return retVal
  end

  # Remove PREFIX from path component
  # @param [String] path the file path to remove the PREFIX from
  # @return [String] the relative path, without the absolute prefix
  def relativePath(path)
    retVal = nil
    matchData = /^#{PREFIX}\/#{@user}(\/.*)/.match(path)
    if(matchData.nil?)
      retVal = path
    else
      retVal = matchData[1]
    end
    return retVal
  end

  # Provide a wrapper around Open4::popen to print out the command, stdout, and stderr with the usual
  #   BRL logging utility, to ensure that processes do not hang due to unprocessed out or err,
  #   which may be the case with some commands, and to close file handles opened by popen
  # @return [Array] 
  #   [Process::Status] a status object with helpful methods #pid and #exitstatus
  #   [String] stdout from the process
  #   [String] stderr from the process
  # @todo use BRL::Util version
  def popen4Wrapper(cmd, out=true, err=true)
    $stderr.debugPuts(__FILE__, __method__, "CMD", cmd) if(@debug)
    pid = out = err = nil
    status = POpen4::popen4(cmd){|stdout, stderr, stdin, pid|
      out = ""; stdout.each{|line| out << line}
      err = ""; stderr.each{|line| err << line}
      $stderr.debugPuts(__FILE__, __method__, "CMD-OUT", out[0...50]) if(out and @debug)
      $stderr.debugPuts(__FILE__, __method__, "CMD-ERR", err) if(err and @debug)
    }
    $stderr.debugPuts(__FILE__, __method__, "CMD-EXIT_CODE", "exitstatus=#{status.exitstatus}") if(@debug)
    return status, out, err
  end
end
class RsyncError < RuntimeError; end
end ; end ; end ; end ; end # module BRL ; module Genboree ; module Pipeline ; module FTP ; module Helpers
