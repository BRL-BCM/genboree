#!/usr/bin/env ruby
# Script for adjusting track attributes based on regular expression rules.
# Currenlty juts changing color of the tracks by doing pattern matching 

require 'ap'
require 'json'
require 'socket'
require 'rubygems'
require 'brl/db/dbrc'
require 'highline/import'
require 'brl/genboree/rest/apiCaller'
require 'brl/genboree/genboreeUtil'
include BRL::Genboree::REST


class ColorApi
    # Global variable for making hash table (from the provided input file) for regexp as key and colors as value
    $regexpTable = {}
    $passWord = ""
    $nonCustomTrack = %w[url urlLabel description style defaultStyle color defaultColor display defaultDisplay rank defaultRank]
    
    def initialize(optsHash)
    @groupName  = optsHash['--groupName']
    @db         = optsHash['--db']
    @host       = optsHash['--host']
    @regexpFile = optsHash['--regexpFile']
    @userName   = optsHash['--userName']
    @dbrcKey    = optsHash['--dbrcKey']
    @dbrcFile   = optsHash['--dbrcFile']
    
    if(optsHash.key?('--attribute'))
        @attribute = optsHash['--attribute']
    else
        @attribute = 'color'
    end
        
        
        ## Some checks to prevent ambiguity
        if((optsHash.key?('--userName') or optsHash.key?('--host')) and (optsHash.key?('--dbrcKey')))
            $stderr.puts "\nError :     For authentication, either .dbrc file can be used or you may provide
            information(username and hostname). But both wouldn't be accpeted. Either provide username and host name only without
            dbrcKey or just provide dbrcKey\n\n"
            exit
        end
        
        
        ## Pulling information from .dbrc file
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
                    ['--attribute'  , '-a', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--dbrcKey'    , '-k', GetoptLong::OPTIONAL_ARGUMENT],
                    ['--dbrcFile'   , '-F', GetoptLong::OPTIONAL_ARGUMENT], 
                    ['--help'       , '-h', GetoptLong::NO_ARGUMENT]
                  ]
      progOpts = GetoptLong.new(*optsArray)
      ColorApi.usage("USAGE ERROR: some required arguments are missing") unless(progOpts.getMissingOptions().empty?)
      optsHash = progOpts.to_hash
      if(!optsHash.key?('--dbrcKey'))
          unless(optsHash.key?('--host') and optsHash.key?('--userName'))
               ColorApi.usage("USAGE ERROR: Either host name and user name is missing or dbrckey is missing")
          end 
      end
      ColorApi if(optsHash.empty? or optsHash.key?('--help'));
      return optsHash
    end
  
  def ColorApi.passW(passWord)
      $passWord = passWord
  end
  
  # Builds connection with gemboree and extracts the required info and make a hash 
  def work()
    apiCaller = ApiCaller.new("", "", @userName, $passWord)
    apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trks?connect=no")
    apiCaller.setHost(@host)
    apiCaller.get({ :grp => @groupName, :db => @db})
    unless ( apiCaller.parseRespBody["status"]["msg"].eql?('OK'))
            if(apiCaller.parseRespBody["status"]["msg"] =~/BAD\_TOKEN/)
                puts "Wrong Password"
            elsif(apiCaller.parseRespBody["status"]["msg"] =~/NO\_USR/)
                puts "Wrong Username"
            elsif(apiCaller.parseRespBody["status"]["msg"] =~/NO\_DB/)
                puts "Wrong DataBase or group"
            elsif(apiCaller.parseRespBody["status"]["msg"].eql?('FORBIDDEN'))
                $stderr.puts apiCaller.parseRespBody["status"]["msg"]
            else
                puts apiCaller.parseRespBody["status"]["msg"]
            end
        exit
    end
    apiCaller.parseRespBody
    apiCaller.apiDataObj
    apiCaller.respBody

    
    # Making array of the all track names available in the database
    puts "Processing...."
    tracks = []
    apiCaller.apiDataObj.each { |trackRec|
      tracks << trackRec['text']
      }
    # Calling method for reading the regexp input file and making hash table of regex and colors
    fileRead(@regexpFile)

    # Traversing over the track names and matching them with regular expresion and changing color
    # accordinlgy
    tracks.each { |ii|
        checkMatch = 0
      $regexpTable.each { |key, value|
        
         if(ii =~ /#{key}/)
            if($nonCustomTrack.include?(@attribute))
                apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trk/{trk}/#{@attribute}")
            else
                apiCaller.setRsrcPath("/REST/v1/grp/{grp}/db/{db}/trk/{trk}/attribute/#{@attribute}/value")
            end
            
            payLoad = { "data" => { "text" => value} }
            payLoadStr = payLoad.to_json
            # Changing the colors accordingly in the host 
            apiCaller.put( { :grp => @groupName, :db => @db, :trk => ii }, payLoadStr )
if(!apiCaller.succeeded?)
              apiCaller.parseRespBody ; puts "ERROR: couldn't set #{@attribute} for #{ii.inspect}. Code: #{apiCaller.apiStatusObj['statusCode']}. Msg: #{apiCaller.apiStatusObj['msg']}"
            else
              puts "#{ii.inspect}'s #{@attribute} has changed to #{value}"
            end
            checkMatch = 1
            break
         end
       }
      if ( checkMatch == 0)
          $stderr.puts "#{ii.inspect} #{ii.length} didnt match with any regular expression \n"
        end
      }
  end
  
  # Reading regexpFile and making hash of its regexp and respective color
  def fileRead(fileName)
    reader = BRL::Util::TextReader.new(fileName)
    if(File::size(reader) <=0 )
      $stderr.puts "Error: The file is null\n"
    else
    lineNum = 0
    reader.each { |line|
        lineNum += 1
        column = line.split(/\t/)
        value = column[1]
        value.strip!
                if(@attribute =~/color/i)
                    
                    if(ColorApi.color(value) == 1)
                        $regexpTable[column[0]] = $hexColor
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                
                elsif(@attribute =~ /url/i)
                    if(ColorApi.url(value) == 1)
                       $regexpTable[column[0]] = value
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end 
                
                elsif(@attribute =~ /description/i)
                   if(ColorApi.description(value) == 1)
                        $regexpTable[column[0]] = value
                   else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~ /style/i)
                    if(ColorApi.style(value) == 1)
                        $regexpTable[column[0]] = value
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                    
                elsif(@attribute =~ /display/i)
                   if(ColorApi.display(value) == 1)
                        $regexpTable[column[0]] = value.capitalize
                   else
                       $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~ /rank/i)
                    if(ColorApi.rank(value) == 1)
                       $regexpTable[column[0]] = value
                    else
                       $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~/gbTrackPxHeight/i )
                    if(ColorApi.gbTrackPxHeight(value) == 1)
                        $regexpTable[column[0]]= value
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~/gbTrackUseLog/i )
                    value = value.capitalize
                    if(ColorApi.gbTrackUseLog(value) == 1)
                        $regexpTable[column[0]] = value
                    else
                       $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~/gbTrackUser/i )
                    if(ColorApi.gbTrackUserM(value) == 1)
                        $regexpTable[column[0]] = value
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~/gbTrackWindowingMethod/i )
                    value = value.upcase
                    if(ColorApi.gbTrackWindowingMethod(value) == 1)
                        $regexpTable[column[0]] = value
                    else
                       $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                
                elsif(@attribute =~/gbTrackPxScore/i or @attribute =~/gbTrackYIntercept/i )
                    if(ColorApi.gbTrackPxScoreThreshold(value) == 1)
                        $regexpTable[column[0]] = value
                    else
                        $stderr.puts "Error:  : the #{@attribute} format is invalid at line num #{lineNum} :- \n - #{line}\n\n"
                    end
                    
                else
                    $regexpTable[column[0]] = value
                end
        
        }
    end
    reader.close
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
  # If color format is not in "#RRGGBB". It parses "RRR,GGG,BBB" color format and
  # converts into #RRGGBB format. It also do validation for the format of color code
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
          if(color =~ /^#[0-9A-F]{6,6}/i and color.size == 8)
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
        if(values.include?(disp))
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
    
  

 # Display usage info and quit.
  def ColorApi.usage(msg='')
    unless(msg.empty?)
      puts "\n#{msg}\n"
    end
    puts "

  PROGRAM DESCRIPTION:
    Adjusts track attributes based on regular expression rules. The REGEXP file will be tab delimited file
    where 1st column would be regexp and 2nd column would be the attribute's value. 
   
  COMMAND LINE ARGUMENTS:
    --groupName        | -g => Group name.
    --db               | -d => Database name.
    --host             | -o => Host name.
    --regexpFile       | -f => Tab-delimited file with 1st column as regexp and
                               2nd column as hex RGB color
    --userName         | -u => Genboree username/login
    --attribute        | -a => [Optional] Attribute name. By-default is 'defaultColor'
    --dbrcKey          | -k => dbrc key to pull out information (username, password and host name from .dbrc file)
    --dbrcFile         | -F => [Optional] location of dbrc file
    --help             | -h => [Optional flag]. Print help info and exit.

  using .dbrc file for authentication
  trackColor.rb -f REGEXP.file  -d DATABASE_NAME -g GROUP_NAME -k KEY_NAME -F DRBC_FILE
  
  Providing authetication information from command line
  trackAttribute.rb -f REGEXP.file -u USERNAME -d DATABASE_NAME -g GROUP_NAME -o HOST_NAME

  PS:--Either username and host name can be given from command prompt or only DBRCkeyname can be give. If both are
  given toether, it will be rejected. DBRC file path is optional.
  


  ";
      exit;
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

