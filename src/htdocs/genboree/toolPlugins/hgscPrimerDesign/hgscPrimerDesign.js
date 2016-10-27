// Uses prototype.js standard library file
// Uses util.js genboree library file

// INITIALIZE your page/javascript once it loads if needed.
addEvent(window, "load", init_toolPageInit) ;
function init_toolPageInit()
{
  // Nada for this tool.
  return
}
// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

// INITIALIZE your page/javascript once it loads if needed.
addEvent(window, "load", init_toolPage) ;
function init_toolPage()
{
  var hgscProjYes = getElementByIdAndValue(TOOL_PARAM_FORM, 'hgscProj', 'yes') ;
  var hgscProjNo = getElementByIdAndValue(TOOL_PARAM_FORM, 'hgscProj', 'no') ;
  if(!hgscProjYes.checked && !hgscProjNo.checked)
  {
    hgscProjNo.checked = true ;
  }
  return
}

// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  // Standard validations:
  if(validate_expname() == false) { return false; }
  if(unique_expname() == false) { return false; }
  if(validate_track() == false) { return false; }  
  // Custom validations: 
  if(validate_genboreeTrack() == false) { return false; } 

  return true;
}

// Validate Genboree track name if to be uploaded. 
function validate_genboreeTrack()
{
  // Check Primer Track
  var trackTypeName = $F('primerTrackType');
  if( !trackTypeName || trackTypeName.length == 0 )
  {
    return showFormError('primerTrackType_lbl', 'primerTrackType', "You must enter a Genboree track type and subtype for the primer pairs!" );
  }
  else
  {
    unHighlight( 'primerTrackType_lbl' ); 
  }
  var trackSubtypeName = $F('primerTrackSubtype');
  if( !trackSubtypeName || trackSubtypeName.length == 0 )
  {
    return showFormError('primerTrackSubtype_lbl', 'primerTrackSubtype', "You must enter a Genboree track type and subtype for the primer pairs!" );
  }
  else
  {
    unHighlight( 'primerTrackSubtype_lbl' ); 
  }
  
  // Check Amplicon Track
  trackTypeName = $F('ampliconTrackType');
  if( !trackTypeName || trackTypeName.length == 0 )
  {
    return showFormError('ampliconTrackType_lbl', 'ampliconTrackType', "You must enter a Genboree track type and subtype for the amplicon!" );
  }
  else
  {
    unHighlight( 'ampliconTrackType_lbl' ); 
  }
  trackSubtypeName = $F('ampliconTrackSubtype');
  if( !trackSubtypeName || trackSubtypeName.length == 0 )
  {
    return showFormError('ampliconTrackSubtype_lbl', 'ampliconTrackSubtype', "You must enter a Genboree track type and subtype for the amplicon!" );
  }
  else
  {
    unHighlight( 'ampliconTrackSubtype_lbl' ); 
  }
  
  return true ;
}

//-----------------------------------------------------------------------------
// POP-UP HELP: in this function, make a pop-up help for each parameter/field in the form.
// This is done by supplying a helpSection arg indicating what help info to display.
//-----------------------------------------------------------------------------
function overlibHelp(helpSection)
{
  var overlibCloseText = '<FONT COLOR=white><B>X&nbsp;</B></FONT>' ;
  var leadingStr = '&nbsp;<BR>' ;
  var trailingStr = '<BR>&nbsp;' ;
  var helpText;
  
  if(helpSection == "expname")
  {
    overlibTitle = "Help: Job Name" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Give this HGSC Primer Design job a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "template_track")
  {
    overlibTitle = "Help: Template Track" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select an annotation track to design primers against.</LI>" ;
    helpText += "  <LI>Each annotation in the track will be treated as a template for which primers are desired.</LI>" ;
    helpText += "  <LI>You may get multiple primer-pairs for each template.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "hgscProj")
  {
    overlibTitle = "Help: HGSC Registered Project" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Indicate if this job is a formal HGSC project.</LI>" ;
    helpText += "  <LI>For most uses, this will be 'no'. HGSC employees, consult your S.O.P.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "primerTrack" )
  {
    overlibTitle = 'Help: Primer Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The primer pairs will be uploaded to Genboree in this track.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "ampliconTrack" )
  {
    overlibTitle = 'Help: Amplicon Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The amplicons annotations will be uploaded to Genboree in this track.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  overlibBody = helpText;
  return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F', 
                  CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
                  CLOSETEXT, overlibCloseText, WIDTH, '300');
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
  if(elem.focus) elem.focus() ;
  if(elem.select) elem.select() ;
  return false ;
}

function highlight( id )
{ 
  $(id).style["color"] = "#FF0000";
}

function unHighlight( id )
{ 
  $(id).style["color"] = "#000000";
}

// Verify that expname is unique.
function unique_expname()
{
   var expname = $F('expname') ;
   for( var ii=0; ii<=USED_EXP_NAMES.length; ii++ )
   {
     if(expname == USED_EXP_NAMES[ii])
     {
       return showFormError( 'expnameLabel', 'expname', ( "'" + expname + "' is already used as an experiment name in this group.\nPlease select another.") );
     }
   }
   return true;
}

// Verify the expname looks ok.. 
function validate_expname()
{
  var expname = $F('expname');
  if( !expname || expname.length == 0 )
  {
    return showFormError( 'expnameLabel', 'expname', "You must enter a job name!" ) ;
  }
  else
  {
    newExpname = expname.replace(/\\|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\||\;|\'|\>|\<|\/|\?/g, '_')
    if(newExpname != expname)
    {
      return showFormError( 'expnameLabel', 'expname', "Unacceptable letters in Experiment Name have been replaced with '_'.\n\nNew Experiment Name is: '" + newExpname + "'.\n");
    }
    else
    {
      unHighlight( 'expnameLabel' ); 
    }
  }
  return true ;
}

// Validate that a track is selected. 
function validate_track()
{
  if( $F('template_lff') == "selectATrack" )
  {
    return showFormError( 'trackLabel', 'template_lff', "You must select a template track!" );
  }
  else
  {
    unHighlight( 'trackLabel' ); 
  }
  return true ;
}
//-----------------------------------------------------------------------------                    