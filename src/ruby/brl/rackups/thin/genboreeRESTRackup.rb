# A rackup Rack file. For use with thin or other rackup-enabled web server

# ##############################################################################
# REQUIRED LIBRARIES (basic only, no direct or indirect class discovery
# ##############################################################################
require 'rack/showexceptions'
require 'brl/extensions/bson'
require 'brl/util/util'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/rest/apiCaller'
require 'brl/activeSupport/activeSupport'

# ##############################################################################
# CORE CLASS DEFINTION
# - In advance of any direct or indirect (through requires) dynamic class discovery
# - Class-method/properties defined and available immediately
# ##############################################################################
class GenboreeRESTRackup
  class << self
    # Set up class instance variables
    attr_accessor :resourcesLoaded, :skipLoadPathPattern, :classDiscoveryDone, :resources, :resourceFileMap, :tools, :toolIdMap, :toolMap
    GenboreeRESTRackup.resourcesLoaded = false
    GenboreeRESTRackup.skipLoadPathPattern = nil
    GenboreeRESTRackup.classDiscoveryDone = {}
    GenboreeRESTRackup.resources = []
    GenboreeRESTRackup.resourceFileMap = {}
    GenboreeRESTRackup.tools = []
    GenboreeRESTRackup.toolIdMap = {}
    GenboreeRESTRackup.toolMap = {} # Maps tool id to all other constants

    # Save any dir-skipping pattern for use elsewhere
    genbConf = BRL::Genboree::GenboreeConfig.load() rescue nil
    if(genbConf and genbConf.skipLoadPathPattern and genbConf.skipLoadPathPattern =~ /\S/)
      GenboreeRESTRackup.skipLoadPathPattern = genbConf.skipLoadPathPattern
      GenboreeRESTRackup.skipLoadPathPattern = Regexp.new(GenboreeRESTRackup.skipLoadPathPattern) rescue nil
    else
      GenboreeRESTRackup.skipLoadPathPattern = nil
    end
  end

  DEFAULT_RESOURCE_PATHS = [ "brl/rest/resources", "brl/genboree/rest/resources", "brl/genboree/rest/extensions/*/resources", "brl/genboree/tools/*" ]
  attr_accessor :resourcePaths, :resources
end # Core class defined in advance of class discovery

# ##############################################################################
# REQUIRE CORE INFRASTRUCTURE CLASSES (but only core ones)
# - Will make use of GenboreeRESTRackup class features defined above, if class available at require-time.
# ##############################################################################
require 'brl/rest/resource'
require 'brl/genboree/dbUtil'
require 'brl/genboree/rest/resources/genboreeResource'
require 'brl/genboree/rest/data/entity'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/tools/toolConf'
require 'brl/genboree/kb/mongoKbDatabase'

