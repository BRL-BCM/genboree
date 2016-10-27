// Uses prototype.js standard library file
// Uses util.js genboree library file

// INITIALIZE your page/javascript once it loads if needed.
addEvent(window, "load", init_toolPageInit) ;
function init_toolPageInit()
{
  // Nada for this tool.
  return
}

// REQUIRED: Implement a toolReset() function that will correctly reset your
// tool's form to its initial state.
function toolReset()
{
  $('expname').value = '' ;
  $('annoNames').value = '' ;
  $('trackType').value = '' ;
  $('trackSubtype').value = '' ;
  var sortList = $('rearrange_list1') ;
  var liElems = sortList.getElementsByTagName('li') ;
  for(var ii=0; ii<liElems.length; ii++)
  {
    // reset the chkbox div
    var divs = liElems[ii].getElementsByTagName('div') ;
    for(var jj=0; jj<divs.length; jj++)
    {
      var idx = divs[jj].id.indexOf('_chkdiv') ;
      if(idx == (divs[jj].id.length-7))
      {
        divs[jj].style.backgroundPosition = "0px 0px" ;
        break ;
      }
    }
    // reset the chkbox recording input
    inputs = liElems.select('.trkOrderChkbx') ;

    for(var jj=0; jj<inputs.length; jj++)
    {
      var idx = inputs[jj].id.indexOf('_chkbx') ;
      if(idx == (inputs[jj].id.length-6))
      {
        inputs[jj].value = 'false' ;
        break ;
      }
    }
    inputs = liElems[ii].select('.trkOrderInput') ;
    for(var jj=0; jj<inputs.length; jj++) { inputs[jj].value = '' ; }
  }
}

// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  var retVal = false ;
  // We need to mark the select list as invalid and only mark
  // as valid if the whole form is valid
  var selectList = $('rearrange_list1') ;
  selectList.removeClassName('isValid') ;

  // Standard validations:
  if(validate_expname())
  {
    if(unique_expname())
    {
      // Custom validations:
      if(validate_tracks())
      {
        if(validate_selectMode())
        {
          if(validate_annoNames())
          {
            if(validate_genboreeTrack())
            {
              // Form is valid, mark the list as valid so it can be processed for submission
              selectList.addClassName('isValid') ;
              retVal = true ;
            }
          }
        }
      }
    }
  }
  return retVal ;
}

// Validate select mode selection (at least one must be selected)
function validate_selectMode()
{
  var retVal = false ;
  var selectModeRadios = document.getElementsByName("selectMode") ;
  for( var ii = 0; ii < selectModeRadios.length; ii++)
  {
    if(selectModeRadios[ii].checked)
    {
      retVal = true ;
      break ;
    }
  }
  if(!retVal)
  {
    highlight('selectModeFull_lbl') ;
    highlight('selectModeIsoform_lbl') ;
    return showFormError('selectModeExact_lbl', 'selectMode', "You must select a mode of operation to use!") ;
  }
  else
  {
    unHighlight('selectModeFull_lbl') ;
    unHighlight('selectModeExact_lbl') ;
    unHighlight('selectModeIsoform_lbl') ;
    return true ;
  }
}

// Validate anno name/patterns to match
function validate_annoNames()
{
  var annoNames = $F('annoNames') ;
  if( !annoNames || annoNames.length <= 0)
  {
    return showFormError('annoNames_lbl', 'annoNames', "You must provide a list of names to match against!") ;
  }
  else
  {
    unHighlight( 'annoNames_lbl' );
  }
  return true ;
}

// Validate that 1+ source tracks were selected
function validate_tracks()
{
  var sortList = $('rearrange_list1') ;
  var liElems = sortList.getElementsByTagName('li') ;
  var atLeastOne = false ;
  for(var ii=0; ii<liElems.length; ii++)
  {
    var pseudoCheckbox = liElems[ii].select('.trkOrderChkbx')[0] ;
    if(pseudoCheckbox.value == 'true')
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
    return showFormError('trackLabel', 'rearrange_list1', "You must select 1+ tracks to select annotations from!") ;
  }
}

