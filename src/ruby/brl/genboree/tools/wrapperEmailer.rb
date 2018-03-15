#!/usr/bin/env ruby
require 'cgi'
require 'brl/util/util'
require 'brl/util/emailer'
require 'brl/rackups/thin/genboreeRESTRackup'

module BRL ; module Genboree ; module Tools
  class WrapperEmailer
    # Tool title/name (required)
    attr_accessor   :toolTitle, :shortToolTitle
    # User email address (required)
    attr_accessor   :emailTo
    # Tool Job ID (required)
    attr_accessor   :jobID
    # User first name (should have!)
    attr_accessor   :userFirst
    # User last name (should have!
    attr_accessor   :userLast
    # Analysis Name
    attr_accessor   :analysisName
    # Hash for labels to suitable text describing for each input
    attr_accessor   :inputsText
    # Hash for labels to suitable text describing for each output
    attr_accessor   :outputsText
    # Hash of setting names to values (both must be user readable!)
    attr_accessor   :settings
    # Extra text for email, prior to signature (result summaries, etc)
    attr_accessor   :additionalInfo
    # Array of files to their Workbench location (as properly indented string)
    attr_accessor   :resultFileLocations
    # Hash of files to their corresponding URLs
    attr_accessor   :resultFileURLs
    # String with user-readable message about error that occurred
    attr_accessor   :errMessage
    # String with exit code(s) info from underlying tool(s); user readable!
    attr_accessor   :exitStatusCode
    # String with one or more apiExitCode and possibly the status message; user readable!
    attr_accessor   :apiExitCode
    # tool id of the tool for which the email is being sent 
    attr_accessor   :toolId
    # flag to tell us whether the tool is an ERCC tool or not. If it is, then we'll put the DCC admin emails instead of the standard Genboree email. 
    attr_accessor   :erccTool

    def initialize(toolTitle, emailTo,  jobID, userFirst="User", userLast="", analysisName="n/a", inputsText="n/a", outputsText="n/a", settings=nil, additionalInfo=nil, resultFileLocations=nil, resultFileURLs=nil, shortToolTitle=nil, erccTool=nil)
      @toolTitle, @emailTo,  @jobID, @userFirst, @userLast, @analysisName, @inputsText, @outputsText, @settings, @additionalInfo, @resultFileLocations, @resultFileURLs, @erccTool = toolTitle, emailTo,  jobID, userFirst, userLast, analysisName, inputsText, outputsText, settings, additionalInfo, resultFileLocations, resultFileURLs, erccTool
      @errMessage = nil
      @exitStatusCode = "n/a"
      @apiExitCode = nil
      @toolId = nil
      @shortToolTitle = (shortToolTitle.nil? ? toolTitle : shortToolTitle)
    end

    def sendSuccessEmail()
      self.class::sendSuccessEmail(self)
    end

    # [+errMessage+] String with a message about any error that occurred. User readable!
    # [+exitStatusCode+] String with exit code information (for underlying tool(s))
    # [+apiExitCode+] String with apiExitCode information, if appropriate for user to see
    def sendErrorEmail(errMessage=@errMessage, exitStatusCode=@exitStatusCode, apiExitCode=@apiExitCode)
      self.class::sendFailureEmail(errMessage, exitStatusCode="n/a", apiExitCode=nil, self)
    end
    
    
    # ------------------------------------------------------------------
    # CLASS METHODS - do the actual sending, etc
    # ------------------------------------------------------------------
    
    
    def self.sendSuccessEmail(emailConf)
      retVal = false
      # Header Indentation
      @headerIndent = " " * 2
      # Sub Header Indentation
      @subHeaderIndent = " " * 4
      # Sub sub Header Indentation
      @subSubHeaderIndent = " " * 6
      if(emailConf.is_a?(WrapperEmailer))
        # Read genbConf
        genbConf = ENV['GENB_CONFIG']
        genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
        
        
        # Get some key attributes from emailConf
        inputsText, outputsText, settings = emailConf.inputsText, emailConf.outputsText, emailConf.settings
        # Build Email
        emailTo = emailConf.emailTo
        if(emailTo)
          
          subject = "Genboree: Your #{emailConf.shortToolTitle} job is complete "
          # Prep body of email
          body = "
            Hello #{emailConf.userFirst.capitalize} #{emailConf.userLast.capitalize},

            Your #{emailConf.toolTitle} job completed successfully.

            Job Summary:
              JobID          - #{emailConf.jobID}
          "
          # Add Analysis Name, if available
          if(emailConf.analysisName and !emailConf.analysisName.empty?)
            body << "    Analysis Name  - #{emailConf.analysisName}\n"
          end
          # De-indent body
          body.gsub!(/^ {10,10}/, '')

          # We're about to print some info about the inputs, outputs, and settings if available.
          # First, determine longest key for each of these since it will dictate indenting and aligning.
          largestSize = 0
          inputsText.each_key { |inputType| largestSize = inputType.size if(inputType.size > largestSize) } if(inputsText.is_a?(Hash))
          outputsText.each_key { |outputType| largestSize = outputType.size if(outputType.size > largestSize) } if(outputsText.is_a?(Hash))
          settings.each_key { |settingType| largestSize = settingType.size if(settingType.size > largestSize) } if(settings.is_a?(Hash))

          # Print some Inputs information
          if(inputsText.is_a?(Hash))
            # Display max 9 input files
            trackCount = 1
            body << "\n#{@headerIndent}Inputs:\n"
            # Loop over inputs to display
            inputsText.keys.sort.each { |inputType|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - inputType.size) + 1)
              # value
              value = inputsText[inputType]
              body << "#{@subHeaderIndent}#{inputType}#{spacingStr}- #{CGI.unescape(value.to_s)}\n"
              # Display max 9 input files
              if(trackCount == 9 and inputsText.size > 9 )
                body << "#{@subHeaderIndent}....\n"
                break
              end
              trackCount += 1
            }
          end

          # Print some Outputs information
          if(outputsText.is_a?(Hash))
            body << "\n#{@headerIndent}Outputs:\n"
            outputsText.keys.sort.each { |outputType|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - outputType.size) + 1)
              # value
              value = outputsText[outputType]
              body << "#{@subHeaderIndent}#{outputType}#{spacingStr}- #{CGI.unescape(value.to_s)}\n"
            }
          end

          # Print some Settings information
          if(settings.is_a?(Hash))
            body << "\n#{@headerIndent}Settings:\n"
            settings.keys.sort.each { |setting|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - setting.size) + 1)
              # value
              value = settings[setting]
              if(value =~ /^http/)
                body << "#{@subHeaderIndent}#{setting}#{spacingStr}- #{value.to_s}\n"
              else
                body << "#{@subHeaderIndent}#{setting}#{spacingStr}- #{CGI.unescape(value.to_s)}\n"
              end
            }
          end

          # If any additional info (results summary, etc).
          # - Result file URLs & Locations should be supplied separately
          if(emailConf.additionalInfo and !emailConf.additionalInfo.empty?)
            body << "\nAdditional Info:\n"
            addInfo = emailConf.additionalInfo.gsub(/\n/, "\n#{@headerIndent}")
            body << "#{@headerIndent}#{addInfo}\n"
          end

          # Result File Locations
          if(emailConf.resultFileLocations)
            body << "\n\nResult File Location in the Genboree Workbench:\n"
            body << "(Direct links to files are at the end of this email)\n" if(emailConf.resultFileURLs)
            emailConf.resultFileLocations.each { |locationStr|
              body << locationStr.gsub(/^/, '  ')
            }
          end

          # Result File URLS
          if(emailConf.resultFileURLs)
            body << "\nResult File URLs (click or paste in browser to access file):\n"
            emailConf.resultFileURLs.each_key { |file|
              value = emailConf.resultFileURLs[file]
              body << "    FILE: #{File.basename(file)}\n    URL:\n  #{value}\n"
            }
          end

          # Signature
          body << "\n\n- The Genboree Team\n"

          # Send email
          WrapperEmailer.sendEmail(emailTo, subject, body, "success")
          retVal = true
        end # if(emailTo)
      end # if(emailConf.is_a?(Hash) and !emailConf.empty?)
      return retVal
    end # def self.sendSuccessEmail(emailConf={})

    def self.sendFailureEmail(errMessage, exitStatusCode="n/a", apiExitCode=nil, emailConf=nil)
      # Header Indentation
      @headerIndent = " " * 2
      # Sub Header Indentation
      @subHeaderIndent = " " * 4
      # Sub sub Header Indentation
      @subSubHeaderIndent = " " * 6
      retVal = false
      if(emailConf.is_a?(WrapperEmailer))
        # Read genbConf
        genbConf = ENV['GENB_CONFIG']
        genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
        # Get some key attributes from emailConf
        inputsText, outputsText, settings = emailConf.inputsText, emailConf.outputsText, emailConf.settings
        # Build Email
        emailTo = emailConf.emailTo
        if(emailTo)
          subject = "Genboree: Your #{emailConf.shortToolTitle} job failed."
          # Prep the email body
          body = "
            Hello #{emailConf.userFirst.capitalize} #{emailConf.userLast.capitalize},

            Your #{emailConf.toolTitle} job failed.

            Job Summary:
              JobID          - #{emailConf.jobID}
          "
          # Add Analysis Name, if available
          if(emailConf.analysisName and !emailConf.analysisName.empty?)
            body << "    Analysis Name  - #{emailConf.analysisName}\n"
          end
          # De-indent body
          body.gsub!(/^ {12,12}/,'')

          # We're about to print some info about the inputs, outputs, and settings if available.
          # First, determine longest key for each of these since it will dictate indenting and aligning.
          largestSize = 0
          inputsText.each_key { |inputType| largestSize = inputType.size if(inputType.size > largestSize) } if(inputsText.is_a?(Hash))
          outputsText.each_key { |outputType| largestSize = outputType.size if(outputType.size > largestSize) } if(outputsText.is_a?(Hash))
          settings.each_key { |settingType| largestSize = settingType.size if(settingType.size > largestSize) } if(settings.is_a?(Hash))

          # Print some Inputs information
          if(inputsText.is_a?(Hash))
            # Display max 9 input files
            trackCount = 1
            body << "\n#{@headerIndent}Inputs:\n"
            # Loop over inputs to display
            inputsText.keys.sort.each { |inputType|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - inputType.size) + 1)
              # value
              value = inputsText[inputType]
              body << "#{@subHeaderIndent}#{inputType}#{spacingStr}- #{value}\n"
              # Display max 9 input files
              if(trackCount == 9 and inputsText.size > 9 )
                body << "#{@subHeaderIndent}....\n"
                break
              end
              trackCount += 1
            }
          end

          # Print some Outputs information
          if(outputsText.is_a?(Hash))
            body << "\n#{@headerIndent}Outputs:\n"
            outputsText.keys.sort.each { |outputType|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - outputType.size) + 1)
              # value
              value = outputsText[outputType]
              body << "#{@subHeaderIndent}#{outputType}#{spacingStr}- #{value}\n"
            }
          end

          # Print some Settings information
          if(settings.is_a?(Hash))
            body << "\n#{@headerIndent}Settings:\n"
            settings.keys.sort.each { |setting|
              # spacing after the long name:
              spacingStr = " " * ((largestSize - setting.size) + 1)
              # value
              value = settings[setting]
              body << "#{@subHeaderIndent}#{setting}#{spacingStr}- #{value}\n"
            }
          end

          if((emailConf.errMessage and !emailConf.errMessage.empty?) or (emailConf.exitStatusCode))
            body << "\n"
            body << "  Exit Status   : #{emailConf.exitStatusCode}\n" if(emailConf.exitStatusCode)
            body << "  Error Message :\n#{emailConf.errMessage}\n" if(emailConf.errMessage and !emailConf.errMessage.empty?)
          end
           # If any additonal info (results summary, etc).
          # - Result file URLs & Locations should be supplied separately
          if(emailConf.additionalInfo and !emailConf.additionalInfo.empty?)
            body << "\nAdditional Info:\n"
            addInfo = emailConf.additionalInfo.gsub(/\n/, "\n#{@headerIndent}")
            body << "#{@headerIndent}#{addInfo}\n"
          end

          # Any API exit code?
          if(apiExitCode and !apiExitCode.empty?)
            body << "      Api Exit Status   : #{emailConf.apiExitCode}\n"
          end

          # Signature
          if(emailConf.erccTool)
            adminEmailStr = "a DCC admin "
            if(genbConfig.gbDccAdminEmails.class == Array)
              adminEmailStr << "(#{genbConfig.gbDccAdminEmails.join(", ")})"
            else
              adminEmailStr << "(#{genbConfig.gbDccAdminEmails})"
            end
          else
            adminEmailStr = "the Genboree Team (#{genbConfig.gbAdminEmail})"
          end
          body << "\n\nFor further assistance, please contact #{adminEmailStr} with the above information.\n\n- The Genboree Team"

          # Send email
          WrapperEmailer.sendEmail(emailTo, subject, body, "failure")
          retVal = true
        end # if(emailTo)
      end # if(emailConf.is_a?(WrapperEmailer))
      return retVal
    end # def self.sendFailureEmail(emailConf)

    def self.sendEmail(emailTo, subjectTxt, bodyTxt, type)
      # Read genbConf
      genbConf = ENV['GENB_CONFIG']
      genbConfig = BRL::Genboree::GenboreeConfig.load(genbConf)
      # Make emailer object
      email = BRL::Util::Emailer.new(genbConfig.gbSmtpHost)
      email.setHeaders(genbConfig.gbFromAddress, emailTo, subjectTxt)
      email.setMailFrom(genbConfig.gbFromAddress)
      email.addRecipient(emailTo)
      email.addHeader("Bcc: #{genbConfig.gbBccAddress}")
      email.addRecipient(genbConfig.gbBccAddress)
      ## Send Failure emails to select people in a BCC list
      if(type =~ /failure/)
        @bccFailureEmails = genbConfig.gbBccFailureAddress
        if(!@bccFailureEmails.nil? or !@bccFailureEmails.empty?)
          @bccFailureEmails.each { |bccEmail|
            email.addRecipient(bccEmail)
          }
        end          
      end
      email.setBody(bodyTxt)
      email.send()
      return true
    end
  end # class WrapperEmailer
end ; end ; end # module BRL ; module Genboree ; module Tools
