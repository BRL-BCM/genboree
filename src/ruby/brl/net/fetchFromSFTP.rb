#!/usr/bin/env ruby
require 'net/sftp'

$VERBOSE = nil

module BRL ; module Net
include ::Net

    # ---------------------------------------------------------------------------
    # Error Classes
    # ---------------------------------------------------------------------------
    class FetchFromSFTP < StandardError
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


    class FetchFromSFTP
        attr_accessor :serverName, :password, :userName, :files, :directories, :directoryName, :links

        # Required: the "new()" equivalent
        def initialize( serverName, userName, password, directoryName)
            @serverName = serverName
            @userName = userName
            @files = Hash.new {|hh, kk| hh[kk] = []}
            @directories = Hash.new {|hh, kk| hh[kk] = []}
            @links = Hash.new {|hh, kk| hh[kk] = []}
            @password = password
            @directoryName = directoryName
            listFiles()
        end

        def listFiles()
            Net::SFTP.start(serverName, userName, password) { |sftp|
                    file = ""
                    allAtrib = ""
                    test = "ddd"
                    link = "lll"
                    dirhandle = sftp.opendir(directoryName)
                    dirContent = sftp.readdir(dirhandle)
                    dirContent.each {|item|
                        file = item.filename
                        file.chomp!
                        allAtrib = item.longname
                        allAtrib.chomp!
                        if(allAtrib[0] == test[0])
                            directories[file] = allAtrib
                        elsif(allAtrib[0] == link[0])
                            links[file] = allAtrib
                        else
                           files[file] = allAtrib
                        end

    #                    p thing.attributes
                    }
                    sftp.close_handle(dirhandle)
            }
        end

        def getFile(fileName, localDestination)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.get_file "#{directoryName}/#{fileName}", "#{localDestination}/#{fileName}"
            }
        end

        def writeMyDataToAFileInServer(fileName, myData)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.open_handle("#{directoryName}/#{fileName}", "w") { |handle|
                    result = sftp.write(handle, myData)
    #                puts "the result code = #{result.code} and the data = #{myData}"
                }
            }
        end

      def getFilePermissionOnServer (fileName)
            perm = ""
                Net::SFTP.start(serverName, userName, password) { |sftp|
                    perm = sftp.stat("#{directoryName}/#{fileName}").permissions
                    perm = perm.to_s(8)[-3,3]
                  }
                  return perm
      end

      def setFilePermissionOnServer (fileName, permission)
        permission = permission.to_i
        $stderr.puts("Error invalid mode #{permission}! the permission should be a three digit number between 0 and 777 ") if(permission < 0 or permission > 777)
        Net::SFTP.start(serverName, userName, password) { |sftp|
            sftp.setstat("#{directoryName}/#{fileName}", :permissions => permission)
          }
      end


        def createDirInServer(serverNewDirName, permission)
            permission = permission.to_i
            $stderr.puts("Error invalid mode #{permission}! the permission should be a three digit number between 0 and 777 ") if(permission < 0 or permission > 777)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.mkdir("#{directoryName}/#{serverNewDirName}", :permissions => permission)
          }
        end

        def removeDirInServer(serverDirName)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.rmdir("#{directoryName}/#{serverDirName}")
          }
        end

        def removeFileInServer(fileInServer)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.remove("#{directoryName}/#{fileInServer}")
          }
        end

        def renameFile(fileName, newDirname, newFileName)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.rename("#{directoryName}/#{fileName}", "#{newDirname}/#{newFileName}")
            }
        end

        def getAllTextFiles(localDestination)
            Net::SFTP.start(serverName, userName, password) { |sftp|
                files.each_key{ |myfile|
    #               puts "Now trying to get -->#{myfile} = #{files[myfile]}"
    #                puts "cmd = sftp.get_file #{directoryName}/#{myfile}, #{localDestination}/#{myfile}"
                    sftp.get_file "#{directoryName}/#{myfile}", "#{localDestination}/#{myfile}"
                }
            }
        end

        def getContentOfFile(fileName)
            data = nil
            Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.open_handle("#{directoryName}/#{fileName}") { |handle|
                data = sftp.read(handle)
                }
            }
            return data
        end


        def putAFileInServer(localDirWithFile, localFileName, remoteFileName)
            ::Net::SFTP.start(serverName, userName, password) { |sftp|
                sftp.put_file "#{localDirWithFile}/#{localFileName}", "#{directoryName}/#{remoteFileName}"
            }
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


    end
end end


##examples of how to use this class
#testing = BRL::Util::FetchFromSFTP.new('SERVERNAME', 'USERNAME', 'PASSWORD', 'INITIALDIR')

## example of listing directories
#puts "Now printing dirs....."
#testing.printDirs()

## example of listing regular files
#puts "Now printing files....."
#testing.printFiles()

## example of getting a single file
#puts "getting file "
#testing.getFile("091607-0847-resultsVerificationPartial-MissingDbs.log", "/tmp")

## example of getting all regular files from the server not recursive
#puts "getting all files"
#testing.getAllTextFiles("/tmp/simpleTest")

## example of getting the content of file in memory
#puts "No files just the content of a file"
#myFileContent = testing.getContentOfFile("091607-0847-resultsVerificationPartial-MissingDbs.log")
#puts "the content of my file = #{myFileContent}"

## example of uploading a file into the server
#testing.putAFileInServer("/usr/local/brl/home/manuelg", "someGenes.lff", "veryImportantFile.lff")

## example of how to get permission of a remote file
#perm = testing.getFilePermissionOnServer("veryImportantFile.lff")
#puts "the file veryImportantFile.lff has a permission of #{perm}"

## example of how to set permission of a remote file
#testing.setFilePermissionOnServer("veryImportantFile.lff", 0666)
#perm = testing.getFilePermissionOnServer("veryImportantFile.lff")
#puts "the file veryImportantFile.lff has a permission of #{perm}"

## example of how create a directory remotly
#testing.createDirInServer("someStrangeNewDir", 0777)

## example of how remove a remote directory (have to be empty)
#testing.removeDirInServer("someStrangeNewDir")

## example of how remove a remote file
#testing.removeFileInServer("veryImportantFile.lff")

## example of how to rename a remote file
#testing.renameFile("fileToMove.txt", "/usr/local/brl/home/genbadmin/someTestDir/moreTest/Maybe/", "myNewFile.txt")
