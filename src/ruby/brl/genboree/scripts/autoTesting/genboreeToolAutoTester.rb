#!/usr/bin/env ruby
require 'time'
require 'json'
require 'pathname'
require 'brl/util/util'
require 'brl/db/dbrc'
require 'brl/script/scriptDriver'
require 'brl/genboree/rest/apiCaller'

# Write sub-class of BRL::Script::ScriptDriver
module BRL ; module Genboree ; module Scripts ; module AutoTesting
  class GenboreeToolAutoTester < BRL::Script::ScriptDriver
    # ------------------------------------------------------------------
    # SUB-CLASS INTERFACE
    # - replace values for constants and implement abstract methods
    # ------------------------------------------------------------------
    # INTERFACE: provide version string
    VERSION = "0.6"
    # INTERFACE provide *specific* command line argument info
    # - Hash of '--longName' arguments to Array of: arg type, one-char arg name, description.
    COMMAND_LINE_ARGS = {
      "--testJobRoot"   =>  [ :REQUIRED_ARGUMENT, "-t", "Root of the dir containing the tool test job dir tree." ],
      "--genboreeHost"  =>  [ :REQUIRED_ARGUMENT, "-a", "Genboree host to which to submit tool job." ],
      "--genboreeGroup" =>  [ :REQUIRED_ARGUMENT, "-g", "Genboree group to which to save jobs outputs (it cannot exists)." ],
      "--genboreeUser"  =>  [ :REQUIRED_ARGUMENT, "-u", "Genboree user for which to submit tool job." ]
    }
    # INTERFACE: Provide general program description, author list (you...), and 1+ example usages.
    DESC_AND_EXAMPLES = {
      :description => "
  Traverses the tool test job dir tree to find automatic testing tool jobs that need to be submitted.

  The tool test job root dir is expected to contain subdirs named after the toolIds. Within those subdirs
  are one or more sub-subdirs named after the test case 'name/id', perhaps matching some known 'use case' name.

  Within each test case sub-subdir is a dir tree with a very particular layout. But this script will look for:
  'autoRunJob/conf/jobFile.json' and use it as a template to submit the test job.

  Aside: here is the general layout of the tool test job dir tree, with dynamic names marked with {}:
  .
  |-- {TOOL_ID}/
  |   `-- {TEST_CASE_NAME}/
  |       |-- autoRunJob/
  |       |   `-- conf/                   # <= script looks here for jobFile.json template
  |       |-- canonicalOutput/
  |       |   |-- cluster/
  |       |   |   `-- jobDir/
  |       |   |       |-- logs/
  |       |   |       |-- scratch/
  |       |   |       `-- scripts/
  |       |   `-- genboree/
  |       |       `-- uploadedJobFiles/
  |       |           `-- raw/
  |       `-- inputs/
  |           `-- files/
  |-- {TOOL_ID}/
  |   `-- ... etc...

      ",
      :authors      => [ "Andrew R Jackson (andrewj@bcm.edu)" ],
      :examples => [
        "#{File.basename(__FILE__)} -g genboree.org --testJobRoot=/cluster.shared/data/groups/genboree/canonicalToolJobs",
        "#{File.basename(__FILE__)} --help"
      ]
    }

    # ------------------------------------------------------------------
    # IMPLEMENTED INTERFACE METHODS
    # ------------------------------------------------------------------
    # run()
    #  . MUST return a numerical exitCode (20-126). Program will exit with that code. 0 means success.
    #  . Command-line args will already be parsed and checked for missing required values
    #  . @optsHash contains the command-line args, keyed by --longName
    def run()
      retVal = EXIT_OK
      retVal = validateAndProcessArgs()
      report = {}
      if(retVal == EXIT_OK)
        # Find job files
        jobFiles = Dir.glob("#{@rootDir}/**/autoRunJob/conf/jobFile.json")
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "Found #{jobFiles.size} autoRunJob jobFile.json templates to fill and submit:\n  - #{jobFiles.join("\n  - ")}")
        # Create time string for use in Analysis Name and such
        timeStr = Time.now.strftime("%Y-%m-%d %H:%M")
        dateStr = Time.now.strftime("%Y-%m-%d")
        # Get dbrc rec for user/pass info
        dbrc = BRL::DB::DBRC.new()
        dbrcRec = dbrc.getRecordByHost(@host, :api)
