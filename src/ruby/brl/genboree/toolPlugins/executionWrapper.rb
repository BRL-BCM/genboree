#!/bin/env ruby

# Matthew Linnell
# January 11th, 2006
#-------------------------------------------------------------------------------
# This is the main wrapper that manages communication between Genboree
# and the Pattern Discvoery toolset
#-------------------------------------------------------------------------------
require 'cgi'
require 'getoptlong'
require 'brl/util/util'
require 'brl/genboree/toolPlugins/tools/tools'
require 'brl/genboree/toolPlugins/util/util'
require 'brl/genboree/toolPlugins/util/binaryFeatures'
require 'brl/genboree/toolPlugins/wrappers'
include BRL::Genboree::ToolPlugins
include BRL::Genboree::ToolPlugins::Util
include BRL::Genboree::ToolPlugins::Tools

module BRL ; module Genboree ; module ToolPlugins

class ExecutionWrapper
    #---------------------------------------------------------------------------
    # Get a list of all available tools
    #---------------------------------------------------------------------------
    def self.list()
        BRL::Genboree::ToolPlugins::Tools.list()
    end

    #---------------------------------------------------------------------------
    # Return the hash of available binary representation schemes
    #---------------------------------------------------------------------------
    def self.binary_list()
        BRL::Genboree::ToolsPlugins::Util::BinaryFeatures.functions
    end

    #---------------------------------------------------------------------------
    # Print out usage information based on tool/function
    #---------------------------------------------------------------------------
    def self.usage( tool=nil, function=nil )
        # If tool/function nil, report available tools/functions
        msg = ""
        if( tool.nil? )
            msg << "\n    Usage: executionWrapper.rb --tool=toolname --function=functionname [function options]\n"
            msg << "\n    The following tools are available:\n\n"
            self.list.each_key { |key, val|
                msg << "\t#{val[:title]} - #{val[:desc]}\n"
                val[:functions].each_pair{ |name, func|
                    msg << "\t  #{name}: #{func[:desc]}\n"
                }
            }
            msg << "\n    For details on a specific tool/function, pass --tool=toolname and/or --function==functionname\n"
            msg << "\nExample:\n    ruby executionWrapper.rb --tool=winnow --function=train --binary=basic_kmer --kmer=6 --positive_track=/scratch/filename.lff --negative_track=/scratch/filename.lff\n\n"
        elsif(function.nil?) # Otherwise, report usage for given tool/function
            tool_const = BRL::Genboree::ToolPlugins::Tools.list()[tool]
            msg = "  TOOL NAME: #{tool_const.about[:title]}\n" +
                  "  TOOL DESC: #{tool_const.about[:desc]}\n\n" +
                  "    AVAILABLE FUNCTIONS:\n"

            tool_const.functions.each_pair { |key, val|
              msg << "      --#{key} => #{val[:desc]}\n"
            }
            msg << "\n"
        else
            tool_const = BRL::Genboree::ToolPlugins::Tools.list()[tool]
            puts "executionWrapper.rb#usage(): function is nil! '#{function}' tool '#{tool}'" if(function.nil?)
            func_options = tool_const.functions[function.to_sym]
            inputs  = func_options[:input]
            msg = "  TOOL NAME: #{tool_const.about[:title]}\n" +
                  "  TOOL DESC: #{tool_const.about[:desc]}\n\n" +
                  "    AVAILABLE FUNCTIONS:\n"

            inputs.each_pair do |key, val|
                msg << "      --#{key} => #{val[:desc]}\n"
            end
            msg << "\n"
        end
        return msg
    end

    #---------------------------------------------------------------------------
    # Execute the analysis based on current user input
    # options is a Hash whose values are:
    #   :tool     => The name of the tool to use
    #   :function => Which function of the tool to use
    #   :input    => A hash of inputs for this tool/function
    #---------------------------------------------------------------------------
    def self.execute( options )
      # This is dumb and convoluted:
      # tool     = Object.const_get( options[:tool] ).new
      # Get tool class by reusing the tools.rb list() method of registered tools
      tool = BRL::Genboree::ToolPlugins::Tools.list()[options[:tool]].new
      function = options[:function]
      # Validate input parameters
      validate_input( options )

      # Check lock file for permission to start
      lockFile = File.open(BRL::Genboree::ToolPlugins::PLUGIN_LOCK_FILE, "w+")
      lockFile.getLock() # When returns, you got a lock; otherwise it sleeps

      # Now that all the data is prepped, send it off to be process by selected tool/function
      tool.send( function, options[:inputs] )
    end

    #---------------------------------------------------------------------------
    # Validate the user input based on the tool and function
    # Everything must, at the minimum, have
    #   :tool     => The name of the tool to be used
    #   :function => The name of said tools function to be used
    #---------------------------------------------------------------------------
    def self.validate_input( options )
      # This is dumb and convoluted:
      # tool = Object.const_get( options[:tool] )
      # Get tool class by reusing the tools.rb list() method of registered tools
      tool = BRL::Genboree::ToolPlugins::Tools.list()[options[:tool]]
      function = options[:function]
      raise( ArgumentError, "Missing argument: 'tool'" ) unless(options.key?( :tool ))
      raise( ArgumentError, "Missing argument: 'function'" ) unless(options.key?( :function ))
      puts "executionWrapper#validate_input(): function is nil? '#{function}' tool is '#{tool}'" if(function.nil?)
      tool.functions()[function.to_sym][:input].each_pair { |inputName, inputHash|
          # Don't enforce inputs--tool does enforcement
          # raise( ArgumentError, "Missing argument: --#{inputName}" ) unless(options[:inputs].key?( inputName ))
          # The presence of an input can mean there must be additional inputs
          # as well.  For example, --binary=basic_kmer requires --kmer=6
          if(inputHash[:extras])
              puts "executionWrapper#validate_input(): options[:inputs] is nil? inspect:\n\n#{options.inspect}\n\ntool is '#{tool}'"
              extra_args = inputHash[:extras][ (options[:inputs][inputName]).to_sym ][:inputs].keys
              extra_args.each { |new_input|
                  raise( ArgumentError, "--#{inputName}=#{options[:inputs][inputName]} requires missing argument: --#{new_input}" ) unless(options[:inputs][new_input])
              }
          end
      }
      return true
    end