// Validate Genboree track name if to be uploaded.
function validate_genboreeTrack()
{
  var trackClass = $F('trackClass') ;
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
    return showFormError('trackType_lbl', 'trackType', "You must enter a Genboree track type and subtype for the\nextracted annotations!" );
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

function selectModeRadio_checked()
{
  var selectModeRadios = document.getElementsByName("selectMode") ;
  for( var ii = 0; ii < selectModeRadios.length; ii++)
  {
    if(selectModeRadios[ii].checked)
    {
      if(selectModeRadios[ii].value != "full")
      {
        $('useGeneAliases').disabled = true ;
      }
      else
      {
        $('useGeneAliases').disabled = false ;
      }
    }
  }
  return ;
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
    helpText += "  <LI>Give this selection job a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "sourceTracks")
  {
    overlibTitle = "Help: Source Tracks" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select and order 1+ annotation tracks from which you wish to select.</LI>" ;
    helpText += "  <LI><I>Drag-and-drop</I> the annotation tracks to determine the search order.</LI>" ;
    helpText += "  <LI>Tracks will be examined <i>in order</i>.</LI>" ;
    helpText += "  <LI>Only annotations from the <i>first</i> track with matching names or patterns will be selected.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "annoNames")
  {
    overlibTitle = "Help: Names to Match" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>List each annotation name or pattern to search for, one per line.</LI>" ;
    helpText += "  <LI>For pattern-based matching, use <b>*</b> for 1+ characters and <b>?</b> for any one character.</LI>" ;
    helpText += "  <LI>You may specific aliases using commas (see above)</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "outputTrack" )
  {
    overlibTitle = 'Help: Output Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The annotations selected will be placed in this track.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "useGeneAliases" )
  {
    overlibTitle = 'Help: Use Known Gene Aliases' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Your gene name may not be the name used in the track.</LI>\n" ;
    helpText += "  <LI>Check this to make use of some known aliases for certain genes, increasing the likelihood of finding a match (or, more likely, <I>many</I> matches) for your gene.</LI>\n" ;
    helpText += "  <LI>This option is recommended and only valid for <I>mammalian gene tracks</I>.</LI>\n" ;
    helpText += "  <LI>Although this helps work with the use of older or non-standard gene names, it can result in many more <I>false positiives</I>.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "selectModeExact" )
  {
    overlibTitle = 'Help: Exact matching only.' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>In this mode, annotations will only be extracted if their name <u>exactly</u> matches one of the listed names.</LI>\n" ;
    helpText += "  <LI>Each line is a different name to search for.</LI>\n" ;
    helpText += "  <LI>This option is very fast, but will leave out numbered isoforms/variants (e.g. EPS8R3.2, EPS8R3.3) and doesn't support aliases.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "selectModeIsoform" )
  {
    overlibTitle = 'Help: Match Numbered Isoforms/Versions' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>This mode is like exact-matching, except <u>numbered</u> isoforms/versions will also be extracted.</LI>\n" ;
    helpText += "  <LI>Example: 'EPS8R3' would match the exons of 3 splice-variants: 'EPS8R3', 'EPS8R3.2', 'EPS8R3.3'</LI>\n" ;
    helpText += "  <LI>Each line is a different name to search for.</LI>\n" ;
    helpText += "  <LI>This can also be done with a pattern, but this option is faster.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "selectModeFull" )
  {
    overlibTitle = 'Help: Use Full Patterns and Aliases' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Your gene name may not be the name used in the track; by using patterns and/or aliases you can still extract it.</LI>\n" ;
    helpText += "  <LI>Use this options to make use of the '*' and '?' pattern-matching feature, and/or to specify multiple aliases that all refer to a single gene.</LI>\n" ;
    helpText += "  <LI>Check the box to <i>also</i> make use of some known aliases for certain genes, increasing the likelihood of finding a match (or, more likely, <I>many</I> matches) for your gene.</LI>\n" ;
    helpText += "  <LI>The check box option is recommended and only valid for <I>mammalian gene tracks</I>.</LI>\n" ;
    helpText += "  <LI>Although this helps work with the use of older or non-standard gene names, it can result in many more <I>false positiives</I>.</LI>\n" ;
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
//-----------------------------------------------------------------------------
