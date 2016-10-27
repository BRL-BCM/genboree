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

//-------------------------------------------------------------------
// VALIDATE *WHOLE* FORM
// - Call *each* specific validator method from here
//-------------------------------------------------------------------
// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  // Standard validations:
  if(!validate_expname()) { return false; }
  if(!validate_emptyTrack()) { return false ; }
  if(!unique_expname()) { return false; }
  if(!validate_track()) { return false; }
  // Custom validations:
  if(!validate_minProbes()) { return false ; }
  if(!validate_threshold()) { return false; }
  if(!validate_genboreeTrack()) { return false; }

  return true;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------
function validate_minProbes()
{
  var minProbes = $F('minProbes') ;
  if(minProbes.length <= 0)
  {
    unHighlight('minProbes_lbl') ;
  }
  else if( !minProbes || !validatePositiveInteger(minProbes) || minProbes < 0 )
  {
    return showFormError('minProbes_lbl', 'minProbes', "The minimum probes must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'minProbes_lbl' ) ;
  }
  return true ;
}

function validate_threshold()
{
  var threshold = $F('threshold') ;
  if( !threshold || !validatePositiveNumber(threshold) || threshold < 0 )
  {
    return showFormError('threshold_lbl', 'threshold', "The threshold must be a positive non-zero number!") ;
  }
  else
  {
    unHighlight( 'threshold_lbl' );
  }
  return true ;
}

// Validate Genboree track name if to be uploaded.
function validate_genboreeTrack()
{
  var trackClass = $F('trackClass')
  if( !trackClass || trackClass.length == 0 )
  {
    return showFormError('trackClass_lbl', 'trackClass', "You must enter a Genboree track class for the output track!" );
  }
  else
  {
    unHighlight( 'trackClass_lbl' );
  }
  var trackTypeName = $F('trackType');
  if( !trackTypeName || trackTypeName.length == 0 )
  {
    return showFormError('trackType_lbl', 'trackType', "You must enter a Genboree track type for the output track!" );
  }
  else
  {
    unHighlight( 'trackType_lbl' );
  }

  var trackSubtypeName = $F('trackSubtype');
  if( !trackSubtypeName || trackSubtypeName.length == 0 )
  {
    return showFormError('trackSubtype_lbl', 'trackSubtype', "You must enter a Genboree track subtype for the output track!" );
  }
  else
  {
    unHighlight( 'trackSubtype_lbl' );
  }

  // Check if track name is already present.
  var userTrackEncoded = escape(trackTypeName).gsub(/\+/, "%2B") + ":" + escape(trackSubtypeName).gsub(/\+/, "%2B") ;
  // -- ASSUMES the page has the variable 'jsTrackMap' set up as a Prototype Hash
  if( jsTrackMap.get(userTrackEncoded) )
  {
    // If so, show dialog asking if it's ok to load data into existing track.
    // We need to block going any further until answer is given.
    var existingTrackOK =   confirm(  "The track you provided, '" + unescape(userTrackEncoded) + "', already exists.\n\n" +
                                      "Do you still want to add the tool output to the existing track?");
    if(!existingTrackOK)
    {
      $('trackType').focus() ;
      $('trackType').select() ;
      return false ;
    }
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
  var leadingStr = '&nbsp;<br />' ;
  var trailingStr = '<br />&nbsp;' ;
  var helpText;

  if(helpSection == "expname")
  {
    overlibTitle = "Help: Job Name" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Give this job a name.</li>" ;
    helpText += "  <li>You will use this name to retrieve your results later!</li>" ;
    helpText += "</ul>\n\n" ;
  }
  else if(helpSection == "input_track")
  {
    overlibTitle = "Help: Input Track" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Select an annotation track on which you wish to do segmentation.</li>" ;
    helpText += "</ul>\n\n" ;
  }
  else if(helpSection == "threshold" )
  {
    overlibTitle = "Help: Conditions" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>You can require segments to be comprised of at least a <i>minimum</i> number of probes; this should result in more meaningful segments.</li>"
    helpText += "  <li>Also you can choose the threshold that a segment must exceed.</li>\n" ;
    helpText += "  <li>The threshold value will be treated <i>either</i>:\n<ul style=\"padding-left: 2em; text-indent: 0pt;\">\n" ;
    helpText += "     <li>as an absolute mean log-ratio score the segment must exceed to be output <i>OR</i></li>" ;
    helpText += "     <li>as the number of standard deviations from the global mean, the segment's mean log-ratio score must exceed</li>" ;
    helpText += "  </ul></li>\n"
    helpText += "  <li>Example 1, if you enter '2.0' as a standard deviation threshold:\n<ul style=\"padding-left: 2em; text-indent: 0pt;\">\n" ;
    helpText += "    <li>a segment whose mean log-ratio is greater than 2 standard deviations from the mean log-ratio <i>all</i> the probes (annotations) will be output</li>\n" ;
    helpText += "    <li>a segment whose mean log-ratio is within 2 standard deviations from the mean log-ratio of <i>all</i> the probes (annotations) will NOT be output</li>\n" ;
    helpText += "  </ul></li>"
    helpText += "  <li>Example 2, if you enter '0.2' as an absolute threshold:\n<ul style=\"padding-left: 2em; text-indent: 0pt;\">\n" ;
    helpText += "    <li>a segment with a mean log-ratio value of 0.3 will be kept</li>\n" ;
    helpText += "    <li>a segment with a mean log-ratio value of -0.3 will be kept</li>\n" ;
    helpText += "    <li>a segment with a mean log-ratio value of 0.1 will NOT be kept</li>\n" ;
    helpText += "  </ul></li>"
    helpText += "</ul>\n\n";
  }
  else if(helpSection == "outputTrack" )
  {
    overlibTitle = 'Help: Output Track' ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>The resulting annotations will be placed in this track.</li>\n" ;
    helpText += "  <li>A Track 'Type' and Track 'Subytpe' must be provided for this option.</li>\n" ;
    helpText += "  <li>The track name will look like:<br />&nbsp;&nbsp;  Type:Subtype</li>\n" ;
    helpText += "  <li>The 'Class' is a sort of category for the track.</li>\n" ;
    helpText += "</ul>\n\n";
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
    var newExpname = expname.replace(/\`|\|\!|\@|\#|\$|\%|\^|\&|\*|\(|\)|\+|\=|\||\;|\'|\>|\<|\/|\?/g, '_')
    if(newExpname != expname)
    {
      $('expname').value = newExpname ;
      return showFormError( 'expnameLabel', 'expname', "Unacceptable letters in Experiment Name have been replaced with '_'.\n\nNew Experiment Name is: '" + newExpname + "'.\n");
    }
    else
    {
      unHighlight( 'expnameLabel' );
    }
  }
  return true ;
}

// Make sure we aren't dealing with an empty database
function validate_emptyTrack()
{
  // Make sure we don't have empty track database
  var firstEmptySpan = $('noTracks1') ;
  var secondEmptySpan = $('noTracks2') ;
  if(firstEmptySpan || secondEmptySpan)
  {
    alert("This database has no tracks, so you can't submit this type of tool.") ;
    return false ;
  }
  else
  {
    return true ;
  }
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
