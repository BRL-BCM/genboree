#!/usr/bin/env ruby
#########################################################
############ FTP smRNAPipeline metadata bulk upload #####
## This wrapper splits the metadata doc file into individual 
## collections and uploads them to the appropriate collection
## in GenboreeKB
#########################################################

require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/genboree/rest/apiCaller'

include BRL::Genboree::REST
module BRL; module Genboree; module Tools; module Scripts
  class ExRNAMetadataValidator
    VERSION = "1.0"
    COMMAND_LINE_ARGS = { }
    DESC_AND_EXAMPLES = {
      :description  => "This is the wrapper for uploading metadata to GenboreeKB exRNA metadata Collections'.
                        It is intended to be called when data is submitted through the FTP Pipeline",
      :authors      => [ "Sai Lakshmi Subramanian(sailakss@bcm.edu)" ],
      :examples     => [
        "#{File.basename(__FILE__)} --inputFile=filePath",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    def uploadMetadata() 
      ## Get the metadata file
      inputFile = File.expand_path(@optsHash['--inputFile'])

      #inputFile = "/home/sailakss/sai/tabbedModels/docs/allDocs.tsv"

      ## Split docs into various collections
      metadataObjects = ["Biosample", "Run", "Analysis", "Experiment", "Study", "Submission"]

      docObjects = {}
      metadataObjects.each {|md|
        docObjects[md] = ""
      }

      linesInFile = File.read(inputFile) 
      docsArray = linesInFile.split(/^(?=#)/)

      docsArray.each{ |data|
        puts data
        metadataObjects.each {|md|
          if(data =~ /^#{md}/)
            docObjects[md] << data
          end
        }
      }

      ## Use apiCaller to bulk upload docs into its collection
      rsrcPath = "/REST/v1/grp/exRNAKbGroup/kb/exRNAKb/coll/{coll}/docs?format=tabbed_prop_nesting&docType=data"
      docObjects.each { |collName, metadataDocs|
        rsrcPath.gsub!(/\{coll\}/, collName) 
        apiCaller.setRsrcPath(rsrcPath)
        # format tell the API the format of the payload (JSON is the default payload format)
        # docType is the document type: data or model. Currently only data is supported. 
        apiCaller.put(
          { :grp => exRNAKbGroup, :kb => exRNAKb, :coll => collName },
            metadataDocs
        )
        if(apiCaller.succeeded?)
          $stderr.debugPuts(__FILE__, __method__, "STATUS", "Successfully uploaded all docs in the KB")
        else
          $stderr.debugPuts(__FILE__, __method__, "ERROR", "Failed to upload docs to the GenboreeKB collection. API Response:\n#{apiCaller.respBody.inspect}")  
        end
      }
    end 
  end
end ; end ; end # module BRL ; module Genboree ; module Tools