# ##############################################################################
# DEFINE REST OF METHODS AND DO SOME EXPLICIT CLASS DISCOVERY
# ##############################################################################
class GenboreeRESTRackup
  # CONSTRUCTOR. Makes a Rackup-enabled dispatcher.
  # This method will -dynamically- locate BRL::REST::Resources::Resource classes
  # in a simple, minimum-reflection manner, assuming:
  # 1)  @resourcePaths contains namespace path(s) where files implementing
  #     BRL::REST::Resources::Resource sub-class(es) can be found ; files found
  #     in these paths will be 'required',exposing the sub-classes to Ruby
  # 2)  Namespace paths must result in a real physical file path (.rb optional)
  #     when combined with one of the entries in Ruby's $LOAD_PATH
  # 3)  Sub-classes inherit from BRL::REST::Resource and don't change its interface.
  # 4)  Each resource class resides within the module "BRL::REST::Resources"
  #
  # [+resourcePaths+] : namespace paths to search for BRL::REST::Resources::Resource
  #                     sub-classes
  #                   : default is [ "brl/rest/resources" ]
  #                   : otherwise, the provided locations will each be examined
  #                   : namespace(s) MUST be locatable -somewhere- in $LOAD_PATH
  # _returns_ : instance
  def initialize(resourcePaths=DEFAULT_RESOURCE_PATHS)
    @resourcePaths = resourcePaths
    #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "******************** @resourcePaths\n        #{@resourcePaths.inspect}\n\n")
    loadResources() # Load all resources & tool classes
    File.umask(002)
  end

  # RACKUP INTERFACE. Called by Rackup framework (typically by web server's Rack handler)
  # This method will attempt to dispatch the incoming request by locating a
  # matching BRL::REST::Resources::Resource sub-class to handle the request.
  # [+env+] : [required] When called by Rack handler, it supplies appropriate environment hash.
  # _returns_ A Rack::Response object the Rack handler will use to send response.
  def call(env)
    t1 = Time.now
    req = Rack::Request.new(env)
    defResp = Rack::Response.new()
    resp = Rack::Response.new()
    #$stderr.puts "#{'-'*60}\n#{"*"*30}\nenv:\n#{"*"*30}\n#{env.inspect}\n#{"*"*30}\nRequest: #{req.inspect} ; methods:\n#{JSON.pretty_generate(req.methods.sort)}\nvariables:\n#{JSON.pretty_generate(req.instance_variables.sort)}\n#{'*'*30}\nResponse: #{resp.inspect} ; methods:\n#{JSON.pretty_generate(req.methods.sort)}\nvariables:\n#{JSON.pretty_generate(req.instance_variables.sort)}\n#{'*'*30}\nENV:\n#{"*"*30}\n#{ENV.inspect}\n#{'-'*60}"
    #$stderr.puts "#{'-'*60}\n#{"*"*30}\nenv:\n#{"*"*30}\n#{env.inspect}\n#{"*"*30}\nRequest: #{req.inspect}\n#{'*'*30}\nResponse: #{resp.inspect}\n#{'*'*30}\nENV:\n#{"*"*30}\n#{ENV.inspect}\n#{'-'*60}"
    # Default response is a bad one...ought to be set to successfull response or a ~informative error response:
    respBodyObj = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, :'Internal Server Error', "FATAL: server code failed to verify and process your request. Cannot even give clues as to nature of the error.")
    defResp.body = resp.body = respBodyObj.to_json()
    defResp.status = resp.status = BRL::REST::Resource::HTTP_STATUS_NAMES[:'Internal Server Error']
    defResp['Content-Type'] = resp['Content-Type'] = BRL::Genboree::REST::Data::AbstractEntity::FORMATS2CONTENT_TYPE[:JSON]
    # Locate the first Resource whose pattern indicates the class can handle the request
    uriMatchData = nil
    rsrcClass = GenboreeRESTRackup.resources.find { |resource|
      req.path_info =~ resource.pattern()
      uriMatchData = $~
    }
    
    rsrc = nil
    begin
      # If found a proper rsrcClass and call the appropriate request method
      unless(rsrcClass.nil?)
        rsrc = rsrcClass.new(req, resp, uriMatchData) # Make a new resource handler instance (can be thread safe by not sharing 1 instance)
        unless(rsrc.reqMethod.nil?)
          resp = rsrc.process()
          rsrc.cleanup()  # Aid GC (remove a reference to rsrc obj)
          rsrc = nil
        else # bad request, couldn't get method from request
          resp = prepCoreError(resp, :'Bad Request', "ERROR: Couldn't locate a sensible http request method in received packet. (req method: #{req.request_method})")
        end
      else # no rsrcClass found
        resp = prepCoreError(resp, :'Bad Request', "ERROR: Request URI doesn't indicate an exposed resource or is otherwise incorrect. (req uri path: #{req.path_info.inspect})")
      end
    rescue => err # Ouch, some exception thrown!
      begin
        BRL::Genboree::GenboreeUtil.logError("Fatal Error processing REST http request.", err)
        bktrace = err.backtrace.join("\n")
        resp = prepCoreError(resp, :'Internal Server Error', "FATAL: failed during processing of the request.\n#{err}:\n#{bktrace}")
      rescue => re_err
        # died handling error, so can't try to deal nicely with it...log as simply as possible and let it go
        $stderr.puts "#{'#'*40}\nAPI ERROR: COULDN'T MAKE FATAL RESPONSE TO CLIENT AFTER EXCEPTION CAUGHT\n  Message: #{re_err.to_s}\n  Backtrace:\n" + re_err.backtrace.join("\n") + ('#'*40)
      end
    ensure
      begin
        rsrc.cleanup() if(rsrc)
      rescue => cuErr
        $stderr.puts "#{'#'*40}\nAPI ERROR: COULDN'T CLEANUP RESOURCE FOLLOWING AN ERROR RESPONSE TO CLIENT\n  Message: #{cuErr.to_s}\n  Backtrace:\n" + cuErr.backtrace.join("\n") + ('#'*40)
      end
      rsrc = nil
    end

    if(resp)
      resp['Content-Length'] = resp.body.size.to_s if(resp.body and resp.body.is_a?(String))   # Just to be sure. Resources should set this directly themselves for non-strings (eg files)
      retVal = resp.finish()
    else
      retVal = defResp.finish()
    end
    #$stderr.debugPuts(__FILE__, __method__, ">>>>>", "  Rackup call() finished. Leaving Genboree code. (#{Time.now - t1} sec)")
    return retVal
  end # def call(env)

  # ############################################################################
  # HELPERS
  # ############################################################################
  # Dynamically locates files in @resourcePaths with BRL::REST::Resources::Resource
  # sub-classes and 'requires' the file to make the classes available to Ruby here.
  def loadResources()
    unless(GenboreeRESTRackup.resourcesLoaded or GenboreeRESTRackup.classDiscoveryDone[self.class])
      #$stderr.debugPuts(__FILE__, __method__, "LOAD", "rackup loadResources : LOAD_PATH:\n        #{$LOAD_PATH.inspect}")
      # Mark resources as loaded (so doesn't try again)
      GenboreeRESTRackup.resourcesLoaded = true
      # Record that we've done this class's discovery. Must do before start requiring.
      # - Less important here, since this is the global store of this info, but other classes
      #   should interrogate this Hash before possibily REdoing their class-discovery.
      # - Dependency required while trying to define a class can otherwise result in re-discovery over and over and over.
      GenboreeRESTRackup.classDiscoveryDone[self.class] = true
      # Save any dir-skipping pattern for use elsewhere
      genbConf = BRL::Genboree::GenboreeConfig.load()
      if(genbConf.skipLoadPathPattern and genbConf.skipLoadPathPattern =~ /\S/)
        GenboreeRESTRackup.skipLoadPathPattern = genbConf.skipLoadPathPattern
        GenboreeRESTRackup.skipLoadPathPattern = Regexp.new(GenboreeRESTRackup.skipLoadPathPattern) rescue nil
      else
        GenboreeRESTRackup.skipLoadPathPattern = nil
      end
      # Try to lazy-load (require) each file found in the resourcePaths.
      # We need to ENSURE we will only use the FIRST source file for a given extensionPath.
      # While a given extensionPath source file may be found under multiple topLevel paths,
      # (and consider that the SAME extensionPath may be found via different topLevel paths due to symlinks)
      # the FIRST one is the ONLY one we're allowed to use. This is standard convention for
      # RUBYLIB, PERL5LIB, PYTHONPATH, PATH, LD_LIBRARY_PATH, etc.
      # - Thus, the code below will note in GenboreeRESTRackup.resourceFileMap where a given extension was found.
      #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Resource subdirs: #{@resourcePaths.join("\n")}")
      # Having "." in LOAD_PATH is a security risk, just like having "." in your Unix $PATH (especially for root!)
      # - It has been removed from Ruby 1.9 and above
      # - It definitely makes no sense in a web server (what is "." there? why looking for .rb files wherever "." is?)
      $LOAD_PATH.delete('.')
      $LOAD_PATH.sort.each { |topLevel|
        if(GenboreeRESTRackup.skipLoadPathPattern.nil? or topLevel !~ GenboreeRESTRackup.skipLoadPathPattern)
          #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Looking for Resources in dir: #{topLevel}")
          #$stderr.puts "    * #{Time.now} Toplevel: #{topLevel}"
          @resourcePaths.each { |rsrcPath|
            if(rsrcPath =~ /extension/)
              patt = "#{topLevel}/#{rsrcPath}/*.rb"
              #$stderr.debugPuts(__FILE__, __method__, "DEBUG", "Looking for API extensions using this path pattern: #{patt}")
            end
            rsrcFiles = Dir["#{topLevel}/#{rsrcPath}/*.rb"]
            #$stderr.puts "     - #{Time.now} #{rsrcFiles.size} .rb files found for #{rsrcPath}"
            rsrcFiles.sort.each { |rsrcFile|
              extension = "#{rsrcPath}/#{File.basename(rsrcFile, ".rb")}"
              unless(GenboreeRESTRackup.resourceFileMap[extension])
                begin
                  #$stderr.puts "        . #{Time.now} Loading #{rsrcFile}"
                  require rsrcFile
                  GenboreeRESTRackup.resourceFileMap[extension] = rsrcFile
                rescue Exception => err # just log error and try more files
                  BRL::Genboree::GenboreeUtil.logError("ERROR: #{__FILE__}##{__method__}() => failed to require file '#{rsrcFile.inspect}'. Following exception was raised:", err)
                end
              end
            }
          }
        end
      }
      #$stderr.debugPuts(__FILE__, __method__, "LOAD", "found & required discoverable class files")

      # Find all the classes in BRL::REST::Resources that inherit from BRL::REST::Resources::Resource
      BRL::REST::Resources.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::REST::Resources.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::REST::Resources::Resource
        next unless(const.is_a?(Class) and const.ancestors.include?(BRL::REST::Resource))
        GenboreeRESTRackup.resources << const
      }

      #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "******************** BRL::REST::Extensions.constants:\n\n#{BRL::REST::Extensions.constants.join("\n")}\n\n")
      # Find all the classes in BRL::REST::Extensions::*::Resources name spaces that inherit from BRL::REST::Resources::Resource
      BRL::REST::Extensions.constants.each { |constName|
        # Assess this class/moduel directly in the BRL::REST::Extensions namespace:
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::REST::Extensions.const_get(constNameSym) # Retreive the Constant object
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', ">>> Examining possible API Extension module #{const.inspect}")
        # The constant object must be a Module that has below it the Resources namespace
        if(const.is_a?(Module) and const.constants.include?("Resources"))
          # Dig into the Resources namespace below our found constant (since we know it is there)
          rsrcConst = const.const_get("Resources")
          # Resources namespace at this level must be a module, so let's assert that
          if(rsrcConst.is_a?(Module)) # Now in the Resources area of some Extension.
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', ">>> Possible API Extension module #{const.inspect} is indeed a module AND has a 'Resources' sub-module within.")
            # Examine all the possible Resource classes this Extension implements
            rsrcConst.constants.each { |extRsrcConstName|
              extRsrcConst = rsrcConst.const_get(extRsrcConstName.to_sym)
              # The Resource constant must be a Class must have BRL::REST::Resource as an ancestor, just like core Genboree resource classes do
              if(extRsrcConst.is_a?(Class) and extRsrcConst.ancestors.include?(BRL::REST::Resource))
                #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', ">>> Found API Extension class #{extRsrcConst.inspect}")
                GenboreeRESTRackup.resources << extRsrcConst
              end
            }
          end
        end
      }
      GenboreeRESTRackup.resources.sort! { |aa, bb| bb.priority() <=> aa.priority() }  # sort resources according to their priorities
      #$stderr.debugPuts(__FILE__, __method__, "LOAD", "Registered rest resource classes:\n\n#{GenboreeRESTRackup.resources.join("\n")}\n\n")

      # Find all the tool job helper classes in BRL::Genboree::Tools that inherit from BRL::Genboree::Tools
      BRL::Genboree::Tools.constants.each { |constName|
        constNameSym = constName.to_sym   # Convert constant name to a symbol so we can retrieve matching object from Ruby
        const = BRL::Genboree::Tools.const_get(constNameSym) # Retreive the Constant object
        # The Constant object must be a Class and that Class must inherit [ultimately] from BRL::REST::Resources::Resource
        if(const.is_a?(Class) and const.ancestors.include?(BRL::Genboree::Tools::WorkbenchJobHelper) and const != BRL::Genboree::Tools::WorkbenchJobHelper)
          # Need toolIdStr to determine anything more
          toolIdStr = const::TOOL_ID
          next if(toolIdStr == '[NOT SET]')
          # Get tool config
          toolConf = BRL::Genboree::Tools::ToolConf.new(toolIdStr)
          unless(toolConf.getSetting('ui', 'hidden'))
            GenboreeRESTRackup.tools << { :conf => toolConf, :toolId => toolIdStr, :jobHelperClass => const }
            GenboreeRESTRackup.toolMap[toolIdStr] = {:conf => toolConf, :jobHelperClass => const }
            GenboreeRESTRackup.toolIdMap[toolIdStr] = toolConf.conf['ui']['label']
          end
        end
      }
      GenboreeRESTRackup.tools.sort! { |aa, bb| aaLabel = aa[:conf].conf['ui']['label']; bbLabel = bb[:conf].conf['ui']['label'] ; retVal = (aaLabel.downcase <=> bbLabel.downcase) ; (retVal = (aaLabel <=> bbLabel)) if(retVal == 0) ; retVal }
      #$stderr.debugPuts(__FILE__, __method__, "LOAD", "registered tool classes")
      BRL::ActiveSupport.restoreJsonMethods()
    end
    #$stderr.debugPuts(__FILE__, __method__, "LOAD", "rackup loaded resources")
  end

  # Prepare an error response that communicates a fundamental problem with the
  # request, including cases where the API code itself threw an exception.
  # - rather than the expected representation, a generic respresentation is returned
  #   in this disaster-handling case with appropriate content
  def prepCoreError(resp, errSym, errMsg)
    respBodyObj = BRL::Genboree::REST::Data::AbstractEntity.new(false, true, errSym, errMsg)
    resp.body = respBodyObj.to_json()
    resp.status = BRL::REST::Resource::HTTP_STATUS_NAMES[errSym]
    resp['Content-Length'] = resp.body.size.to_s
    resp['Content-Type'] = 'application/json'
    return resp
  end
end # class GenboreeRESTRackup
