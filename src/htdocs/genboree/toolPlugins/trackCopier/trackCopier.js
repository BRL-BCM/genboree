// Uses prototype.js standard library file
// Uses util.js genboree library file

// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

//-------------------------------------------------------------------
// INITIALIZE your page/javascript once it loads if needed.
//-------------------------------------------------------------------


//-------------------------------------------------------------------
// RESET implementation
//-------------------------------------------------------------------
// OPTIONAL: Implement a toolReset() function that will correctly reset your
// tool's form to its initial state.

//--------------------------------------------------------------------------
// GLOBALS
//--------------------------------------------------------------------------

//-------------------------------------------------------------------
// VALIDATE *WHOLE* FORM
// - Call *each* specific validator method from here
//-------------------------------------------------------------------
// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  // Standard validations:
  if(!validate_expname()) { return false ; }

  // Custom validations:
  // Parse and final validate:
  if(!parseInput()) { return false ; }

  return true  ;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------

//-----------------------------------------------------------------------------
// UI-SPECIFIC FUNCTIONS
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Called when user checks a group containing databases, from which tracks will be selected
// Displays table box listing databases for that group
function dbsDisplay(groupChkbox)
{
  // See which group  selected
  var escGroupName = groupChkbox.value ;
  var groupName = unescape(escGroupName) ;
  var isChecked = groupChkbox.checked ;
  // Get groupParamsTable
  var paramsTable = $('groupParamsTable' + escGroupName) ;
  // Get paramsRow
  var paramCell = $('groupParamCell' + escGroupName) ;
  // Remove existing paramDiv
  var paramDiv = $('groupParamDiv' + escGroupName) ;
  if(paramDiv)
  {
    paramDiv.remove() ;
  }

  if(isChecked)
  {
    // Make a new groupParamDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'groupParamDiv' + escGroupName ;
    var divString ;
    // -- ASSUMES the page has the variable jsGroupsDatabasesTracks set up as a hash of groups/databases/trackList
    // Get the appropriate sub-hash of databases for this group:
    if(jsGroupsDatabasesTracks.get(groupName))
    {
      var byDatabases = $H(jsGroupsDatabasesTracks.get(groupName)) ;
      var databaseNames = byDatabases.keys() ;
      if(databaseNames.length > 0)
      {
        // Remove the current database from the list, if it's in there
        if(escGroupName == escCurrGroupName)
        {
          for(var ii=0; ii<databaseNames.length; ii++)
          {
            var escDatabaseName = fullEscape(databaseNames[ii]) ;
            if(escDatabaseName == escCurrUserDbName)
            {
              databaseNames[ii] = null ;
              break ;
            }
          }
          databaseNames = databaseNames.compact() ;
        }
        // Sort the database names sensibly
        databaseNames = databaseNames.sortBy( function(item)
                        {
                          return item.toLowerCase() ;
                        });
        if(databaseNames.length > 0) // Maybe removing the current database leaves none, so recheck
        {
          if(templateVersion == "none")
          {
            divString = "<b><nowrap>Databases:</nowrap></b><br>" ;
          }
          else
          {
            divString = "<b><nowrap>Databases compatible with template version &quot;" + templateVersion.escapeHTML() + "&quot;:</nowrap></b><br>" ;
          }
          divString += '<div id="databaseListDiv~`~' + escGroupName + '" name="databaseListDiv~`~' + escGroupName + '" style="padding:0px; margin:0px; width:100%; float:left;">'
          // Add each database in the group
          for(var ii=0; ii<databaseNames.length; ii++)
          {
            var databaseName = databaseNames[ii] ;
            var escDatabaseName = fullEscape(databaseName) ;
            if(escDatabaseName == escCurrUserDbName)
            {
              continue ;
            }
            var idSuffix = escGroupName + '~`~' + escDatabaseName ;
            divString +=  '<div style="padding:0px; margin:0px; width:100%; white-space:nowrap;">' +
                            '<input name="databaseChkbox~`~' + idSuffix + '" id="databaseChkbox~`~' + idSuffix + '" value="' + idSuffix + '" type="checkbox" class="databaseCheck" style="vertical-align: middle;" onclick="tracksDisplay(this)"></input>' +
                            'Database: &quot;' + databaseName.escapeHTML() + '&quot;' +
                            '<table style="display: none; width:100%;" id="databaseParamsTable~`~' + idSuffix + '" name="databaseParamsTable~`~' + idSuffix + '">' +
                            '<tr>' +
                              '<td style="width: 5%;">&nbsp;</td>' +
                              '<td style="width: 94%;" id="databaseParamCell~`~' + idSuffix + '" name="databaseParamCell~`~' + idSuffix + '">' +
                                '<div id="databaseParamDiv~`~' + idSuffix + '" name="databaseParamDiv~`~' + idSuffix + '"></div>' +
                              '</td>' +
                            '</tr>' +
                            '</table>' +
                          '</div>' ;
          }
          divString += '</div><br clear="all">'
        }
        else
        {
          divString = '<span style="font-weight:bold; color:red;">No other databases in group ' + ((templateVersion == 'none') ? '.' : (' have the template &quot;' + templateVersion.escapeHTML() + '&quot; .')) + '</span><br clear="all">' ;
        }
      }
      else
      {
        divString = '<span style="font-weight:bold; color:red;">No databases in group.</span><br clear="all">' ;
      }
      paramDiv.update(divString)
      paramCell.appendChild(paramDiv) ;
      paramsTable.show() ;
    }
  }
  else
  {
    if(paramsTable)
    {
      paramsTable.hide() ;
    }
  }
  return ;
}