dbrcRec[:user] = "genbadmin"   # TODO - what kind of account is it ?
dbrcRec[:password] = "genbadmin"      
        @userLogin = dbrcRec[:user]
        @userPassword = dbrcRec[:password]
        # Create target group
        raise 'Group #{@group} already exists. Quit.' if(checkIfGroupExists(@group))
        createGroup(@group, 'Group for tests') #unless(checkIfGroupExists(@group))
        raise 'Created group #{@group} is not visible. Quit.' unless(checkIfGroupExists(@group))
        
        # Process each jobFile.json we found:
        jobFiles.each { |jobFile|
          jobFile = File.expand_path(jobFile)
          begin
            # Read job file
            jsonStr = File.read(jobFile)
            # Fill in {TIME}, {HOST}, etc template fields everywhere in json string:
            jsonStr.gsub!(/\{TIME\}/, timeStr)
            jsonStr.gsub!(/\{DATE\}/, dateStr)
            jsonStr.gsub!(/\{HOST\}/, @host)
            # Now parse (mainly to raise exception if invalid, but also to dig out toolId...
            jobObj = JSON.parse(jsonStr)
            toolId = jobObj['context']['toolIdStr']
            # replace user id by the value given in the command line (if set)
            if(@userId)
              jobObj['context']['userId'] = @userId
            end
            # check if output elements exist and create them if not
            jobObj['outputs'].map! { |output|
              uriPath = URI::split(output)[5]
              unless(uriPath =~ %r{^/REST/v1/grp/[^/]+/[^/]+/[^/]+})
                raise "Incorrect type of output's path: " + uriPath 
              end
              pathElements = uriPath.split('/')
              outputType = pathElements[5]
              outputName = CGI::unescape(pathElements[6])
              case outputType
                when 'db'
                  templateVersion = outputName.split(/(\s|\-)/).last()
                  createDatabase(@group,outputName,templateVersion) unless(checkIfDatabaseExists(@group,outputName))
                when 'prj'
                  outputName = @group + "_" + outputName   # TODO - because of bug in projects - name must be unique
                  createProject(@group,outputName) unless(checkIfProjectExists(@group,outputName))
                else
                  raise "Unknown type of output: " + outputType 
              end 
              "http://#{CGI::escape(@host)}/REST/v1/grp/#{CGI::escape(@group)}/#{outputType}/#{CGI::escape(outputName)}"
            }
            # Submit job
            # Create a reusable ApiCaller instance
            apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, "/REST/v1/genboree/tool/{toolId}/job", @userLogin, @userPassword)
            httpResp = apiCaller.put({ :toolId => toolId }, jobObj.to_json)
            # Check result
            if(apiCaller.succeeded?)
              apiCaller.parseRespBody()
              $stderr.debugPuts(__FILE__, __method__, "STATUS", "Tool job accepted with analysis name: #{jobObj['settings']['analysisName'].inspect}. \n  HttpResponse: #{httpResp.inspect}\n  statusCode: #{apiCaller.apiStatusObj['statusCode'].inspect}\n  statusMsg: #{apiCaller.apiStatusObj['msg'].inspect}\n")
              report[jobFile] = true
            else
              $stderr.debugPuts(__FILE__, __method__, "ERROR [but continuing]:", "Tool job submission failed! HTTP Response object: #{httpResp.class}. Response payload:\n#{apiCaller.respBody}")
              report[jobFile] = false
            end
          rescue => err
            report[jobFile] = false
            $stderr.debugPuts(__FILE__, __method__, "ERROR [but continuing]", "Problem with #{jobFile.inspect}: #{err.message.inspect}.\n#{err.backtrace.join("\n")}")
          ensure
            $stderr.puts("#{'='*80}\n")
          end
        }
      end
      
      $stdout.puts("Failed:")
      countTrue = 0
      countFalse = 0
      report.each { |key,value|
        if(not value)
          $stdout.puts(key)
          countFalse = countFalse + 1
        else
          countTrue = countTrue + 1
        end
      }
      $stdout.puts "Submitted: #{countTrue.to_s()}   Failed: #{countFalse.to_s()}"
      
      # Must return a suitable exit code number
      return retVal
    end

    # ------------------------------------------------------------------
    # SCRIPT-SPECIFIC METHODS
    # ------------------------------------------------------------------
    # - stuff needed to do actual program or drive 3rd party tools, etc
    # - repeatedly-used generic stuff is in library classes of course...
    def validateAndProcessArgs()
      retVal = EXIT_OK
      @rootDir = @optsHash['--testJobRoot']
      @host    = @optsHash['--genboreeHost']
      @group   = @optsHash['--genboreeGroup']
      @userId  = @optsHash['--genboreeUser']
      unless(File.exist?(@rootDir))
        $stderr.puts "\nERROR: the tool test job root dir #{@rootDir.inspect} does not exist!\n\n"
        retVal = 35
      else
        $stderr.debugPuts(__FILE__, __method__, "STATUS", "using tool test job root dir of #{@rootDir.inspect}")
      end
      return retVal
    end
    
    # - general function to check if given object exists by sending "get" request
    # - returns true/false
    # - raise exception when error occurs
    def checkIfExists(uriPath)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, uriPath, @userLogin, @userPassword)
      resp = apiCaller.get()
      puts "Api call, details: uri=#{uriPath}  fullResponse=#{apiCaller.respBody()}" 
      return false if(resp.kind_of?(::Net::HTTPNotFound))
      return true  if(apiCaller.succeeded?())
      raise "Api call failed (get), details:\n  uri=#{uriPath}\n  fullResponse=#{apiCaller.respBody()}"   
    end
    
    # - check if user group exists, returns true/false
    # - raise exception when error occurs
    def checkIfGroupExists(groupName)
      return checkIfExists('/REST/v1/grp/' + CGI::escape(groupName) + '?')
    end
    
    # - check if database exists, returns true/false
    # - raise exception when error occurs
    def checkIfDatabaseExists(groupName, databaseName)
      return checkIfExists('/REST/v1/grp/' + CGI::escape(groupName) + '/db/' + CGI::escape(databaseName) + '/name?')
    end
    
    # - check if project exists, returns true/false #TODO - always returns true - bug in API ?
    # - raise exception when error occurs
    def checkIfProjectExists(groupName, projectName)
      return checkIfExists('/REST/v1/grp/' + CGI::escape(groupName) + '/prj/' + CGI::escape(projectName) + '/title?')
    end   
    
    # - general function to create object by sending "put" request
    # - raise exception when error occurs
    def createObject(uriPath)
      apiCaller = BRL::Genboree::REST::ApiCaller.new(@host, uriPath, @userLogin, @userPassword)
      resp = apiCaller.put()
      puts "Api call, details: uri=#{uriPath}  fullResponse=#{apiCaller.respBody()}" 
      raise "Api call failed (put), details:\n  uri=#{uriPath}\n  fullResponse=#{apiCaller.respBody()}" if(apiCaller.failed?())  
    end  
    
    # - create group
    # - raise exception when error occurs
    def createGroup(groupName, groupDescription)
      createObject('/REST/v1/grp/' + CGI::escape(groupName) + '?')
    end
    
    # - create project
    # - raise exception when error occurs
    def createProject(groupName, projectName)
      createObject('/REST/v1/grp/' + CGI::escape(groupName) + '/prj/' + CGI::escape(projectName) + '?')
    end
    
    # - create database
    # - raise exception when error occurs
    def createDatabase(groupName, databaseName, templateVersion)
      templateName = nil
      if templateVersion == "hg19"
        templateName = "Template: Human (Hg19)"
      else
        raise "Unsupported version of template: " + templateVersion
      end
      createObject('/REST/v1/grp/' + CGI::escape(groupName) + '/db/' + CGI::escape(databaseName) + '?templateName=' + CGI::escape(templateName))
    end

  end
end ; end ; end ; end # module BRL ; module Genboree ; module Scripts ; module AutoTesting

########################################################################
# MAIN - Provided in the scripts that implement ScriptDriver sub-classes
# - but would look exactly like this ONE LINE:
########################################################################
# IF we are running this file (and not using it as a library), run it:
if($0 and File.exist?($0) and BRL::Script::runningThisFile?($0, __FILE__, true))
  # Argument to main() is your specific class:
  BRL::Script::main(BRL::Genboree::Scripts::AutoTesting::GenboreeToolAutoTester)
end
