#!/usr/bin/env ruby
# Script for adjusting track attributes based on regular expression rules.
# Currenlty juts changing color of the tracks by doing pattern matching 
# author : Arpit Tandon 

require 'ap'
require 'json'
require 'socket'
require 'rubygems'
require 'brl/db/dbrc'
require 'highline/import'
require 'brl/genboree/rest/apiCaller'
include BRL::Genboree::REST


class ColorApi
    # Global variable for making hash table (from the provided input file) for regexp as key and colors as value
    $regexpTable = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
    $tracks = []
    $hexColor = 0
    $passWord = ""
    
    def initialize(optsHash)
        @groupName  = optsHash['--groupName']
        @db         = optsHash['--db']
        @host       = optsHash['--host']
        @regexpFile = optsHash['--regexpFile']
        @userName   = optsHash['--userName']
        @dbrcKey    = optsHash['--dbrcKey']
        @dbrcFile   = optsHash['--dbrcFile']
        
        
        ## Some checks to prevent ambiguity
        if((optsHash.key?('--userName') or optsHash.key?('--host')) and (optsHash.key?('--dbrcKey')))
            $stderr.puts "\nError :     For authentication, either .dbrc file can be used or you may provide
            information(username and hostname). But both wouldn't be accpeted. Either provide username and host name only without
            dbrcKey or just provide dbrcKey\n\n"
            exit
        end
        
        
        ## Pulling information from .dbrc file from different paths
        if(optsHash.key?('--dbrcKey'))
            begin
            if(optsHash.key?('--dbrcFile'))
                if(!File.exists?(optsHash['--dbrcFile']))
                    $stderr.puts "\n\n Error :.dbrc file is not present at #{optsHash['--dbrcFile']} \n\n"
                    exit
                end
                dbrc = BRL::DB::DBRC.new(@dbrcFile, @dbrcKey)
            elsif(ENV.key?('DBRC_FILE'))
                dbrc = BRL::DB::DBRC.new(ENV['DBRC_FILE'], @dbrcKey)
            elsif(ENV.key?('DB_ACCESS_FILE'))
                dbrc = BRL::DB::DBRC.new(ENV['DB_ACCESS_FILE'], @dbrcKey)
            elsif
                if(File.exists?(File.expand_path("~/.dbrc")))
                    dbrc = BRL::DB::DBRC.new(File.expand_path("~/.dbrc"), @dbrcKey)
                else
                    $stderr.puts "\nError: Plz check the .dbrc file location\n\n"
                    exit
                end
            end
            rescue
                $stderr.puts "\nError : #{@dbrcKey} KEY doesnt exist in .dbrc file\n\n"
                exit
            end
            
            @userName = dbrc.user
            $passWord = dbrc.password
            @host = dbrc.driver.split(/:/).last
        end
    end

  # Process Arguements form the command line input
  def ColorApi.processArguements()
    # We want to add all the prop_keys as potential command line options
      optsArray = [ ['--groupName'  , '-g', GetoptLong::REQUIRED_ARGUMENT],
                    ['--db'         , '-d', GetoptLong::REQUIRED_ARGUMENT],
                    ['--host'       , '-o', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--regexpFile' , '-f', GetoptLong::REQUIRED_ARGUMENT],
                    ['--userName'   , '-u', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--dbrcKey'    , '-k', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--dbrcFile'   , '-F', GetoptLong::OPTIONAL_ARGUMENT], 
                    ['--help'       , '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      ColorApi.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty? )
      optsHash = progOpts.to_hash
      if(!optsHash.key?('--dbrcKey'))
          unless(optsHash.key?('--host') and optsHash.key?('--userName'))
               ColorApi.usage("USAGE ERROR: Either host name and user name is missing or dbrc key is missing")
          end
          
      end
      ColorApi if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
  end
  
   # Password Settings
   def ColorApi.passW(passWord)
      $passWord = passWord
   end
   
  
  # Builds connection with gemboree and extracts the required info and make a hash 
  def work()
    apiCaller = ApiCaller.new("", "", @userName, $passWord)
    apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trks?connect=no")
   begin
    apiCaller.setHost(@host)
        apiCaller.get({ :grp => @groupName, :db => @db})
    rescue SocketError  => e
        $stderr.puts "\nError: Host name is not correct\n\n"
    end
    apiCaller.parseRespBody
    unless ( apiCaller.parseRespBody["status"]["msg"].eql?('OK'))
            if(apiCaller.parseRespBody["status"]["msg"] =~/BAD\_TOKEN/)
                $stderr.puts " Wrong Password"
            elsif(apiCaller.parseRespBody["status"]["msg"] =~/NO\_USR/)
                $stderr.puts " Wrong Username"
            elsif(apiCaller.parseRespBody["status"]["msg"] =~/NO\_DB/)
                $stderr.puts "Wrong DataBase or group"
            elsif(apiCaller.parseRespBody["status"]["msg"].eql?('FORBIDDEN'))
                $stderr.puts apiCaller.parseRespBody["status"]["msg"]
            else
                puts apiCaller.parseRespBody["status"]["msg"]
            end
        exit
    end
    apiCaller.apiDataObj
    apiCaller.respBody

    
    # Making array of the all track names available in the database
    puts "Processing file and validating the attributes and their values...."
    #tracks = []
    apiCaller.apiDataObj.each { |trackRec|
      $tracks << trackRec['text']
      }
    # Calling method for reading the regexp input file and making hash table of regex and colors
    ColorApi.fileRead(@regexpFile)

    puts "\n"
    puts "------"
    puts "\n"
    puts "Results "
    puts "\n"
    # Traversing over the track names and matching them with regular expresion and changing color
    # accordinlgy
    $tracks.each { |ii|
    # Just for information, we are making hash of hash of hash from the regexp file.
    # In order to keep easy and consistent naming convention, the 'k' and 'v' are used for
    # representing key and value, respectively followed by their depth in hash. Ex- k1 and v1 means,, 1st level
    # key and value and so on...
    checkMatch = 0
      $regexpTable.each { |k1 , v1|
          if(ii =~ /#{k1}/)
              puts "TRACK: " + ii
            v1.each { |k2 , v2|
                    # Storing value of attribute                
                    val = $regexpTable[k1][k2]["value"]
    
                # Checks for non custom trakcs
                if( k2 !~ /gb/ )
                    apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trk/{trk}/#{k2}")
                    payLoad = {"data" => { "text" => val } }
                    payLoadStr = payLoad.to_json
                    apiCaller.put( { :grp => @groupName, :db => @db, :trk => ii }, payLoadStr )
                    if(!apiCaller.succeeded?)
                        apiCaller.parseRespBody ; puts "\nERROR: couldn't set #{k2} for #{ii.inspect}. Code: #{apiCaller.apiStatusObj['statusCode']}. Msg: #{apiCaller.apiStatusObj['msg']}\n\n"
                    else
                       puts "- \t#{ii.inspect}'s #{k2} has changed to #{val}"
                    end
                
                # Checks for custom track
                elsif ( k2 =~ /gb/ )
                    apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/#{k2}/value")
                    payLoad = {"data" => { "text" => val } }
                    payLoadStr = payLoad.to_json
                    apiCaller.put( { :grp => @groupName, :db => @db, :trk => ii }, payLoadStr )
                    if(!apiCaller.succeeded?)
                        apiCaller.parseRespBody
                        puts "\nERROR: couldn't set #{k2} for #{ii.inspect}. Code: #{apiCaller.apiStatusObj['statusCode']}. Msg: #{apiCaller.apiStatusObj['msg']}\n\n"
                    else
                       puts "- \t#{ii.inspect}'s #{k2} has changed to #{val}"
                    end
                end
                
                # Sets the display setting if there is any..
                v2.each { | k3 ,v3 |
                    unless(k3.eql?('value'))
                        colorDisp  = $regexpTable[k1][k2][k3][0]
                        if(ColorApi.color(colorDisp) == 1)
                            colorDisp = $hexColor
                       
                            rankDisp   = $regexpTable[k1][k2][k3][1]
                            if(ColorApi.rank(rankDisp) == 1)
                
                                flagsDisp  = $regexpTable[k1][k2][k3][2]
                                if(flagsDisp =~/[0|1]/)
                                
                                    apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/#{k2}/#{k3}")
                                    apiCaller.get( { :grp => @groupName, :db => @db, :trk => ii } )
                                    storeValues = apiCaller.parseRespBody
                                    prevFlag = storeValues["data"]["flags"]
                                    
                                         
                                    sleep(1)
                                    payLoad = { "data" => { "color" =>  colorDisp,"rank" => rankDisp, "flags" => flagsDisp } }
                                    payLoadStr = payLoad.to_json
                                    apiCaller.put( { :grp => @groupName, :db => @db, :trk => ii }, payLoadStr )
                                    if(!apiCaller.succeeded?)
                                        apiCaller.parseRespBody ; puts "\nERROR: couldn't set #{k3} for #{ii.inspect}'s attribute '#{k2}' . Code: #{apiCaller.apiStatusObj['statusCode']}. Msg: #{apiCaller.apiStatusObj['msg']}\n\n"
                                    else
                                        puts "- \t#{ii.inspect}'s attribute '#{k2}''s #{k3} has changed"
                                    end
                                else
                                    $stderr.puts "Error: the #{flagsDisp} (display flag ) value is invalid. It should be either 0 or 1 \n\n"
                                end
                                
                            else
                                $stderr.puts "Error : the #{rankDisp} (display rank) format is invalid. It should be Fixnum\n\n"
                            end
                            
                         else
                            $stderr.puts "Error:  : the #{colorDisp} format is invalid \n\n"
                        end
                                
                    end                              
                }             
            }
            checkMatch = 1
            break;
        end
        if( checkMatch == 0)
          $stderr.puts "#{ii.inspect} didnt match with any regular expression \n"
        end
        }
      }
  end
  
  # validates specific core "Class" field's value
  def ColorApi.classes(cls)
      classValues = ["Genes", "Regulatory", "Disease-Associated"]
      if( classValues.include?(cls))
          return 1
      else
          return 0
      end
    end
    
  # Validates specific core "url/urlLabel" field's value
  def ColorApi.url(url)
      if( url.class != "String")
            return 0
      else
            return 1
      end
  end
  
  
  # Validates specific core "description" fields's value
  def ColorApi.description(desc)
      if( desc.class != "String" and desc !~ /\n/)
            return 0
      else
            return 1
      end
  end
  
  # Validates specific core "style/defaultStyle" field's value
  def ColorApi.style(style)
      
        values = [  "Simple Rectangle",                  
                    "Paired-End",                       
                    "Boxed Group",                      
                    "Line-Linked",                     
                    "Anchored Arrows",                   
                    "Half Paired-End",                  
                    "Global Score Barchart (small)",    
                    "Barbed-Wire Rectangle",           
                    "Label Within Rectangle",          
                    "Global Score Barchart (big)",      
                    "Simple Rectangle With Gaps",   
                    "Line-Linked With Gaps",            
                    "Score Colored (fade to white)",    
                    "Score Colored (fade to gray)",      
                    "Score Colored (fade to black)",    
                    "Score Colored (fixed colors)",      
                    "Barbed-Wire Rectangle (no lines)",  
                    "Score Pie Chart",                   
                    "Local Score Barchart (small)",      
                    "Local Score Barchart (big)",        
                    "Line-Linked with Sequence",         
                    "Global Bidirectional Barchart",  
                    "Local Bidirectional Barchart"    ]
                           
        if( values.include?(style) and style.class.eql?(String))
            return 1
        else
            return 0
        end
  end
  
  
  # Validates specific core "color/defaultColor" field's value
  def ColorApi.color(color)
      
      if(color =~ /\,/)
          col = color.split(/\,/)	
          if((col[0].to_i <0 or col[0].to_i > 255) or (col[1].to_i <0 or col[1].to_i > 255) or (col[2].to_i <0 or col[2].to_i > 255))
           # puts "Error: the color format is invalid at line num #{lineNum} ----#{line}\n"
            return 0
          else
            rr = (col[0]).to_i.to_s(16)
            if( rr.size == 1)
              rr = "0" + rr
            end
            gg = col[1].to_i.to_s(16)
            if ( gg.size == 1)
              gg = "0" + gg
            end
            bb = col[2].to_i.to_s(16)
            if ( bb.size == 1)
              bb = "0" + bb
            end        
            $hexColor = '#' + rr.to_s + gg.to_s + bb.to_s
            return 1
          end
      else
          if(color =~ /^#[0-9A-F]{6,6}/i and color.size ==7)
                $hexColor = color
                return 1
          else
            #    puts "Error: the color format is invalid at line num #{lineNum} ----#{line}\n"
                return 0
            end
        end
  end
  
    # Validates specific core "display/defaultDisplay" field's value
    def ColorApi.display(disp)
        values = %w[Expand
                    Compact
                    Hidden
                    Multicolor
                    Expand with Names
                    Expand with Comments]
        disp = disp.capitalize
        if(values.include?(disp) and disp.class.eql?(String))
            return 1
        else
            return 0
        end
    end
    
    # Validates specific core "rank/defaultRank" field's value
    def ColorApi.rank(rank)
        if( rank =~ /[0-9]+/ )
            return 1
        else
            return 0
        end
    end
    
    # Validates non-core "gbTrackPxHeight" field's value
    def ColorApi.gbTrackPxHeight(height)
           if( height =~ /[0-9]+/)
            return 1
        else
            return 0
        end
    end
    
    # Validates non-core "gbTrackUseLog" field's value
    def ColorApi.gbTrackUseLog(log)
        if( log.eql?('True') or log.eql?('False'))
            return 1
        else
            return 0
        end
    end
        
    # Validates non-core "gbTrackUserMax/gbTrackUserMin" field's value
    def ColorApi.gbTrackUserM(val)
        if(val =~/[0-9]*\.?[0-9]+/)
            return 1
        else
            return 0
        end
    end
    
    # Validates non-core "gbTrackWindowingMethod" field's value
    def ColorApi.gbTrackWindowingMethod(val)
        if(val == "AVG" or val == "MIN" or val == "MAX")
            return 1
        else
            return 0
        end
    end
    
    # Validates non-core "gbTrackPxScoreUpperThreshold/gbTrackPxScoreLowerThreshold/gbTrackPxScoreUpperNegativeThreshold
    # /gbTrackPxScoreLowerNegativeThreshold/gbTrackYIntercept" field's value
    def ColorApi.gbTrackPxScoreThreshold(val)
        if(val =~/[0-9]*\.?[0-9]+/)
            return 1
        else
            return 0
        end
    end
    
  
  # Reading regexpFile and making hash of hash (its regexp => attribute => value )
  def ColorApi.fileRead(fileName)
    reader = BRL::Util::TextReader.new(fileName)
    if(File::size(reader) <=0 )
      puts "Error: The file is null\n"
    else
    lineNum = 0
    reader.each { |line|
        line.strip!
        lineNum += 1
        
        # Using JSON.parse to read the file (which is in Json format) and make
        # data structure in ruby. Its easy. SO making Hash of Hash of Hash
        row = JSON.parse(line)
        row.each { | key ,value |
                value.each { | k1 , v1 | 
                if row[key][k1].is_a?(String)
                    $regexpTable[key][k1]["value"] = v1
                    else row[key][k1].is_a?(Hash)
                    v1.each{ | k2, v2 |
                        $regexpTable[key][k1][k2] = v2
                    }               
                end
                }
        }
        
            
        # Verifying the attribute values from the above ruby data structure (hash of hash of hash)
        # and removing all those enteries which are invalid and displaying the error message
        $regexpTable.each { | k1 , v1 |
            v1.each { | k2, v2 |
                v2.each { | k3 , v3 |
                value = $regexpTable[k1][k2]["value"]
                if(k2 =~/class/i)
                    value = value.capitalize
                    if(ColorApi.classes(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                        $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /color/i)
                    if(ColorApi.color(value) == 1)
                        $regexpTable[k1][k2]["value"] = $hexColor
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /url/i)
                    if(ColorApi.url(value) == 1)
                       $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /description/i)
                   if(ColorApi.description(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                   else
                        $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /style/i)
                    if(ColorApi.style(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /display/i)
                   if(ColorApi.display(value) == 1)
                        $regexpTable[k1][k2]["value"] = value.capitalize
                   else
                        $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~ /rank/i)
                    if(ColorApi.rank(value) == 1)
                       $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                       $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~/gbTrackPxHeight/i )
                    if(ColorApi.gbTrackPxHeight(value) == 1)
                        $regexpTable[k1][k2]["value"]= value
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~/gbTrackUseLog/i )
                    value = value.capitalize
                    if(ColorApi.gbTrackUseLog(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                       $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~/gbTrackUser/i )
                    if(ColorApi.gbTrackUserM(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~/gbTrackWindowingMethod/i )
                    value = value.upcase
                    if(ColorApi.gbTrackWindowingMethod(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                       $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                
                if(k2 =~/gbTrackPxScore/i or k2 =~/gbTrackYIntercept/i )
                    if(ColorApi.gbTrackPxScoreThreshold(value) == 1)
                        $regexpTable[k1][k2]["value"] = value
                    else
                         $regexpTable[k1].delete(k2)
                        $stderr.puts "Error:  : the #{k2} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                end
                }
            }
                       
        }
                
    }
    end
    
    reader.close
  end
  

 # Display usage info and quit.
  def ColorApi.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    This is the advanced verison of 'trackColor.rb' script.
    Adjusts track attributes alongwith their display option on the browser, based on regular expression rules.
    Install 'highline' gem, if not in system. This gem is required to get the password from the user while hiding it.
   
  COMMAND LINE ARGUMENTS:
    --groupName        | -g => Group name.
    --db               | -d => Database name.
    --host             | -o => Host name.
    --regexpFile       | -f => Tab-delimited file with 1st column as regexp and
                               2nd column as hex RGB color
    --userName         | -u => Genboree username/login
    --dbrcKey          | -k => dbrc key to pull out information (username, password and host name from .dbrc file)
    --dbrcFile         | -F => [Optional] location of dbrc file
    --help             | -h => [Optional flag]. Print help info and exit.

  USAGE:
  Providing authetication information from command line
  trackAttribute.rb -f REGEXP.file -u USERNAME -d DATABASE_NAME -g GROUP_NAME -o HOST_NAME
  
  using .dbrc file for authentication
  trackAttribute.rb -f REGEXP.file  -d DATABASE_NAME -g GROUP_NAME -k KEY_NAME -F DRBC_FILE
  
  PS:--Either username and host name can be given from command prompt or only DBRCkeyname can be give. If both are
  given toether, it will be rejected. DBRC file path is optional.
  
  
  Note ---the REGEXP.file MUST have complete and well formatted JSON strings for each regexp.
  
  ex -
  {'annos:sel' :{ 'gbTrackWindowingMethod' :{ 'value' : 'Avg' , 'display' : [ '#FF0000', '1' , '0' ] }, 'gbTrackUserMin' :  '43' , 'gbTrackUseLog' : { 'value' : 'False', 'defaultDisplay' : ['#006F90' ,'2', '1' ] } } } 

  Above example represents only one regexp line from the REGEXP.file.
  'annos:sel' is the regexp. Ita a key.
  'gbTrackWindowingMethod', 'gbTrackUserMin' and 'gbTrackUseLog' are different attributes of which, values are to be changed. These are values for the above key.
  'value' and 'display' are the tags to provide info about the attribute value and display settings. These are values to the above key.
  'display''s value should be in array form with [ COLOR, RANK and FLAG ]. and the values in this array should be complete.
   
  Note--- If 'display' settings are not given, usage of 'value' tag is optional.
    
  ";
      exit  ;
  end # 
end # 


#######################################################################################
# MAIN
#######################################################################################

# Process command line options
optsHash =  ColorApi.processArguements()
if(optsHash.key?('--dbrcKey'))
    color = ColorApi.new(optsHash)
    color.work

else
    passWord = ask("Enter Password: ") { |q| q.echo = false }
    ColorApi.passW(passWord)
    color = ColorApi.new(optsHash)
    color.work
end
