#!/usr/bin/env ruby

require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/abstract/resources/user'
require 'brl/genboree/kb/graphics/d3/converters'

module BRL; module Genboree ; module ExRNAatlas ;

  # class to convert transformed output to dr json 
  # used by exrna atlas
  # @todo This class is  to be replaced by API-extension based class
  # This class is not be used anywhere else except for exRNA-atlas
  class TransformToD3generator
    attr_reader :gbHost
    attr_reader :baseDir

    # param[String] conf path to the main configuration file - for instance, data/exRNA-atlas-public.conf 
    # param[String] userId user id of the user, nil for the public version
    def initialize(baseDir, gbHost, userId)
      @gbHost = gbHost
      @baseDir = baseDir
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Configuration file for the atlas found: #{@conf.inspect}")
      @userId = userId
      @hostauthmap = {}
      @hostauthmap = (!userId.nil? and userId !~ /\S/) ? Abstraction::User.getHostAuthMapForUserId(nil, userId) : {}
    end
   
    # goes through all the entries, transforms and writes the generated d3 to
    # the path mentioned in the dataConfig
    # param[String] summaryFile name or key of the data summary json file from which
    # d3 is to be generated. Ex - sampleSummaryConf|dataSummaryConf|linearTreeConf
    def generateD3FromConfig(summaryFile, opts={})
       # get the host
       d3LvpHelper =  BRL::Graphics::D3::D3LvpListHelpers 
       summaryFile = "#{@baseDir}/#{summaryFile}"
       # read the file
       if(summaryFile)
          begin
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "summaryFile: #{summaryFile.inspect}")
            dataCon = JSON(File.read(summaryFile))
            dataCon.each { |dataObj|
              trObj = nil
              rawTransform = nil
              outputFile = nil
              trans = dataObj['transformation']
              transuri = URI.parse(trans) unless(trans.is_a?(Array))
              d3path = "#{@baseDir}/#{dataObj['path']}"
              #Make the transformation call
              apiCaller = BRL::Genboree::REST::ApiCaller.new(@gbHost, "#{transuri.path}?#{transuri.query}", @hostauthmap)
              apiCaller.get()
              if(apiCaller.succeeded?)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "API: #{apiCaller.parseRespBody['data'].inspect}")
                trObj = apiCaller.parseRespBody['data']
                rawTransform = JSON.pretty_generate(trObj)
                #Create KB=>D3 converter
                d3conv = BRL::Genboree::KB::Graphics::D3::KbTransformConverter.from_string( rawTransform )
                #Convert to D3 JSON format
                d3json = d3conv.to_d3Lvp(rawTransform)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "d3json: #{d3json.inspect}")
                if(opts.key?('percentage'))
                  #Get percent of samples per PI - this is the D3 structure needed for the bar chart
                  d3Percent = d3LvpHelper.percentageD3LvpOneList(d3json)
                  outputFile = d3Percent
                else
                  outputFile = d3json
                end
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to write to the file - #{d3path}")
                ff = File.open(d3path,"w")
                ff.write(JSON.pretty_generate(outputFile))
                ff.close()
              else
                #break? error
                break
                 raise "API_ERROR #{apiCaller.parseRespBody}"
              end
            }
          rescue => err
            raise ArgumentError, "ERROR: Failed to parse the summary file - #{summaryFile.inspect}.\n Details - #{err.message}"
          end
        end
    end 
  
    def generateD3FromConfigSingleEntry(summaryFile, transformationMatch, opts={})
      d3LvpHelper =  BRL::Graphics::D3::D3LvpListHelpers
      summaryFile = "#{@baseDir}/#{summaryFile}"
      if(summaryFile)
        begin
          dataCon = JSON(File.read(summaryFile))
          dataCon.each { |dataObj|
            trObj = nil
            rawTransform = nil
            outputFile = nil
            trans = dataObj['transformation']
            transuri = URI.parse(trans) unless(trans.is_a?(Array))
            d3path = "#{@baseDir}/#{dataObj['path']}"
            #Look for the  entry that matches the transformation match string in the config
            if(transformationMatch and trans =~ /(#{transformationMatch})/)
              #Make the transformation call
              apiCaller = BRL::Genboree::REST::ApiCaller.new(@gbHost, "#{transuri.path}?#{transuri.query}", @hostauthmap)
              apiCaller.get()
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Transformation = #{apiCaller.parseRespBody.inspect}")
              if(apiCaller.succeeded?)
                trObj = apiCaller.parseRespBody['data']
                rawTransform = JSON.pretty_generate(trObj)
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "rawTransform =#{rawTransform.inspect}")
                #Create KB=>D3 converter
                d3conv = BRL::Genboree::KB::Graphics::D3::KbTransformConverter.from_string( rawTransform )
                #Convert to D3 JSON format
                if(opts.key?('sumOfAllSubjects') and opts['sumOfAllSubjects'].empty?)
                  d3json = d3conv.sumOfAllSubjects(0, true)
                  d3json = [d3json]
                else
                  d3json = d3conv.to_d3Lvp(rawTransform)
                end
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "d3json = #{d3json.inspect}")

                if(opts.key?('SumSubjectsMatchVal'))
                  $stderr.debugPuts(__FILE__, __method__, "DEBUG", "SumSubjectsMatchVal = #{opts['SumSubjectsMatchVal']}")
                  summed = d3conv.to_d3LvpSumSubjectsMatchVal(opts['SumSubjectsMatchVal'])
                end
                if(opts.key?('percentage'))
                  #Get percent of samples per PI - this is the D3 structure needed for the bar chart
                  if(opts['percentage'] == 'onelist')
                    d3Percent = d3LvpHelper.percentageD3LvpOneList(d3json)
                  elsif(opts['percentage'] == 'lists')
                    #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Percentage - #{opts['percentage']}")
                    d3Percent = d3LvpHelper.percentageD3LvpLists(d3json, summed)
                  end
                  outputFile = d3Percent
                  #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Outfile = #{outputFile.inspect}")
                else
                  outputFile = d3json
                end
                #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to write to the file - #{d3path}")
                ff = File.open(d3path,"w")
                ff.write(JSON.pretty_generate(outputFile))
                ff.close()
              else
                #break? error
                break
                raise "API_ERROR #{apiCaller.parseRespBody}"
              end
            end
          }
          rescue => err
          raise ArgumentError, "ERROR: Failed to parse the summary file - #{summaryFile.inspect}.\n Details - #{err.message}"
        end
      end
    end 

    def mergeTransformationsGenerateD3(summaryFile, opts={})
      d3LvpHelper =  BRL::Graphics::D3::D3LvpListHelpers
      summaryFile = "#{@baseDir}/#{summaryFile}"
      if(summaryFile)
        begin
         dataCon = JSON(File.read(summaryFile))
         dataCon.each{|dataObj|
           trObj = nil
           rawTransform = nil
           outputFile = nil
           trans = dataObj['transformation']
           d3path = "#{@baseDir}/#{dataObj['path']}"
           if(trans.is_a?(Array))
             # this is the entry that has multiple transformations
             total = []
             # go through each transformation and its corrsp options
             apiCaller = BRL::Genboree::REST::ApiCaller.new(@gbHost, "", @hostauthmap)
             trans.each_with_index{|trf, ii|
               #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "TransformationURI = #{trf.inspect}")
               truri = URI.parse(trf)
               apiCaller.setRsrcPath("#{truri.path}?#{truri.query}")
               apiCaller.get()
               #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Transformation = #{apiCaller.parseRespBody.inspect}")
               if(apiCaller.succeeded?)
                 rawTransform = JSON.pretty_generate(apiCaller.parseRespBody['data'])
                 #Create KB=>D3 converter
                 d3conv = BRL::Genboree::KB::Graphics::D3::KbTransformConverter.from_string( rawTransform )
                 #sum as per the opts
                 if(opts.key?('sumOfAllSubjects'))
                   #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "OPTS = #{opts['sumOfAllSubjects'][ii].inspect}")             
                   total << d3conv.sumOfAllSubjects(0, true, opts['sumOfAllSubjects'][ii])
                 end
               else
                 break
                 raise "API_ERROR #{apiCaller.parseRespBody}"
               end
            }
            
          # total is done here
          d3Percent = d3LvpHelper.percentageD3LvpOneList(total)
          $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to write to the file - #{d3path}")
          ff = File.open(d3path,"w")
          ff.write(JSON.pretty_generate(d3Percent))
          ff.close()
          end
         }
        rescue => err
          raise ArgumentError, "ERROR: Failed to parse the summary file - #{summaryFile.inspect}.\n Details - #{err.message}"
        end
      end # is summaryFile
    end

    def getd3Hierarchical(summaryFile)
      d3LvpHelper =  BRL::Graphics::D3::D3LvpListHelpers
      summaryFile = "#{@baseDir}/#{summaryFile}"
      if(summaryFile)
        begin
         dataObj = JSON(File.read(summaryFile))
             $stderr.debugPuts(__FILE__, __method__, "DEBUG", "DataObj - #{dataObj.inspect}")
           trObj = nil
           rawTransform = nil
           outputFile = nil
           trans = dataObj['transformation']
           d3path = "#{@baseDir}/#{dataObj['path']}"
           truri = URI.parse(trans)
           apiCaller = BRL::Genboree::REST::ApiCaller.new(@gbHost, "", @hostauthmap)
           apiCaller.setRsrcPath("#{truri.path}?#{truri.query}")
           apiCaller.get()
           if(apiCaller.succeeded?)
             tr = apiCaller.parseRespBody['data']
             rawTransform = JSON.pretty_generate(tr)
             d3conv = BRL::Genboree::KB::Graphics::D3::KbTransformConverter.from_string( rawTransform )
             # Get pruned version of transforma; prune branches with 0 samples
             cleanTransform = d3conv.cleanPartData()
             d3hier = d3conv.to_d3Hierarchical(cleanTransform)
             $stderr.debugPuts(__FILE__, __method__, "DEBUG", "d3hier - #{d3hier.inspect}")
             BRL::Graphics::D3::D3HierarchyHelpers.addNodeSums(d3hier)
             d3hier["name"] = "All Samples"
             $stderr.debugPuts(__FILE__, __method__, "DEBUG", "Going to write to the file - #{d3path}")
            ff = File.open(d3path,"w")
            ff.write(JSON.pretty_generate(d3hier))
            ff.close()
          else
            raise "API_ERROR #{apiCaller.parseRespBody}"   
          end
        rescue => err
          raise ArgumentError, "ERROR: Failed to parse the summary file - #{summaryFile.inspect}.\n Details - #{err.message}"
        end
      end
    end

  end
end; end; end
