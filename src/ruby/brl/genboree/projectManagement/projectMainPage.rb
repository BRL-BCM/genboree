
require 'fileutils'
require 'cgi'
require 'find'
require 'time' # needed to get useful extra Time methods (parse, rfc*, etc)
require 'brl/util/util'
require 'brl/util/textFileUtil'
require 'brl/db/dbrc'
require 'brl/genboree/dbUtil'
require 'brl/genboree/genboreeDBHelper'
require 'brl/genboree/constants'
require 'brl/genboree/genboreeUtil'
require 'brl/genboree/genboreeContext'
require 'brl/genboree/projectManagement/projectManagement'
require 'brl/genboree/projectManagement/projectTreeBrowser'
require 'brl/genboree/abstract/resources/project'
require 'brl/genboree/abstract/resources/projectFiles'

module BRL ; module Genboree
  class ProjectMainPage
    # mixin methods from other files (other modules)
    include BRL::Genboree

    # To save some typing, we'll create a shorter alias for the Abstract::Resources namespace.
    Abstract = BRL::Genboree::Abstract::Resources

    # TODO: this class has lost many many methods. Check all .rb and all .rhtml
    # to see if they called some of those methods and fix the calling code.

    #--------------------------------------------------------------------------
    # ACCESSORS
    #--------------------------------------------------------------------------
    attr_accessor :name, :escName, :basePath, :editMode, :editModeStr, :jsVersion, :context
    # The name of the group this project is in
    attr_accessor :groupName
    # A representation of the project being displayed/updated
    attr_accessor :projectObj
    # A global id counter for ever-increasing html id attribute values.
    attr_accessor :idCounter
    attr_accessor :projectTitleImgDiv, :projectTitleDiv, :projectDescDiv, :projectContentDiv, :projectCustomLinksDiv
    attr_accessor :projectQuickLinksDiv, :projectAdditionalPagesDiv, :projectFilesDiv
    attr_accessor :hasLeftSideContent

    #--------------------------------------------------------------------------
    # METHODS
    #--------------------------------------------------------------------------

    # Instantiate.
    # - context is presumed to contain the :dbu and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database and
    #   the user who will be performing the create/rename/delete/etc methods on the project
    def initialize(name, editMode, context)
      replace(name, editMode, context)
    end

    # Reuse this object for a new ProjectMainPage
    # - context is presumed to contain the :dbu and :userId keys, whose value
    #   are valid DBUtil instance connected to the main genboree database and
    #   the user who will be performing the create/rename/delete/etc methods on the project
    # TODO: do we need all of these instance variables still? Check them.
    def replace(name, editMode, context)
      clear()
      # Read Genboree config file:
      @context = context
      @genbConfig = @context.genbConf
      # Core proj info
      @name = name
      @escName = Abstract::Project.projNameToPath(@name)
      # Get projId and groupId for this project
      # - the project name may be indicating a subproject, in which case, we check
      #   for top-level project and get its id, group id, etc
      # Getting projId for project name without an associated group will only work while project names are globally unique:
      @context[:projId] = Abstract::Project.getProjId(@name, nil, nil, @genbConfig)
      # Get the groupId for this project, using its name (only good while globally unique)
      @context[:groupId] = Abstract::Project.getGroupId(@name, nil, @genbConfig)
      # Instantiate a Project class to represent this project and answer questions about it
      @projectObj = Abstract::Project.new(@name, @context[:groupId], @genbConfig)
      @projectObj.isPublicAccess = @context[:isPublicAccess]
      @context[:projId] = @projectObj.projId
      @context[:state] = @projectObj.state
      @subProjElems = @projectObj.subProjectElems
      @projDir = @projectObj.projDir
      @bakDir = @projectObj.bakDir
      # Can use dbu created for Project object
      @context[:dbu] = dbu = @projectObj.dbu
      #
      @revertClicked = (context.cgi['revert'] =~ /Undo Last/i) ? true : false
      # Group name project is in:
      groupRecs = dbu.selectGroupById(@projectObj.groupId)
      @groupName = groupRecs.first['groupName']
      # Check access level based on instance's context object
      @userAllowedToEdit = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(@context[:userId], @projectObj.groupId, 'w', dbu)
      @userAllowedToPublish = BRL::Genboree::GenboreeDBHelper.checkUserAllowed(@context[:userId], @projectObj.groupId, 'o', dbu)
      @editMode = (editMode and @userAllowedToEdit)
      @jsVersion = (context ? context.jsVerStr : 'jsVer=1')
      @hasLeftSideContent = true
    end

    # Clear current state
    def clear()
      @name = @escName = @context = @projectObj = nil
      @idCounter = 0
      # Component divs:
      @projectTitleImgDiv = @projectTitleDiv = @projectDescDiv = @projectContentDiv = @projectCustomLinksDiv = @projectQuickLinksDiv = nil
      @projectAdditionalPagesDiv = @projectFilesDiv = ''
      return
    end

    # Generate Project Title Image Div
    def generateTitleImageDiv()
      @projectTitleImgDiv = ''
      titleImgComponent = @projectObj.titleImgComponent()
      # If we have an image, then display
      if(titleImgComponent.imgFilePath) # then we found a title graphic
        @projectTitleImgDiv << "<div id='projectTitleImg'>\n"
        @projectTitleImgDiv << "  <img src='#{titleImgComponent.getImageUrl()}' title='Project Title Image' alt='Project Title Image'>\n"
        @projectTitleImgDiv << "</div>"
      elsif(@editMode) # No image, but if editMode show some box
        @projectTitleImgDiv << "<div id='projectTitleImg' style='width:180;height:120;border:1px dashed black;font-style:italic;padding: 30px 5px 30px 5px;text-align:center;' >Upload of title images not enabled yet.<br><br><font size='-2'>Please email your project logo/graphic as a PNG or JPG to <a href='mailto:#{@context.genbConf.gbAdminEmail}?subject=#{@name}%20Title%20Graphic'>#{@context.genbConf.gbAdminEmail}</a>. A width of no more than 180px is highly recommended.</font>"
        # TODO: add image upload functionality
        #  @projectTitleImgDiv << editButtonDiv('projectTitleImg')
        @projectTitleImgDiv << "</div>"
      end
      return @projectTitleImgDiv
    end

    # Generate Project Title HTML
    def generateProjectTitle()
      titleComponent = @projectObj.titleComponent()
      if(titleComponent.empty?)
        @projectTitleDiv = "<div id='projectTitle'>\n<br>&nbsp;<br>\n"
      else
        @projectTitleDiv = "<div id='projectTitle'>\n#{titleComponent.data}\n"
      end
      @projectTitleDiv << editButtonDiv("projectTitle")
      @projectTitleDiv << "</div>"
      return @projectTitleDiv
    end

    # Generate Project Description HTML
    def generateProjectDesc()
      descComponent = @projectObj.descComponent()
      projectDesc = descComponent.data
      projectDesc = "<br>&nbsp;<br>" if(projectDesc !~ /\S/)
      @projectDescDiv = "<div id='projectDesc'>\n#{projectDesc}\n"
      @projectDescDiv << editButtonDiv('projectDesc')
      @projectDescDiv << "</div>"
      return @projectDescDiv
    end

    # Generate Project Content HTML
    def generateProjectContent()
      @projectContentDiv = ''
      customContentComponent = @projectObj.customContentComponent()
      projectContent = customContentComponent.data
      contentEmpty = (projectContent.nil? or projectContent !~ /\S/)
      if(!contentEmpty or @editMode)
        @projectContentDiv << "<div id='projectExtraContent'>\n"
        @projectContentDiv << (contentEmpty ? '  <i>You haven\'t added custom [free-form] content yet.</i>' : projectContent) << "\n"
        @projectContentDiv << editButtonDiv('projectContent')
        @projectContentDiv << "</div>"
      end
      return @projectContentDiv
    end

    # Generate Project Links HTML
    # - if content empty then no <div> is created, instead empty string
    def generateProjectLinks()
      @projectCustomLinksDiv = ''
      linksComponent = @projectObj.linksComponent()
      if( !linksComponent.empty? or @editMode )
        # Use Json structure to make links div
        @projectCustomLinksDiv << "<div id='projectCustomLinks_list' class='itemListParent'>\n"
        @projectCustomLinksDiv << "  <div id='projectCustomLinks_title'>Important Links:"
        @projectCustomLinksDiv << editButtonDiv('projectCustomLinks')
        @projectCustomLinksDiv << "  </div>\n"
        if(linksComponent.empty?)
          @projectCustomLinksDiv << '  <i>No links added yet.</i>'
        else
          # Iterate over each link
          linksComponent.data.each { |linkHash|
            idStr = linkHash['editableItemId'] = "projectCustomLinks_item_#{@idCounter += 1}"
            # wrap link in div
            @projectCustomLinksDiv << "  <div class='projectCustomLink' id='#{idStr}_div'>\n"
            @projectCustomLinksDiv << "    <a id='#{idStr}_url' href='" << linkHash['url']
            @projectCustomLinksDiv << "'><span id='#{idStr}_linkText'>" << linkHash['linkText'] << "</span></a>\n<br>\n"
            @projectCustomLinksDiv << "    <span id='#{idStr}_linkDesc'>" << linkHash['linkDesc'].to_s << "</span>\n</div>\n"
          }
        end
        @projectCustomLinksDiv << "</div><p>"
      end
      return @projectCustomLinksDiv
    end

    # Generate Project News HTML
    # - if content empty then no <div> is created, instead empty string
    def generateProjectUpdates()
      @updatesDiv = ''
      newsComponent = @projectObj.newsComponent()
      if( !newsComponent.empty? or @editMode )
        # Use Json structure to make updates div
        @updatesDiv << "<div id='projectNews_list' class='itemListParent'>\n"
        @updatesDiv << "  <div id='projectNews_title'>Project News:"
        @updatesDiv <<  editButtonDiv('projectNews')
        @updatesDiv << "  </div>\n"
        if(newsComponent.empty?)
          @updatesDiv << "  <i>No updates added yet.</i>"
        else
          # Sort updates in reverse date order
          newsComponent.data.sort! { |aa, bb|
            xx = Date.parse(aa["date"])
            yy = Date.parse(bb["date"])
            retVal = yy <=> xx
            if(retVal == 0)
              xx = aa['updateText'].gsub(/^(?:\s+|&nbsp;)+/, '')
              yy = bb['updateText'].gsub(/^(?:\s+|&nbsp;)+/, '')
              retVal = xx <=> yy
            end
            retVal
          }
          # Iterate over each link
          newsComponent.data.each { |updateHash|
            idStr = updateHash['editableItemId'] = "projectNews_item_#{@idCounter += 1}"
            # wrap link in div
            @updatesDiv << "  <div class='projectNews' id='#{idStr}_div'>\n"
            @updatesDiv << "    <div class='projectNews_date' id='#{idStr}_date'>#{updateHash['date']}:</div>"
            @updatesDiv << "    <div class='projectNews_updateText' id='#{idStr}_updateText'>#{updateHash['updateText']}</div>\n"
            @updatesDiv << "    <div style='clear:both;height:10px;'></div>\n"
            @updatesDiv << "  </div>"
          }
        end
        @updatesDiv << "  </div><p>"
      end
      return @updatesDiv
    end

    def generateQuickLinks()
      @projectQuickLinksDiv = ''
      quickLinksComponent = @projectObj.quickLinksComponent()
      if(!quickLinksComponent.empty? or @editMode)
        # Use Json structure to make links div
        @projectQuickLinksDiv << "<div id='projectQuickLinks_list' class='itemListParent'>\n"
        @projectQuickLinksDiv << "  <div id='projectQuickLinks_title'>Quick Links:"
        @projectQuickLinksDiv << editButtonDiv('projectQuickLinks')
        @projectQuickLinksDiv << "  </div>\n"
        # Go through each quick links if any
        if(quickLinksComponent.empty?)
          @projectQuickLinksDiv << '  <i>No quick links yet.</i>'
        else
          # Iterate over each link
          quickLinksComponent.data.each { |qlinkHash|
            idStr = qlinkHash['editableItemId'] = "projectQuickLinks_item_#{@idCounter += 1}"
            # wrap link in div
            @projectQuickLinksDiv << "  <div class='projectQuickLink' id='#{idStr}_div'>\n"
            @projectQuickLinksDiv << "  <a id='#{idStr}_url' href='" << qlinkHash['url']
            @projectQuickLinksDiv << "'><span id='#{idStr}_linkText'>" << qlinkHash['linkText'] << "</span></a>\n</div>\n"
          }
        end
        @projectQuickLinksDiv << "</div><p>"
      end
      return @projectQuickLinksDiv
    end

    def generateAdditionalPageLinks()
      @projectAdditionalPagesDiv = ''
      # This is a placeholder
      # TODO: auto index and present additional and custom pages for this project.
      return @projectAdditionalPagesDiv
    end

    def generateAdditionalFileLinks()
      @projectFilesDiv = ''
      filesComponent = @projectObj.filesComponent()
      # Build a Documents & Files section if we're in edit mode (to add, remove, or edit file info) or there are some files (to display).
      additionalFilesEmpty = filesComponent.empty?
      if( !additionalFilesEmpty or @editMode )
        @projectFilesDiv << "<div id='projectFiles_list' class='itemListParent'>\n"
        @projectFilesDiv << "  <div id='projectFiles_title'>Documents &amp; Files:"
        @projectFilesDiv << editButtonDiv('projectFiles')
        @projectFilesDiv << "  </div>\n"
        if(additionalFilesEmpty) # then only showing this because of edit mode; indicate no files present yet
          @projectFilesDiv << "  <i>No project files uploaded yet.</i>"
        else
          # Display info about additional files. First the current ones, then the archived ones.
          # Iterate over all the files and reset the editableItemId:
          filesComponent.data.each { |prjFileRec|
            prjFileRec['editableItemId'] = "projectFiles_item_#{prjFileRec['editableItemId']}"
          }
          addProjectFileListHTML(filesComponent.currentFiles)
          unless(BRL::Genboree::Abstract::Resources::FileManagement.isFileListEmpty?(filesComponent.archivedFiles))
            # Iterate over Archived Files:
            @projectFilesDiv << "<br><a class='archivedProjectFilesLink' onclick='toggleDiv(\"archivedDetailedFileListDiv\", this) ; return false ;'>Archived Documents &amp; Files:</a><br clear='all'>"
            @projectFilesDiv << "<div id='archivedDetailedFileListDiv' style='display: none ;'>"
            addProjectFileListHTML(filesComponent.archivedFiles)
            @projectFilesDiv << "</div>"
          end
        end
        @projectFilesDiv << "</div><p>"
      end
      return @projectFilesDiv
    end

    # Check user's access to the project and update X-HEADERs to communicate current group/proj to proxying app.
    # - [top-level] project must exist in database (and have a group there) and on disk
    # - user must belong to project's group
    # - if :sessionGroupId was set by Genboree, then the top-level project must be within that group,
    #   otherwise if not set we won't worry about it
    # - X-HEADERS must be set to communicate proj/group info
    def processAccess()
      retVal = nil
      # Does project exist in a group and have a disk directory?
      if(@context[:projId].nil? or @context[:groupId].nil? or !File.exist?(@projDir))
        retVal = "<center><font color='red'><b>ERROR: It appears '#{@name}' is not a valid project or is not set up properly. Perhaps the top-level project doesn't exist?</b></font></center>"
      else
        # Is this a public access or private one?
        # - valid public access: (1) no real user in context, (3) project is flagged as public
        unless(@context[:userId].to_i < 1 and @projectObj.isPublished?)
          # Then attempt private access (otherwise is valid public access, not need to check user-access)
          # Does user have access to the project's group?
          userGroupAccessRows = @context[:dbu].getAccessByUserIdAndGroupId(@context[:userId], @context[:groupId])
          if(userGroupAccessRows.nil? or userGroupAccessRows.empty?)
            retVal = "<center><font color='red'<b>ACCESS DENIED: you don't have membership in the user group to which the project belongs.</b></font></center>"
          else
            if(context.key?(:req)) # if we have an Apache request object, then send the x-headers
                                   # we want to replace the first argument here with just cgi object (modified to print some headers)...no apache
              # Set X-HEADERS for group and proj to communicate session data update
              setGroupIdXHeader(@context[:req], @context[:groupId])
              setProjectIdXHeader(@context[:req], @context[:projId])
            end
          end
        end
      end

      # If not an access error and if we have an Apache request object, then send the x-headers
      if(retVal.nil? and context.key?(:req))
        # we want to replace the first argument here with just cgi object (modified to print some headers)...no apache
        # Set X-HEADERS for group and proj to communicate session data update
        setGroupIdXHeader(@context[:req], @context[:groupId])
        setProjectIdXHeader(@context[:req], @context[:projId])
      end
      return retVal
    end

    # Generate this project main page
    def generate()
      # Check access and credentials. Set appropriate response headers
      pageContent = self.processAccess()
      # At this point, pageContent should be nil because everything is ok and we need to generate the valid content.
      # Otherwise, there's a problem (pageContent will have appropriate content to show)
      if(pageContent.nil?) # then no problem
        # First, gather the pieces
        generateTitleImageDiv()
        generateProjectTitle()
        generateProjectDesc()
        generateProjectUpdates()
        generateQuickLinks()
        # TODO: add additional pages functionality
        # generateAdditionalPageLinks()
        generateAdditionalFileLinks()
        generateProjectLinks()
        generateProjectContent()
        # Is there any left-side content?
        @hasLeftSideContent = !(@projectObj.quickLinksComponent.empty? and
                                @projectObj.linksComponent.empty? and
                                @projectObj.filesComponent.empty? and
                                @projectObj.subProjects.empty? and
                                @projectObj.subProjectElems.empty?) # <- all subprojects has *at least* a link up to parent project page
        # Now place each piece in proper spot in page
        # 1) Need to place project.css now ; nominally project-specific
        pageContent = coreScriptAndLinkTags()
        pageContent << javascriptDataForEdit()
        pageContent << "<link type='text/css' href='/styles/project.css?#{@jsVersion}' rel='stylesheet' />\n"
        pageContent << "<script type='text/javascript' src='/javaScripts/project.js?#{@jsVersion}'></script>\n"
        pageContent << "<div id='projectEditBtnBar'>\n"
        pageContent << "<form id='modeForm' name='modeForm' >\n"
        pageContent << "<input id='projectName' name='projectName' type='hidden' value='#{@name}'>\n"
        pageContent << "<input id='groupName' name='groupName' type='hidden' value='#{@groupName}'>\n"
        pageContent << "<input id='lastApiStatusCode' name='lastApiStatusCode' type='hidden' value=''>\n"
        pageContent << "<input id='lastApiStatusMsg' name='lastApiStatusMsg' type='hidden' value=''>\n"
        if(@userAllowedToEdit)
          pageContent << "  <input type='hidden' id='edit' name='edit' value='yes'>"
          if(@editMode and @projectObj.hasBackups? and !@revertClicked)
            pageContent << "  <input type='hidden' id='revert' name='revert' value='yes'>"
          end
          # "undo" button -- only if editing and have some BAK file
          if(@editMode)
            pageContent <<  "  <input id='undoButton' name='undoButton' type='submit' class='projectSubmitButton' " <<
                            "value='Undo Last' alt='Undo last edit (restore previous version)' " <<
                            "title='Undo last edit (restore previous version)' " <<
                            "onclick='return modeButtonClicked(this)' " <<
                            "#{@projectObj.hasBackups? ? '' : 'disabled=\'disabled\''} >\n"
            if(@userAllowedToPublish and (@subProjElems.nil? or @subProjElems.empty?))
              if(@projectObj.isPublished?)
                pageContent <<  "  <input id='retractButton' name='retractButton' type='submit' class='projectSubmitButton' " <<
                                "value='Retract' alt='Retract this Project (make it private-access)' title='Retract this Project (make it private-access)' " <<
                                "onclick='return modeButtonClicked(this)' >\n"
              else # no published [yet]
                pageContent <<  "  <input id='publishButton' name='publishButton' type='submit' class='projectSubmitButton' " <<
                                "value='Publish' alt='Publish this Project (make is publicly-accessible)' title='Publish this Project (make is publicly-accessible)' " <<
                                "onclick='return modeButtonClicked(this)' >\n"
              end
            end
          end
          pageContent <<  "  <input id='editModeSubmit' type='submit' class='projectSubmitButton' value=" <<
                          (@editMode ? "'View Mode' " : "'Edit Mode' ") <<
                          "onclick='return modeButtonClicked(this)' >\n"
        end
        pageContent << "</form></div>"
        pageContent << "<div id='status' class='feedback' style='display: none;'></div>\n"
        # 2) Place image if any
        pageContent << @projectTitleImgDiv << "\n"
        # 3) Place title and desc
        pageContent << "<div id='projectTitleAndDesc' style='width:" << (@projectTitleImgDiv.empty? ? "100%" : "71%") << ";'>"
        pageContent << @projectTitleDiv << "\n"
        pageContent << @projectDescDiv << "\n"
        pageContent << "</div>"
        pageContent << "<br clear='all'>"
        # 3.5 Put an <hr> only if there is content in at least one of: news, qlinks, impt links
        pageContent << "<hr class='projectFullRule'>\n" unless( @editMode or (@projectObj.quickLinksComponent().empty? and @updatesDiv.to_s.empty? and @projectCustomLinksDiv.to_s.empty?))
        # 4) Place typical middle-of-page content
        pageContent << "<div id='projectPageMiddle'>\n"
        # 5) Place left sidebar stuff if there is stuff to put
        if( @editMode )
          pageContent << "<div id='projectPageMiddleLeft'>"
          pageContent << @projectQuickLinksDiv << "\n&nbsp;<p>"
          pageContent << @projectAdditionalPagesDiv << "\n&nbsp;<p>\n"
          pageContent << "</div>"
        else
          if(@hasLeftSideContent)
            pageContent << "<div id='projectPageMiddleLeft' style='overflow: auto;'>"
            pageContent << "  <div id='projectTreeDiv' name='projectTreeDiv' width='100%' style='padding: 0; margin: 0;'></div>"
            pageContent << "</div>"
          end
        end
        # 6) Place right content stuff
        pageContent << "<div id='projectPageMiddleRight'>\n"
        pageContent << @updatesDiv << "\n"
        pageContent << @projectCustomLinksDiv << "\n"
        pageContent << @projectFilesDiv << "\n"
        pageContent << "</div></div><br clear='all'>\n"
        if(@editMode or !@projectObj.customContentComponent().empty?)
          pageContent << "<hr class='projectFullRule'>\n"
          # 7) Place extra content at bottom, if any
          pageContent << @projectContentDiv << "\n"
        end
        pageContent << "<div id='submitForm' name='submitForm' div='display: none;'></div>"
      end
      return pageContent
    end

    def postChanges(projName, context)
      retVal = false
      if(@userAllowedToEdit)
        retVal = true
        # Get entity name and value to change
        componentType = context.cgi['componentType'].strip()
        componentValue = context.cgi['componentValue'].strip()
        projName.strip!()
        # Make a 1-level backup
        @projectObj.createBackup()
        # Get the component we'll be updating:
        component = @projectObj.getComponent(componentType)
        # If it's a type of component that stores JSON text, we need to clean out
        # any "editableItemId" fields in the componentValue.
        if(component.class::DATA_FORMAT == :JSON)
          jsonObj = JSON.parse(componentValue)
          jsonObj.each { |rec|
            rec.delete("editableItemId")
          }
          content = JSON.pretty_generate(jsonObj)
        else
          content = componentValue
        end
        # Update the component's data file with the new contents
        component.replaceDataFile(content)
      end
      return retVal
    end

    #--------------------------------------------------------------------------
    # HELPERS
    #--------------------------------------------------------------------------

    # Convert white space to HTML
    def convertNewlinesToHtml(str)
      retVal = str.gsub(/(?:\r?\n){2,2}|(?:\n\r?){2,2}/, "<p>")
      retVal.gsub!(/(?:\r?\n)|(?:\n?\r)/, "<br>")
      retVal.gsub!(/<p>(?!\n|\r)/, "\n<p>\n")
      retVal.gsub!(/<br>(?!\n|\r)/, "\n<br>\n")
      return retVal
    end

    def editButtonDiv(idStr)
      divClass = imgSrc = nil
      case idStr
        when 'projectTitleImg', 'projectTitle', 'projectDesc', 'projectContent' # Need simple edit button
          divClass = 'editButtonDiv'
          imgSrc = '/images/project_pencil.png'
        else # Need complex edit toolbar buttons
          divClass = 'editToolBarButtonDiv'
          imgSrc = '/images/project_pencil_go.png'
      end
      if(@editMode)
        retVal = "<div class='#{divClass}' id='#{idStr}EBtnDiv'><img id='#{idStr}EBtn' class='editHandleIcon' width='18' height='18' onmouseover='this.style.border=\"1px solid black\";' onmouseout='this.style.border=\"none\";' alt='' title='' src='#{imgSrc}'></div>"
      else
        retVal = ''
      end
      return retVal
    end

    def addProjectFileListHTML(prjFileRecs)
      prjFileRecs.each { |prjFileRec|
        next if(BRL::Genboree::Abstract::Resources::FileManagement.isHidden?(prjFileRec))
        idStr = "projectFiles_item_#{prjFileRec['editableItemId']}"
        # wrap link to file in div
        @projectFilesDiv << "  <div class='projectFile' id='#{idStr}_div'>\n"
        # the file link http://genboree.org/projects/EDACC/SCmeeting1/genb%5E%5EadditionalFiles/UC_and_BC_REMC_Costello_May_2009a.ppt
        escFileName = CGI.escape(prjFileRec['fileName'])
        if(prjFileRec['uploadPending'] == true)
          @projectFilesDiv << "    <span id='#{idStr}_fileLabel'>#{CGI.escapeHTML(prjFileRec['label'])}</span>\n"
          @projectFilesDiv << "    &nbsp;&nbsp;<i>(<span style=\"color:red;font-weight:bold;\">Unavailable</span>, Upload in progress)</i>\n<br>\n"
        else
          # Double escape names: (1st) to make correct URL  (2nd) because stored on disk with escaped name (nginx will read directly after decoding the urll)
          @projectFilesDiv << "    <a id='#{idStr}_fileLink' href='/projects/#{CGI.escape(@escName)}/genb^^additionalFiles/#{CGI.escape(escFileName)}'>"
          @projectFilesDiv << "    <span id='#{idStr}_fileLabel'>#{CGI.escapeHTML(prjFileRec['label'])}</span></a>\n<br>\n"
        end
        @projectFilesDiv << "    <div id='#{idStr}_fileDesc' class='projectFile_fileDesc'>\n"
        unless(prjFileRec['description'].empty?)
          @projectFilesDiv << "#{prjFileRec['description']}\n<br>\n"
        end
        @projectFilesDiv << "      <span id='#{idStr}_fileDate' class='projectFile_fileUploadDate'>File date: #{prjFileRec['date'].strftime('%a %b %d %Y %H:%M:%S')}</span>\n"
        @projectFilesDiv << "    </div><input type='hidden' id='#{idStr}_fileArchived' value='#{prjFileRec['archived']}' />"
        @projectFilesDiv << "    <input type='hidden' id='#{idStr}_fileAutoArchive' value='#{prjFileRec['autoArchive']}' />"
        @projectFilesDiv << "    <input type='hidden' id='#{idStr}_fileName' value='#{prjFileRec['fileName']}' />"
        #@projectFilesDiv << "    <div style='clear:both;height:10px;'></div>\n"
        @projectFilesDiv << "  </div>"
      }
    end

    # TODO: ext-all.css with only what we need
    # TODO: see if we can remove the extra jsp.css <link> after getting rid of ext-all.css (which mucks with all block elements' padding and margin)
    def coreScriptAndLinkTags()
      retVal = <<-EOS
          <!-- PAGE LOADING MASK -->
          <!-- Load the page-init mask CSS first -->
          <link rel="stylesheet" href="/javaScripts/extjs/resources/css/loading-genboree.css?#{@jsVersion}" type="text/css" />
          <script type="text/javascript">
            isEditMode = #{@editMode} ;
            var maskDiv = document.createElement('div') ;
            maskDiv.setAttribute('id', 'genboree-loading-mask') ;
            maskDiv.setAttribute('name', 'genboree-loading-mask') ;
            var loadMsgDiv = document.createElement('div') ;
            loadMsgDiv.setAttribute('id', 'genboree-loading') ;
            loadMsgDiv.setAttribute('name', 'genboree-loading') ;
            loadMsgDiv.innerHTML = '<div class="genboree-loading-indicator"><img src="/javaScripts/extjs/resources/images/default/grid/loading.gif" style="width:16px; height:16px;" align="absmiddle"> &#160;Initializing Page...</div>' ;
            var dialogDiv = document.createElement('div') ;
            dialogDiv.setAttribute('id', 'prompt-dialog') ;
            dialogDiv.setAttribute('name', 'prompt-dialog') ;
            dialogDiv.style.visibility = "hidden" ;
            dialogDiv.innerHtml = '<div class="x-dlg-hd">Layout Dialog</div><div class="x-dlg-bd"><div id="center" class="x-layout-inactive-content" style="padding: 10px;"></div></div>' ;
            var bodyElems = document.getElementsByTagName('body') ;
            var bodyElem = bodyElems[0] ;
            bodyElem.insertBefore(dialogDiv, bodyElem.firstChild) ;
            bodyElem.insertBefore(loadMsgDiv, bodyElem.firstChild) ;
            bodyElem.insertBefore(maskDiv, bodyElem.firstChild) ;
            maskDiv.style.width = "100%" ;
            maskDiv.style.height = "100%" ;
            maskDiv.style.background = "#e1c4ff" ;
            maskDiv.style.position = "absolute" ;
            maskDiv.style['z-index'] = "20000" ;
            maskDiv.style.left = "0px" ;
            maskDiv.style.top = "0px" ;
            maskDiv.style.opacity = "0.5" ;
          </script>
          <!-- include EVERYTHING ELSE after the loading indicator -->
          <script type="text/javascript" src="/javaScripts/json2.js"></script>
          <!-- BEGIN: Extjs: -->
          <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/prototype.js?#{@jsVersion}"></script> <!-- Stuff here used in rest of files... -->
          <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/scriptaculous.js?#{@jsVersion}"></script> <!-- Stuff here used in rest of files... -->
          <script type="text/javascript" src="/javaScripts/extjs/adapter/prototype/ext-prototype-adapter.js?#{@jsVersion}"></script> <!-- Stuff here used in rest of files... -->
          <!-- script type="text/javascript" src="/javaScripts/extjs/package/genboree/ext-projectManagement-only-pkg.js?#{@jsVersion}"></script -->
          <script type="text/javascript" src="/javaScripts/extjs/ext-all.js?#{@jsVersion}"></script>
          <script type="text/javascript" src="/javaScripts/progressUpload.js?#{@jsVersion}"></script>

          <link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ext-all-noMods2BaseTags.css?#{@jsVersion}" />
          <!-- link rel="stylesheet" type="text/css" href="/javaScripts/extjs/resources/css/ytheme-genboree.css?#{@jsVersion}" ></link --><!-- Set a local "blank" image file; default is a URL to extjs.com -->
          <script type='text/javascript'>
            Ext.BLANK_IMAGE_URL = '/javaScripts/extjs/resources/images/genboree/s.gif';
          </script>
          <link type="text/css" href="/styles/jsp.css?#{@jsVersion}" rel="stylesheet" />
          <!-- END -->

          <!-- BEGIN: Genboree Specific -->
          <script type="text/javascript" src="/javaScripts/util.js?#{@jsVersion}"></script> <!-- Stuff here used in rest of files... -->
          <!-- END -->

          <!-- BEGIN: Specifically for fixing Extjs datapickerr -->
          <script type="text/javascript">
            Ext.DatePicker.prototype.brokenOnRender = Ext.DatePicker.prototype.onRender ;
            Ext.DatePicker.prototype.onRender = function(container, position)
            {
              // this.update has to be called only after setting width
              var originalUpdate = this.update ;
              this.update = Ext.emptyFn ;
              this.brokenOnRender(container, position) ;
              this.el.dom.style.width = '10px' ;
              this.update = originalUpdate ;
              this.update(this.value) ;
            }
          </script>
      EOS
      # Add tree browsing stuff if not in edit mode.
      if(!@editMode and @hasLeftSideContent)
        treeBrowser = BRL::Genboree::ProjectTreeBrowser.new(@projectObj, @context[:groupId])
        retVal << treeBrowser.htmlHeadTags()
      end
      return retVal
    end

    def javascriptDataForEdit()
      retVal = '' ;
      if(@editMode and @userAllowedToEdit)
        retVal = "<script type='text/javascript'>"
        retVal << "var pageContents = { "
        retVal << "  'projectTitle': #{@projectObj.titleComponent().empty? ? '""' : @projectObj.titleComponent().to_json},\n"
        retVal << "  'projectDesc': #{@projectObj.descComponent().empty? ? '""' : @projectObj.descComponent().to_json},\n"
        retVal << "  'projectContent': #{@projectObj.customContentComponent().empty? ? '""' : @projectObj.customContentComponent().to_json},\n"
        retVal << "  'projectNews': #{@projectObj.newsComponent().empty? ? '[]' : @projectObj.newsComponent().to_json},"
        retVal << "  'projectCustomLinks': #{@projectObj.linksComponent().empty? ? '[]' : @projectObj.linksComponent().to_json},"
        retVal << "  'projectQuickLinks': #{@projectObj.quickLinksComponent().empty? ? '[]' : @projectObj.quickLinksComponent().to_json},"
        retVal << "  'projectFiles': #{@projectObj.filesComponent().empty? ? '[]' : @projectObj.filesComponent().to_json}"
        retVal << "} ; "
        retVal << "</script>"
      end
      return retVal ;
    end
  end
end ; end
