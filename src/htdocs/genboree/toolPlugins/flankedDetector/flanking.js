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
  if(!unique_expname()) { return false; }
  if(!validate_track()) { return false; }
  // Custom validations:
  if(!validate_radius()) { return false; }
  if(!validate_secondTrack()) { return false; }
  if(!validate_genboreeTrack()) { return false; }

  // Custom manipulations
  secondTrack2Json()
  return true;
}

function secondTrack2Json()
{
  var jsonInput = $('secondTrackJson') ;
  var jsonStr = "[" ;
  var chkboxes = $$('.2ndTrackChkbx') ;
  chkboxes.each( function(item)
  {
    if(item.checked)
    {
      jsonStr += ( "\"" + item.value + "\"," ) ;
    }
    item.remove() ;
  } );
  jsonStr = jsonStr.gsub(/,$/, "") ;
  jsonStr += "]" ;
  jsonInput.value = escape(jsonStr) ;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------
function validate_radius()
{
  var radius = $F('radius') ;
  if( !radius || !validatePositiveInteger(radius)  || radius < 0 )
  {
    return showFormError('radius_lbl', 'radius', "The radius must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'radius_lbl' );
  }
  return true ;
}

function validate_secondTrack()
{
  var boxes = $$('.2ndTrackChkbx') ;
  var found = 0 ;
  for(ii=0; ii < boxes.length; ii++)
  {
    if(boxes[ii].checked)
    {
      found = 1 ;
    }
  }

  if(found == 0)
  {
    return showFormError('secondTrack_lbl', 'secondTrack', "One or more second tracks must be selected") ;
  }
  else
  {
    unHighlight( 'secondTrack_lbl' );
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
    helpText += "  <li>You can use this name to retrieve your results later!</li>" ;
    helpText += "</ul>\n\n" ;
  }
  else if(helpSection == "first_track")
  {
    overlibTitle = "Help: First Track" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Select an annotation track from which you wish to extract flanked annotations.</li>" ;
    helpText += "  <li>You will be selecting annotations from this track that are flanked with annotations from the other track(s).</li>" ;
    helpText += "  <li>You can also choose to select <i>non</i>-flanked annotations. See the 'Conditions' section.</li>" ;
    helpText += "</ul>\n\n" ;
  }
  else if(helpSection == "second_track" )
  {
    overlibTitle = "Help: Second Track" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Name(s) of the second operand track(s). These are the tracks that the first annotation will be compared to.</li>\n" ;
    helpText += "</ul>\n\n";
  }
  else if(helpSection == "anyOrAllCondition" )
  {
    overlibTitle = "Help: Any or All Condition" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Choose whether annotations from the first track must be flanked by annotations from:<ul>\n" ;
    helpText += "  <li>ANY of the second tracks - Each end needs to flanked by only one annotation from any of the second tracks</li>\n" ;
    helpText += "  <li>ALL of the second tracks - Each end needs to flanked by with an annotation from <i>each</i> of the second tracks.</li>\n" ;
    helpText += "</li></ul></ul>\n\n";
  }
  else if(helpSection == "oneEndCondition" )
  {
    overlibTitle = "Help: One or Both condition" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Choose how many sides of the annotation must be flanked in order to be output:<ul>\n" ;
    helpText += "  <li>BOTH - there must be a flanking annotation on both sides</li>\n" ;
    helpText += "  <li>ONE - only one side must have a flanking annotation</li>\n" ;
    helpText += "</li></ul></ul>\n\n";
  }
  else if(helpSection == "nonFlankingCondition" )
  {
    overlibTitle = "Help: Non-Flanking condition" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Check this box to output annotations from the First Track that are <i>not</i> flanked.</li>\n" ;
    helpText += "  <li>Your conditions above will still be used to defined 'flanked'.</li>\n" ;
    helpText += "</ul>\n\n";
  }
  else if(helpSection == "flankedTrack" )
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