function tracksDisplay(databaseChkbox)
{
  // Extact the groupName and database name
  var groupDatabaseStr = databaseChkbox.value ;
  var grpDbParts = groupDatabaseStr.split(/~`~/) ;
  var escGroupName = grpDbParts[0] ;
  var escDatabaseName = grpDbParts[1] ;
  var groupName = unescape(escGroupName) ;
  var databaseName = unescape(escDatabaseName) ;

  // Is selected?
  var isChecked = databaseChkbox.checked ;
  // Get groupParamsTable
  var paramsTable = $('databaseParamsTable~`~' + groupDatabaseStr) ;
  // Get paramsCell
  var paramCell = $('databaseParamCell~`~' + groupDatabaseStr) ;
  // Remove existing paramDiv
  var paramDiv = $('databaseParamDiv~`~' + groupDatabaseStr) ;
  if(paramDiv)
  {
    paramDiv.remove() ;
  }

  if(isChecked)
  {
    // Make a new databaseParamDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'databaseParamDiv~`~' + groupDatabaseStr ;
    var divString ;
    // -- ASSUMES the page has the variable jsGroupsDatabasesTracks set up as a hash of groups/databases/trackList
    // Get the appropriate sub-sub-hash of tracks for this database for this group:
    if(jsGroupsDatabasesTracks.get(groupName))
    {
      var byDatabases = $H(jsGroupsDatabasesTracks.get(groupName)) ;
      if(byDatabases.get(databaseName))
      {
        var byTracks = $H(byDatabases.get(databaseName)) ;
        var tracks = byTracks.keys() ;
        if(tracks.length > 0)
        {
          tracks =  tracks.sortBy( function(item)
                    {
                      return item.toLowerCase() ;
                    });
          divString = "<b><nowrap>Select the tracks(s) to copy:</nowrap></b><br>" ;
          divString += '<div id="trackListDiv~`~' + groupDatabaseStr + '" name="trackListDiv~`~' + groupDatabaseStr + '" style="padding:0px; margin:0px; width:100%; float:left;">'
          // Add each track in the database
          for(var ii=0; ii<tracks.length; ii++)
          {
            var trackName = tracks[ii] ;
            var escTrackName = fullEscape(trackName) ;
            var idSuffix = groupDatabaseStr + '~`~' + escTrackName ;
            divString +=  '<div style="padding:0px; margin:0px; width:60%; float:left; white-space:nowrap;">' +
                            '<input name="' + idSuffix + '" id="' + idSuffix + '" value="' + idSuffix + '" type="checkbox" class="trackCheck" style="vertical-align: middle;" onclick="toggleAlias(this)"></input>' +
                            trackName.escapeHTML() +
                          '</div>' +
                          '<div id="' + idSuffix + '~`~aliasDiv" name="' + idSuffix + '~`~aliasDiv" style="padding:0px; margin:0px; width:39%;float:left;display:none;">' +
                            ' as ' +
                            '<input type="text" id="' + idSuffix + '~`~_genbAlias" name="' + idSuffix + '~`~_genbAlias" value="' + trackName + '" class="trackAlias" style="font-size:8pt; width: 12em; vertical-align: middle;">' +
                          '</div><br clear="all">' ;
          }
          divString += '</div><br clear="all">'
        }
        else
        {
          divString = '<span style="font-weight:bold; color:red;">No databases in group!</span>br clear="all">' ;
        }
        paramDiv.update(divString)
        paramCell.appendChild(paramDiv) ;
        paramsTable.show() ;
      }
    }
  }
  else
  {
    if(paramsTable)
    {
      paramsTable.hide() ;
    }
  }
  return ;
}

function toggleAlias(chkbox)
{
  if(chkbox)
  {
    var aliasDivId = chkbox.id + "~`~aliasDiv" ;
    if(chkbox.checked)
    {
      $(aliasDivId).show() ;
    }
    else
    {
      $(aliasDivId).hide() ;
    }
  }
  return ;
}

//after validation, hide unneccessary fields and get the info from the rest
function parseInput()
{
  var t1 = (new Date()).getTime() ;

  var tracksCheckedCount = 0 ;
  var selectedTracksHash = $H({}) ;
  var usedAliases = $H({}) ;

  // Visit each group
  var groupNames = jsGroupsDatabasesTracks.keys() ;
  for(var ii=0; ii<groupNames.length; ii++)
  {
    var groupName = groupNames[ii] ;
    var groupChkboxId = "groupChkbox~`~" + encodeURIComponent(groupName) ;
    if($(groupChkboxId) && $(groupChkboxId).checked)
    {
      // Visit each database, if the group is checked (else skip this group)
      var byDatabases = $H(jsGroupsDatabasesTracks.get(groupName)) ;
      var databaseNames = byDatabases.keys() ;
      for(var jj=0; jj<databaseNames.length; jj++)
      {
        var databaseName = databaseNames[jj] ;
          // Visit each track, if the database is checked (else skip this database)
          var databaseChkboxId = "databaseChkbox~`~" + encodeURIComponent(groupName) + "~`~" + encodeURIComponent(databaseName) ;
          if($(databaseChkboxId) && $(databaseChkboxId).checked)
          {
            var byTracks = $H(byDatabases.get(databaseName)) ;
            var trackNames = byTracks.keys() ;
            for(var kk=0; kk<trackNames.length; kk++)
            {
              var trackName = trackNames[kk] ;
              var trackChkboxId = encodeURIComponent(groupName) + "~`~" + encodeURIComponent(databaseName) + "~`~" + encodeURIComponent(trackName) ;
              var aliasInputId = trackChkboxId + "~`~_genbAlias" ;
              var trackChkbox = $(trackChkboxId) ;
              var aliasInput = $(aliasInputId) ;
              if(trackChkbox) // Then there's a checkbox displayed...but is it checked?
              {
                if(trackChkbox.checked)
                {
                  tracksCheckedCount += 1 ;
                  // Check the alias...can't be empty and must look like a track name
                  var aliasValue = aliasInput.value ;
                  if(aliasValue.strip().length <= 0)
                  {
                    alert("There is a blank alias for one of the tracks and this is not allowed.") ;
                    aliasInput.focus() ;
                    aliasInput.select() ;
                    return false ;
                  }
                  else if( ! /^[^:]+:[^:]+$/.test(aliasValue))
                  {
                    alert("The track alias '" + aliasValue + "' doesn't look like\na proper track name. Track names look like:\n\n" +
                          "    TYPE:SUBTYPE\n\n" +
                          "That is, a type part and a subtype part joined by a ':' character.") ;
                    aliasInput.focus() ;
                    aliasInput.select() ;
                    return false ;
                  }
                  // Store the alias as used.
                  if(! usedAliases.get(aliasValue))
                  {
                    usedAliases.set(aliasValue, 1) ;
                  }
                  else
                  {
                    usedAliases.set(aliasValue, usedAliases.get(aliasValue + 1)) ;
                  }
                  // If the alias is already in use, give a warning
                  if(usedAliases.get(aliasValue) > 1)
                  {
                    var dupOK = confirm("You are copying MULTIPLE tracks that will have the name\n'" +
                                        aliasValue + "' when copied into the current database.\n\n" +
                                        "This will end up combining all the data together in a\n" +
                                        "single track. Unless deliberate, that is usually confusing\n" +
                                        "and may not give you sensible results.\n\n" +
                                        "Generally, you should give each copied track a unique name\n" +
                                        "in this database using the text-boxes provided.\n\n" +
                                        "Are you sure you want to proceed, despite this warning?") ;
                    if(!dupOK)
                    {
                      return false ;
                    }
                  }
                  // Check that alias is not already a track
                  var parts = aliasValue.split(":") ;
                  if(jsTrackMap.get(fullEscape(parts[0]) + ":" + fullEscape(parts[1])))
                  {
                    var existOK = confirm("You are copying a track which will have the same name\n" +
                                          "('" +  aliasValue + "') as an EXISTING track in this\n" +
                                          "database.\n\n" +
                                          "This will combine the existing data with the copied\n" +
                                          "data, in a single track. Unless deliberate, that is\n" +
                                          "usually confusing and may not give you sensible results.\n\n" +
                                          "Generally, you should give each copied track a unique\n" +
                                          "name that doesn't match an existing track using the\n" +
                                          "text-boxes provided.\n\n" +
                                          "Are you sure you want to proceed, despite this warning?") ;
                    if(!existOK)
                    {
                      return false ;
                    }
                  }
                  // Check that the alias is not over 19 chars
                  if(aliasValue.length > 19)
                  {
                    var longOK = confirm("The track name '" + aliasValue + "' is longer than\n" +
                                         "19 letters and will be truncated when graphically displayed.\n\n" +
                                         "It would be wise to rename this track (with the format\n" +
                                         "'Type:Subtype') using the text-box provided, so that it is\n" +
                                         "shorter than 20 characters.\n\n" +
                                         "Do you want to continue with the long track name anyway?") ;
                    if(!longOK)
                    {
                      return false ;
                    }
                  }
                  // Store the track in the nested hash
                  if( !selectedTracksHash.get(groupName) )
                  {
                    selectedTracksHash.set(groupName, $H({})) ;
                  }
                  if( !selectedTracksHash.get(groupName).get(databaseName))
                  {
                    selectedTracksHash.get(groupName).set(databaseName, $H({})) ;
                  }
                  selectedTracksHash.get(groupName).get(databaseName).set(trackName, aliasValue) ;
                }
              }
            }
          }
      }
    }
  }
  // Check that at least one track is selected to be copied
  if(tracksCheckedCount < 1)
  {
    alert("You must select at least one track to copy into the current database.") ;
    return false ;
  }
  // Warn if not based on template
  if(templateVersion == "none")
  {
    noTemplateOk = confirm("WARNING: because this database is not based on a genome\n" +
                           "template, you are able to copy tracks from ANY database\n" +
                           "you have access to.\n\n" +
                           "This includes databases based on other species' genomes\n" +
                           "and other versions/assemblies of thisgenome.\n\n" +
                           "The annotations are copied as-is, so even copying\n" +
                           "annotations from a different genome assembly version will\n" +
                           "result in INVALID/INCORRECT annotations due to differences\n" +
                           "in the coordinate systems.\n\n" +
                           "Confirm that you understand and wish to proceed:") ;
    if(!noTemplateOk)
    {
      return false ;
    }
  }
  // Convert hash to json.
  var selectedTracksHashJson = selectedTracksHash.toJSON() ;
  // Store hash for submission
  $('selectedTrackHashStr').value = selectedTracksHashJson ;
  //alert(selectedTracksHashJson) ;
  // Delete all the checkboxes, etc, so they don't get submitted.
  var selectTrackTable = $('trackSelectionTable') ;
  selectTrackTable.remove() ;

  var t2 = (new Date()).getTime() ;
  //alert("Parse UI Time: " + (t2-t1)/100.0 + " seconds") ;
  return true ;
}

//-----------------------------------------------------------------------------
// POP-UP HELP: in this function, make a pop-up help for each parameter/field in the form.
// This is done by supplying a helpSection arg indicating what help info to display.
//-----------------------------------------------------------------------------
function overlibHelp(helpSection)
{
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp;</B></FONT>' ;
  var leadingStr = '&nbsp ;<BR>' ;
  var trailingStr = '<BR>&nbsp ;' ;
  var helpText ;

  if(helpSection == "expname")
  {
    overlibTitle = "Help: Job Name" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Give this job a unique name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "destDb")
  {
    overlibTitle = "Help: Destination Database" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <li>This indicates which database will receive the copied tracks coming from the other database(s).</li>" ;
    helpText += "  <li>NOTE: this simply mirrors your current group and database selection, shown at the top of the page.</li>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "copySettings" )
  {
    overlibTitle = "Help: Copy Track Settings" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Check this to copy any display &amp; other track settings as well as the annotation data itself.</li>" ;
    helpText += "  <li>This might save time configuring the tracks for display, once copied.</li>" ;
    helpText += "  <li>Settings that are copied for each track from the source database to this database include: default color, default drawing style, description and URL, and custom links.</li>\n" ;
    helpText += "  <li>NOTE: Because you probably have tracks in this database already and the source database has various other tracks anyway, the <i>track order cannot be copied</i>; please set a suitable track order once the copy is complete.</li>" ;
    helpText += "</ul>\n\n" ;
  }
  else if(helpSection == "tracksToCopy" )
  {
    overlibTitle = "Help: Track(s) To Copy" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select which tracks to copy into the current database.</li>\n" ;
    helpText += "  <LI>Because you may have access to dozens of groups, each with 1+ databases, the tracks are organized hierarchically. Select a group and then a database within the group that has the track you want to copy.</li>\n" ;
    helpText += "  <li>You can select more than one track to copy. Be careful...excessive copying of too much data will bog down your database!</li>" ;
    helpText += "  <li>You can rename the tracks to be copied so they will be called something else in this database. This is <i>highly recommended</i> when copying multiple tracks with identical names from different databases. Otherwise they will all go into the same destination track (lumped together), which may or may not make sense.</li>\n" ;
    helpText += "  <li>To maximize utility and minimize errors &amp; mistakes, if the current database is based on a <i>template</i> genome, then only <i>compatible</i> databases will be listed here. Otherwise, all databases you have access to will be listed, and you must take care to only copy from databases based on the same genome (and assembly version!) as the current one.</li>\n" ;
    helpText += "  <LI>Empty groups and databases are not shown here.</li>\n" ;
    helpText += "</UL>\n\n" ;
  }
  overlibBody = helpText ;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F',
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300') ;
}

//-----------------------------------------------------------------------------
// HELPERS: These are standard and should be left alone. Unless you need
// some special changes for your tool.
//-----------------------------------------------------------------------------
// Displays an error msg and highlights/selects the problem field and label.
function showFormError(labelId, elemId, msg)
{
  alert(msg) ;
  highlight(labelId) ;
  var elem = $(elemId) ;
  if(elem)
  {
    if(elem.focus)
    {
      elem.focus() ;
    }
    if(elem.select)
    {
      elem.select() ;
    }
  }
  return false ;
}

function highlight( id )
{
  $(id).style["color"] = "#FF0000" ;
}

function unHighlight( id )
{
  $(id).style["color"] = "#000000" ;
}

// Verify that expname is unique.
function unique_expname()
{
   var expname = $F('expname') ;
   for( var ii=0 ; ii<=USED_EXP_NAMES.length ; ii++ )
   {
     if(expname == USED_EXP_NAMES[ii])
     {
       return showFormError( 'expnameLabel', 'expname', ( "'" + expname + "' is already used as an experiment name in this group.\nPlease select another.") ) ;
     }
   }
   return true ;
}

// Verify the expname looks ok..
function validate_expname()
{
  var expname = $F('expname') ;
  if( !expname || expname.length == 0 )
  {
    return showFormError( 'expnameLabel', 'expname', "You must enter a job name!" ) ;
  }
  else
  {
    var newExpname = expname.replace(/\`|\|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\||\ ;|\'|\>|\<|\/|\?/g, '_')
    if(newExpname != expname)
    {
      $('expname').value = newExpname ;
      return showFormError( 'expnameLabel', 'expname', "Unacceptable letters in Experiment Name have been replaced with '_'.\n\nNew Experiment Name is: '" + newExpname + "'.\n") ;
    }
    else
    {
      unHighlight( 'expnameLabel' ) ;
    }
  }
  return true ;
}

// Validate that a track is selected.
function validate_track()
{
  if( $F('template_lff') == "selectATrack" )
  {
    return showFormError( 'trackLabel', 'template_lff', "You must select a template track!" ) ;
  }
  else
  {
    unHighlight( 'trackLabel' ) ;
  }
  return true ;
}