end

# Process the command line arguments
def process_arguments()
    opts = Hash.new
    ARGV.each { |aa|
        aa =~ /\A--([^=]+)=(.+)\Z/m
        commandArg, val = $1, $2
        # Do url-unescaping if it looks like the value has at least one actual %-style url encoded value.
        val = CGI.unescape(val) if(!val.nil? and val =~ /%[0-9a-fA-F][0-9a-fA-F]/)
        if(commandArg.nil?)
          puts "ERROR: executionWrapper#process_arguments(): bad original command arg: '#{aa}' "
          next
        else
          argSymbol = commandArg.to_sym
        end
        opts[ argSymbol ] = (val.nil? ? nil : val )
    }
    return opts
end

end ; end ; end

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
begin
    EW = BRL::Genboree::ToolPlugins::ExecutionWrapper

    # Snag Standard Input Parameters
    opts = process_arguments()
    puts "EW called with these opts:\n\n#{opts.inspect}\n\n"
    if( opts.key?(:help) or opts.empty? or !opts.key?(:tool) )
        puts EW.usage()
        exit
    elsif( opts.key?(:"binary-list") )
        puts "\n    AVAILABLE BINARY REPRESENTATIONS:\n\n"
        EW.binary_list().each_pair{ |key, val|
            puts "        #{key} => #{val[:desc]}"
            val[:inputs].each_pair{ |name,desc| puts "          --#{name} => #{desc}" }
            puts
        }
        puts
        exit
    elsif( !opts.key?(:function) )
        puts EW.usage( opts[:tool].to_sym )
        exit
    end

    # Now Snag the tool/function specific parameters
    options = Hash.new
    origTool = opts[:tool]
    refSeqId = opts[:refSeqId]
    # Dumb and convoluted:
    #options[:tool] = opts.delete(:tool).capitalize + "Tool"
    # New approach reuses the tool.rb list() function to look up the registered tool
    # using options[:tool].
    options[:tool] = opts.delete(:tool).to_sym
    options[:function] = opts.delete(:function)
    functionSym = options[:function].to_sym
    options[:inputs] = opts

    # Provide extra info if no other options are passed other than tool and function
    if(opts.empty?)
        puts EW.usage( options[:tool], options[:function] )
        exit
    end
    # Validate Inpute Parameters
    EW.validate_input( options )
    # Execute algorithm.
    # The return value is expected to be a list of files (FULL file paths as strings) that need to be cleaned up
    fileDeleteList = EW.execute( options )
    # Linkify the results so they are available to apache
    BRL::Genboree::ToolPlugins::Util.linkify( origTool, options[:function], options[:inputs][:groupId], refSeqId, options[:inputs][:expname] )
    
    #Don't send email prematurely if the tool is actually running on a cluster    
    if(BRL::Genboree::ToolPlugins::Tools.list[options[:tool]].respond_to?("runsOnCluster?")) then      
      if(!BRL::Genboree::ToolPlugins::Tools.list[options[:tool]].runsOnCluster?) then        
         BRL::Genboree::ToolPlugins.email( options[:inputs][:userId], BRL::Genboree::ToolPlugins::Tools.list[options[:tool]], functionSym, options[:inputs][:expname] )
      end
    else      
      BRL::Genboree::ToolPlugins.email( options[:inputs][:userId], BRL::Genboree::ToolPlugins::Tools.list[options[:tool]], functionSym, options[:inputs][:expname] )
    end
    

    # Finally, cleanup tmp directory used by LFF files
    # cleanup_files( fileDeleteList )
