# Message Queue helper
module GenericHelpers
  module MqHelper
    # To have controller methods available in Views, Rails requires them to be declared as helper_methods.
    # Of course wherever they get included needs to also have the helper_method() method. Controllers
    #   and AbstractController::Helpers do. This should handle other cases appropriately.
    def self.included( obj )
      if( obj.respond_to?( :helper_method) )
        obj.helper_method :mqNotify
      end
    end

    # @params [String] mq message queue for notice
    # @params [String] subject a url or an id that identifies the subject entity of the message
    # @params [String, Hash] msgContent message content
    def mqNotify(mq, subject, msgContent, opts={})
      tt = Time.now.to_f
      retVal = nil
      # Is mqConf already the config Hash or do we need to read the config json file it points to?
      unless( mq.is_a?(Hash) ) # is String with location of conf json file
        mqConfFile = mq
        $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MQ - MQ conf file:\n\t#{mqConfFile.inspect}\n\n")
        mqConf = JSON.parse( File.read( mqConfFile ) ) rescue nil
        #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "Loaded conf for doc-released MQ conf w/keys #{mqConf.keys.inspect} in #{Time.now.to_f - tt} sec") ; tt = Time.now.to_f
      end

      # mqConf and noticeConf hashes look ok? Then write message accordingly
      if( mqConf )
        # Get the mqType from the config file
        if( mqConf['mqType'] == "dir" )
          if( mqConf['location'].to_s =~ /\S/ and subject =~ /\S/ )
            queueDir = mqConf['location'].to_s.strip
            msgFile = uniqFileName( "#{queueDir}/#{subject}.json" )
            #$stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MQ - Message file:\n\t#{msgFile.inspect}")
            File.open(msgFile, 'w+') { |outFile|
              if( msgContent.is_a?(Hash) )
                outFile.write( JSON.pretty_generate(msgContent) )
              else
                outFile.write( msgContent )
              end
            }
            $stderr.debugPuts(__FILE__, __method__, 'DEBUG', "MQ - Wrote message for subject #{subject.inspect} to:\n\t#{msgFile.inspect}") ; tt = Time.now.to_f
            retVal = true
          else
            msg = "Bad arguments. Could not find location and(or) subject from the message queue config file located - (#{mqConfFile.inspect} - syntax error maybe?) or there is no subject (#{subject.inspect rescue '[MISSING]'})! Can't notify Kafka of new event."
            $stderr.debugPuts(__FILE__, __method__, '!! FAILED !!', msg)
            raise ArgumentError, msg
          end # if no location or subject
        else
          raise ArgumentError, "ERROR: Currently only 'mqType'=> 'dir' is supported (and even then probably as a temporary stop-gap measure). Your mqConf['mqType'] was #{mqConf['mqType'].inspect}"
        end # Not the expected message queue type
     else
       raise ArgumentError, "ERROR: Failed to parse the message queue file. Check for syntax errors in #{mqConfFile.inspect}"
     end
    return retVal
    end

   
    def uniqFileName( fileName )
      baseFn = File.basename( fileName.to_s )
      dir = ( (fileName =~ /\//) ? "#{File.dirname(fileName)}/" : '' )
      uniqStr = fileName.to_s.generateUniqueString
      return "#{dir}#{Time.now.to_f}-#{uniqStr}-#{baseFn}"
    end

 
  end
end
