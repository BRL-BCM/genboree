// Uses prototype.js standard library file
// Uses util.js genboree library file
// Uses querytool.js genboree library file for query-tool support

// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

//-------------------------------------------------------------------
// INITIALIZE your page/javascript once it loads if needed.
//-------------------------------------------------------------------
addEvent(window, "load", init_toolPage) ;
function init_toolPage()
{
  // Prime selection criteria UI with 1 rule
  resetQueryUI() ;
  return ;
}

//-------------------------------------------------------------------
// RESET implementation
//-------------------------------------------------------------------
// OPTIONAL: Implement a toolReset() function that will correctly reset your
// tool's form to its initial state.
function toolReset()
{
  $('expname').value = '' ;
  $('trackType').value = '' ;
  $('trackSubtype').value = '' ;
  $('trackClass').value = '' ;
  // unselect all the tracks
  var trackList = $('trackList1') ;
  var liElems = trackList.getElementsByTagName('li') ;
  for(var ii=0; ii<liElems.length; ii++)
  {
    // reset the input checkboxes
    var inputs = liElems[ii].getElementsByTagName('input') ;
    for(var jj=0; jj<inputs.length; jj++)
    {
      var idx = inputs[jj].id.indexOf('_chkbx') ;
      if(inputs[jj].id.indexOf('_chkbx') > -1)
      {
        inputs[jj].checked = false ;
      }
    }
  }
  // reset the selection criteria
  resetQueryUI() ;
  return ;
}

//-------------------------------------------------------------------
// VALIDATE *WHOLE* FORM
// - Call *each* specific validator method from here
//-------------------------------------------------------------------
// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  // Standard validations:
  if(validate_expname() == false) { return false; }
  if(unique_expname() == false) { return false; }
  if(validate_tracks() == false) { return false; }
  // Custom validations:
  if(validate_genboreeTrack() == false) { return false; }
  if(prepAVPsubmit('pdw', 'rulesJson') == false) { return false ; }
  return true ;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------
// Validate Genboree track name if to be uploaded.
function validate_genboreeTrack()
{
  var trackClass = $F('trackClass')
  if( !trackClass || trackClass.length == 0 )
  {
    return showFormError('trackClass_lbl', 'trackClass', "You must enter a Genboree track class for the tiles output track!" );
  }
  else
  {
    unHighlight( 'trackClass_lbl' );
  }
  var trackTypeName = $F('trackType');
  if( !trackTypeName || trackTypeName.length == 0 )
  {
    return showFormError('trackType_lbl', 'trackType', "You must enter a Genboree track type and subtype for the\ngenerated tiling annotations!" );
  }
  else
  {
    unHighlight( 'trackType_lbl' );
  }

  var trackSubtypeName = $F('trackSubtype');
  if( !trackSubtypeName || trackSubtypeName.length == 0 )
  {
    return showFormError('trackSubtype_lbl', 'trackSubtype', "You must enter a Genboree track type and subtype for the\nextracted annotations!" );
  }
  else
  {
    unHighlight( 'trackSubtype_lbl' );
  }
  return true ;
}

// Validate that 1+ track is selected.
function validate_tracks()
{
  var trackList1 = $('trackList1') ;
  var liElems = trackList1.getElementsByTagName('li') ;
  var atLeastOne = false ;
  for(var ii=0; ii<liElems.length; ii++)
  {
    var checkbox = liElems[ii].getElementsByTagName('input')[0] ;;
    if(checkbox.checked == true)
    {
      atLeastOne = true ;
      break ;
    }
  }

  if(atLeastOne)
  {
    return true ;
  }
  else
  {
    return showFormError('trackLabel', 'trackList1', "You must select 1+ tracks to select annotations from!") ;
  }
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
    helpText += "  <LI>Give this annotation selection job a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "sourceTracks")
  {
    overlibTitle = "Help: Source Tracks" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select and order 1+ annotation tracks from which you wish to select.</LI>" ;
    helpText += "  <LI><I>ALL</I> annotations from <I>ALL</I> source tracks matching the criteria will be placed in the output track.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "criteria" )
  {
    overlibTitle = 'Help: Selection Criteria' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Enter the criteria for selecting the annotations.</LI>\n" ;
    helpText += "  <LI>You can enter criteria based on any of the standard annotation properties or for your custom attributes.</LI>\n" ;
    helpText += "  <LI>The <i>Data Type</i> you choose for the attribute will determine which operations are available.\n" ;
    helpText += "  <LI>Use the <font size='+1'>+</font> and <font size='+1'>&ndash;</font> buttons to add and remove criteria.</LI>\n" ;
    helpText += "  <LI>By default annotations must meet <b>All</b> of your criteria to be placed in the output track. But you can change this to require <b>Any</b> of the conditions to be matched.</LI>\n" ;
    helpText += "  <LI>Only 100 attributes from the database are listed. However, you can always indicate attribute names <u>manually</u> using the <b>**User Entered**</b> option at the bottom of the attribute list.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "outputTrack" )
  {
    overlibTitle = 'Help: Output Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The annotations selected will be placed in this track.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "  <LI>The 'Class' is a sort of category for the track.</LI>\n" ;
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

//-----------------------------------------------------------------------------