rescue => err
    errmsg = "There was an error processing your request for\n"
    begin
      if(!options.nil?)
        $stderr.puts "options[:tool] => " + options[:tool].inspect
        $stderr.puts "functionSym => " + functionSym.inspect
        toolClass = BRL::Genboree::ToolPlugins::Tools.list[options[:tool]]
        functionInfo = toolClass.functions()[functionSym]
        $stderr.puts "functionInfo => " + functionInfo.inspect
        toolLabel = functionInfo[:displayName]
        errmsg += "the Genboree tool labelled '#{toolLabel}'\nfor experiment name\n  "
        if(!options[:inputs].nil?)
          errmsg += " '#{options[:inputs][:expname]}'.\n\n"
        else
          errmsg += "options doesn't have an :inputs key, see\n\n#{options.inspect}\n\n"
        end
      else
        errmsg += "options are nil ??"
      end
      errmsg += "You may have provided an invalid set of parameters\nor the tool cannot be ruqqn on your particular dataset.\n\nPlease check the error details at the end of this email and\nresubmit your job after making corrections.\n\n"
      errmsg += "If you continue to have problems, you may contact us at genboree_admin@genboree.org.\nMake sure to include the contents of this email for reference.\n\n"
      errmsg += "ERROR DETAILS:\n#{err.message}\n"
      BRL::Genboree::ToolPlugins.email( options[:inputs][:userId], BRL::Genboree::ToolPlugins::Tools.list[options[:tool]], functionSym, options[:inputs][:expname], errmsg )
      $stderr.puts "\n\nERROR: encountered a problem.\n  Error Message: '#{err.message}'\n  Error trace:\n'" + err.backtrace.join("\n") + "'\n\n"
    rescue => innerErr
      $stderr.puts "ERROR: serious problem occurred. Can't even collect standard information about request."
    ensure
      raise err
    end
end
