require 'uri'
require 'net/ftp'

module BRL; module TrackImporter
    class Utility
      # Downloads a file using FTP
      # [+fileURI+]   The location and name of a file that is to be downloaded
      # [+returns+]   Nothing
      def Utility.downloadFileFTP(fileURI)
        begin
          url = URI.parse(fileURI)
          fileArray = File.split(url.path)

          #Download File
          ftp = Net::FTP.new(url.host)
          ftp.login
          files = ftp.chdir(fileArray[0])
          ftp.getbinaryfile(fileArray[1], fileArray[1])
          ftp.close
        rescue StandardError => downloadError
          raise "Error downloading #{fileURI}"
        end
      end

      # Downloads a file using HTTP
      # [+fileURI+]   The location and name of a file that is to be downloaded
      # [+returns+]   Nothing
      def Utility.downloadFileHTTP(fileURI)
        begin
          url = URI.parse(fileURI)
          fileArray = File.split(url.path)

          Net::HTTP.start(url.host) { |http|
            resp = http.get(url.path)
            open(fileArray[1], "wb") { |file|
              file.write(resp.body)
            }
          }
        rescue StandardError => downloadError
          raise "Error downloading #{fileURI}"
        end
      end

      # Upload files using the correct Java library
      # [+userId+] The user id of the uploader
      # [+refSeqId+] The RefSeqId of the database to upload into
      # [+outputFile+] The name of the file to upload
      # [+returns+]   Nothing
      def Utility.uploadFile(userId, refSeqId, outputFile)
        cmd = "java -classpath "
        cmd += "/cluster.shared/local/lib/java/site_java/1.5/jars/servlet-api.jar:"
        cmd += "/cluster.shared/local/lib/java/site_java/1.5/jars/mysql-connector-java.jar:"
        cmd += "/cluster.shared/local/lib/java/site_java/1.5/jars/activation.jar:"
        cmd += "/cluster.shared/local/lib/java/site_java/1.5/jars/mail.jar:"
        cmd += "/cluster.shared/local/lib/java/site_java/1.5/jars/GDASServlet.jar "
        cmd += "-Xmx1800M org.genboree.upload.AutoUploader "
        cmd += "-u #{userId} -r #{refSeqId} -f #{Dir.pwd}/#{outputFile} "
        cmd += "-t lff -v -s"
        if(not system(cmd))
          raise "Error uploading #{outputFile}"
        end

      end

      # Downloads all files for the given track
      # [+trackData+] The individual track information
      # [+returns+] An array with the new names of the mappingFile(s), and dataFile(s)
      def Utility.downloadAllFiles(trackData)

        mappingFilesArray = trackData.mappingFile.split(",")
        dataFilesArray = trackData.dataFile.split(",")

        outputMappingFiles = ""
        outputDataFiles = ""
        if(not trackData.mappingFile == ".")
          mappingFilesArray.each { |mappingFile|
            url = URI.parse(mappingFile)
            if(url.scheme.downcase == "http")
              downloadFileHTTP(mappingFile)
            elsif(url.scheme.downcase == "ftp")
              downloadFileFTP(mappingFile)
            else
              raise "Unkown Scheme #{url.scheme} for #{mappingFile}"
            end

            if(outputMappingFiles != "")
              outputMappingFiles += ","
            end
            outputMappingFiles += File.split(URI(mappingFile).path)[1]
          }
        end
        
        if(not trackData.dataFile == ".")
          dataFilesArray.each { |dataFile|
            url = URI.parse(dataFile)
            if(url.scheme.downcase == "http")
              downloadFileHTTP(dataFile)
            elsif(url.scheme.downcase == "ftp")
              downloadFileFTP(dataFile)
            else
              raise "Unkown Scheme #{url.scheme} for #{dataFile}"
            end

            if(outputDataFiles != "")
              outputDataFiles += ","
            end
            outputDataFiles += File.split(URI(dataFile).path)[1]
          }
        end
        [outputMappingFiles, outputDataFiles]
      end

      # Uploads all files for the given track
      # [+trackData+] The individual track information
      # [+returns+] nothing
      def Utility.uploadAllFiles(trackData)
        outputFilesArray = trackData.outputFile.split(",")

        outputFilesArray.each { |outputFile|
          uploadFile(trackData.userId, trackData.refSeqId, outputFile)
        }
      end

      # Creates an instance of the TrackData probably from the trackImporter.info
      # file
      # [+arrayData+] Array data of track information
      # [+returns+] New instance of TrackData
      def Utility.arrayToTrackData(arrayData)
        returnStruct = TrackData.new(arrayData[0], arrayData[1], arrayData[2], arrayData[3], arrayData[4], arrayData[5], arrayData[6], arrayData[7], arrayData[8], arrayData[9], arrayData[10], arrayData[11], arrayData[12], "", "", "", "", "", "")
        returnStruct
      end
    end
  end; end

TrackData = Struct.new(:key, :location, :lffClass, :lffType, :lffSubType, :engine, :configFile, :mappingFile, :dataFile, :outputFile, :overideLFFClass, :overideLFFType, :overideLFFSubType, :exitCode, :error, :message, :userId, :refSeqId, :groupId)