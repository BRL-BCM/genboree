#!/usr/bin/env ruby
require 'net/ftp'

$VERBOSE = nil

module BRL ; module Net
include ::Net

    # ---------------------------------------------------------------------------
    # Error Classes
    # ---------------------------------------------------------------------------
    class FetchFromFTP < StandardError
      def initialize(msg='')
        @message = msg
        super(msg)
      end
      def message=(value)
        @message = value
      end
      def message()
        @message
      end
    end


  class FetchFromFTP
      attr_accessor :serverName, :password, :userName, :files, :directories, :directoryName, :links

      # Required: the "new()" equivalent
    def initialize(serverName, directoryName, userName="anonymous", password="" )
	  @serverName = serverName
	  @userName = userName
	  @files = Hash.new {|hh, kk| hh[kk] = []}
	  @directories = Hash.new {|hh, kk| hh[kk] = []}
	  @links = Hash.new {|hh, kk| hh[kk] = []}
	  @password = password
	  @directoryName = directoryName
	  verifyInfo()
	  listFiles()
    end

    def verifyLocalDir(localDestination)
	  dir = nil
	  begin
	    dir = Dir::new(localDestination)
	  rescue => err
	    $stderr.puts "Error local directory is not accessible or do not exist DirName = #{localDestination}"
	    exit 133
	  end
    end
    
    def verifyInfo()	  
	  ftp = nil


	  begin
		ftp = Net::FTP.new(@serverName)
	  rescue => err
		$stderr.puts "Wrong location #{@serverName} server do not exist or not available"
		exit 143
	  end
	  
	  begin
		ftp.login(@userName, @password)
	  rescue => err
		$stderr.puts "Unable to login at #{@serverName} server "
		$stderr.puts "with user = #{@userName} and password = #{@password}"
		exit 148
	  end

	  begin
		dirhandle = ftp.chdir(@directoryName)
	  rescue => err
		$stderr.puts "Unable to accessDir #{@directoryName} in #{@serverName} server"
		exit 148
	  end
	  
    end


    def listFiles()
	  ftp = Net::FTP.new(@serverName)
	  ftp.login(@userName, @password)
	  test = "ddd"
	  link = "lll"
	  ftp.passive = true
	  dirhandle = ftp.chdir(directoryName)
	  ftp.list('*') { |item|
	    item.chomp!
	    attributes = item.split(" ")
	    lastAttribute = attributes.length - 1
	    fileName = attributes[lastAttribute].chomp
	    firstAttribute = attributes[0].chomp
	    if(firstAttribute[0] == test[0])
		directories[fileName] = attributes
	    elsif(firstAttribute[0] == link[0])
		links[fileName] = attributes
	    else
	       files[fileName] = attributes
	    end
	  }
	  ftp.close
    end

    def getFile(fileName, localDestination)
	  verifyLocalDir(localDestination)
	  ftp = Net::FTP.new(serverName) 
	  ftp.login(userName, password)
	  ftp.passive = true
	  fileInServer = "#{directoryName}/#{fileName}"
	  localFile = "#{localDestination}/#{fileName}"
	  ftp.getbinaryfile(fileInServer, localFile, 1024)
	  ftp.close
    end


    def getAllTextFiles(localDestination)
	  verifyLocalDir(localDestination)
	  ftp = Net::FTP.new(serverName)
	  ftp.login(userName, password)
	  ftp.passive = true
	      files.each_key{ |myfile|
	      fileInServer = "#{directoryName}/#{myfile}"
	      localFile = "#{localDestination}/#{myfile}"
#		 puts "Now trying to get -->#{myfile} = #{files[myfile]}"
#		  puts "cmd = ftp.getbinaryfile( #{directoryName}/#{myfile}, #{localDestination}/#{myfile})"
               ftp.getbinaryfile(fileInServer, localFile, 1024)
	      ftp.close
	  }
    end
      
    def getAllTextFilesThatMatch(localDestination, matchString)
	  verifyLocalDir(localDestination)
	  ftp = Net::FTP.new(serverName)
	  ftp.login(userName, password)
	  ftp.passive = true
	  files.each_key{ |myfile|
	      if(myfile =~ /#{matchString}/ )
		fileInServer = "#{directoryName}/#{myfile}"
		localFile = "#{localDestination}/#{myfile}"
		ftp.getbinaryfile(fileInServer, localFile, 1024)
              end
	  }
	  ftp.close
    end

    def getAllTextFilesInArray(localDestination, myArray)
	  verifyLocalDir(localDestination)
	  ftp = Net::FTP.new(serverName)
	  ftp.login(userName, password)
	  ftp.passive = true
	  myArray.each{ |myfile|
		fileInServer = "#{directoryName}/#{myfile}"
		localFile = "#{localDestination}/#{myfile}"
		ftp.getbinaryfile(fileInServer, localFile, 1024)
	  }
	  ftp.close
    end

    def printFiles(shortName = true, longName = false )
	 files.each_key{ |myfile|
		 if(shortName == true and longName == false)
		     puts "#{myfile}"
		 elsif(shortName == false and longName == true)
		     puts "#{files[myfile]}"
		 else
		     puts "#{myfile} = #{files[myfile]}"
		 end
	 }
    end

    def printDirs(shortName = true, longName = false )
		directories.each_key{ |myfile|
	     if(shortName == true and longName == false)
		  puts "#{myfile}"
	      elsif(shortName == false and longName == true)
		  puts "#{directories[myfile]}"
	      else
		  puts "#{myfile} = #{directories[myfile]}"
	      end
	  }
    end
    
  end #end of class
  
end end


##examples of how to use this class
#testing = BRL::Net::FetchFromFTP.new("hgdownload.cse.ucsc.edu", "/goldenPath/hg18")

## example of listing directories
#puts "Now printing dirs....."
#testing.printDirs()

## example of listing regular files
#puts "Now printing files....."
#testing.printFiles()

## example of getting a single file
#puts "getting file "
#testing.getFile("download.time", "/tmp")

## example of getting all regular files from the server not recursive
#puts "getting all files"
#testing.getAllTextFiles("/tmp")


