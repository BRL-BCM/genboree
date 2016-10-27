// Uses prototype.js standard library file
// Uses util.js genboree library file

// STANDARD HELPER FUNCTIONS are at the bottom. Generally they don't need
// changing unless you've mis-named standard fields or something else
// bad/special.

//-------------------------------------------------------------------
// INITIALIZE your page/javascript once it loads if needed.
//-------------------------------------------------------------------
addEvent(window, "load", init_toolPage) ;
function init_toolPage()
{
  var percRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'bpOrPerc', 'perc') ;
  var bpRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'bpOrPerc', 'bp') ;
  if(!percRadio.checked && !bpRadio.checked)
  {
    percRadio.checked = true ;
  }
  return
}

//-------------------------------------------------------------------
// RESET implementation
//-------------------------------------------------------------------
// OPTIONAL: Implement a toolReset() function that will correctly reset your
// tool's form to its initial state.
function toolReset()
{
  $('expname').value = '' ;
  $('template_lff').selectedIndex = 0 ;
  $('maxAnnoSize').value = '0' ;
  $('tileSize').value = '' ;
  $('tileOverlap').value = '50.0' ;
  $('trackType').value = '' ;
  $('trackSubtype').value = '' ;
  $('excludeUntiledAnnos').checked = false ;
  getElementByIdAndValue(TOOL_PARAM_FORM, 'bpOrPerc', 'perc').checked = true ;
  getElementByIdAndValue(TOOL_PARAM_FORM, 'bpOrPerc', 'bp').checked = false ;
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
  if(validate_track() == false) { return false; }  
  // Custom validations: 
  if(validate_maxAnnoSize() == false) { return false; }
  if(validate_tileOverlap() == false) { return false; }
  if(validate_tileSize() == false) { return false ; }
  if(validate_tilePads() == false) { return false ; }
  if(validate_genboreeTrack() == false) { return false; } 

  return true;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------
// Validate anno size to tile 
function validate_maxAnnoSize()
{
  var maxAnnoSize = $F('maxAnnoSize') ;
  if( !maxAnnoSize || !validatePositiveInteger(maxAnnoSize)  || maxAnnoSize <= 1 )
  {
    return showFormError('maxAnnoSize_lbl', 'maxAnnoSize', "The maximum annotation size must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'maxAnnoSize_lbl' ); 
  }
  return true ;
}

// Validate tile size info
function validate_tilePads()
{
  var tileSize = $F('tileSize') ;
  if( !tileSize || !validatePositiveInteger(tileSize) )
  {
    return showFormError('tileSize_lbl', 'tileSize', "The general tile size must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'tileSize_lbl' ); 
  }
  
  var minTileSize = $F('minTileSize') ;
  if( !minTileSize || !validatePositiveInteger(minTileSize) )
  {
    return showFormError('minTileSize_lbl', 'minTileSize', "The minimum tile size must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'tileSize_lbl' ); 
  }
  return true ;    
}

// Validate tile padding info
function validate_tileSize()
{
  var leftPad = $F('leftAnnoPad') ;
  if( !leftPad || !validatePositiveInteger(leftPad) )
  {
    return showFormError('tilePadding_lbl', 'leftAnnoPad', "The paddings must be a positive integer!") ;
  }
  else
  {
    unHighlight( 'tilePadding_lbl' ); 
  }
  
  var rightPad = $F('rightAnnoPad') ;
  if( !rightPad || !validatePositiveInteger(rightPad) )
  {
    return showFormError('tilePadding_lbl', 'rightAnnoPad', "The paddings must be a positive integer!") ;
  }
  else
  {
    unHighlight( 'tilePadding_lbl' ); 
  }
  return true ;    
}

// Validate amount of overlap 
function validate_tileOverlap()
{
  var tileOverlap = $F('tileOverlap') ;
  if( !tileOverlap || !validatePositiveNumber(tileOverlap) )
  {
    return showFormError('tileOverlap_lbl', 'tileOverlap', "Tile overlap must be a positive integer!" );
  }
  else 
  {
    var percRadio = getElementByIdAndValue(TOOL_PARAM_FORM, 'bpOrPerc', 'perc') ;
    if( tileOverlap > 100 && percRadio.checked )
    {
      return showFormError( 'tileOverlap_lbl', 'tileOverlap', "Tile overlap cannot be >100%. What does that mean?" );
    }
    else if( (tileOverlap > parseFloat($F('tileSize'))) && !percRadio.checked )
    {
      return showFormError( 'tileOverlap_lbl', 'tileOverlap', "Tile overlap cannot be larger than annotation tile size!" ) ;
    }
    else
    {
      unHighlight( 'tileOverlap_lbl' ); 
    }
  }
  return true ;
}

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

// Coordinate Tile size with 'large' anno size
function setTileSize()
{
  var maxAnnoSize = $('maxAnnoSize') ;
  var maxAnnoSizeValue = $F('maxAnnoSize') ;
  var tileSize = $('tileSize') ;
  var tileSizeValue = $F('tileSize') ;  
  if( (!tileSizeValue || tileSizeValue.length == 0) && (maxAnnoSizeValue && maxAnnoSizeValue > 0) )
  {
    tileSize.value = maxAnnoSizeValue ;
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
    helpText += "  <LI>Give this tiling job a name.</LI>" ;
    helpText += "  <LI>You will use this name to retrieve your results later!</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "template_track")
  {
    overlibTitle = "Help: Template Track" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select an annotation track having large annotations you wish to tile across.</LI>" ;
    helpText += "  <LI>Each annotation in the track will be examined to see if it is 'too large' and if so, a tiling set of annotations spanning it will be created.</LI>" ;
    helpText += "  <LI>You will define 'too large' and how to do the tiling below.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "maxAnnoSize")
  {
    overlibTitle = "Help: Define 'Large' Annotations" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Annotations over this many base-pairs will have a tiling set generated for them.</LI>" ;
    helpText += "  <LI>Annotations under this size will not be tiled across. They can be included in the output track, however.</LI>" ;
    helpText += "  <LI>This number also determines the <i>size of the tiles</i>, unless you override it.</LI>" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "tilePadding" )
  {
    overlibTitle = "Help: Tile Padding" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>You can pad the annotations prior to tiling (actually prior to <i>deciding</i> to tile or not).</LI>\n" ;
    helpText += "  <LI>This is useful to ensure <i>boundary bases</i> are covered in the tiles (e.g. tiling exons, with 10bp padding to ensure exon-intron boundaries are covered).</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(helpSection == "tileOverlap" )
  {
    overlibTitle = "Help: Tile Overlap" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Define how much each tile should overlap with the next.</LI>\n" ;
    helpText += "  <LI>The default overlap of 50% means that each tile will have 50% overlap with the next tile, when tiling across 'large' annotations.</LI>\n" ;
    helpText += "  <LI>Alternatively, overlap can be a fixed number of base-pairs.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(helpSection == "tileSize" )
  {
    overlibTitle = "Help: Tile Size" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Define how large each tile should be. Each annotation will be covered by tiles of this size, but with the <u>last tile possibly smaller</u>.</LI>\n" ;
    helpText += "  <LI>The last tile covering an annotation will stop <i>at the end of the annotation</i>, unless that would make too small a tile!</LI>\n" ;
    helpText += "  <LI>The default of 1 bp means that even if the last tile only involves the last base of the annotation, that 1 bp will be a tile (but it is guarranteed your tiles won't go beyond the annotation). If you don't like this, you can specify a larger minimum annotation size but in this case the last tile may extend past the end of the annotation.</LI>\n" ;
    helpText += "  <LI>The last tile covering an annotation will not be smaller than the <i>minimum tile size</i>.</LI>\n" ;
    helpText += "  <LI>If you want <i>all</i> tiles to be <i>exactly</i> the same size, even the last one, set the minimum tile size equal to the general tile size.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(helpSection == "tileTrack" )
  {
    overlibTitle = 'Help: Output Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The tiling annotations used to span 'large' annotations will be placed in this track.</LI>\n" ;
    helpText += "  <LI>A Track 'Type' and Track 'Subytpe' must be provided for this option.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp;&nbsp;  Type:Subtype</LI>\n" ;
    helpText += "  <LI>The 'Class' is a sort of category for the track.</LI>\n" ;
    helpText += "</UL>\n\n";
  }
  else if(helpSection == "excludeUntiledAnnos" )
  {
    overlibTitle = 'Help: Amplicon Tm' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>By default, any source annotations that are not 'large' are included in the output.</LI>\n" ;
    helpText += "  <LI>This gives you a full set of appropriately-sized templates in a single track for, say, input to primer design.</LI>\n" ;
    helpText += "  <LI>Checking this box causes these untiled annotations excluded from the output track. The output track will <i>only</i> contain tiling annotations.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(helpSection == "uniqAnnoNames" )
  {
    overlibTitle = 'Help: Enforce Sensible &amp; Unique Annotations' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Tile names will be formed from the annotation (e.g. gene) name, the annotation index within the group (e.g. exon number within a gene), and the tile count.</LI>\n" ;
    helpText += "  <LI>The <I>Yth</I> tile of the <I>Xth</I> annotation (e.g. exon) within the '<I>myGene</I>' annotation group (eg gene) will have the name:<BR>&nbsp;&nbsp;<I>myGene_X.Y</I></LI>\n" ;
    helpText += "  <LI>The annotation order is determined by the reference strand.</LI>\n" ;
    helpText += "  <LI>Otherwise, tiles strictly by appending the tile count and using unordered data.</LI>\n" ;
    helpText += "  <LI>NOTE: untiled ('short') annotations are considered to be their own tile (tile '.1') in the output.</LI>\n" ;
    helpText += "</UL>\n\n";  
  }
  else if(helpSection == "stripVerNums" )
  {
    overlibTitle = 'Help: Strip Version Numbers' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Removes any version numbers from the annotation name before naming tiles.</LI>\n" ;
    helpText += "  <LI>Useful for normalizing names when the source track contains templates (e.g. exons) from things like splice variants, each variant which has a different name but all belong to a single gene.</LI>\n" ;
    helpText += "  <LI>Version numbers are expected to be .1, .2, .3, etc, on the end of the annotation name. If some proprietary scheme is used, this option will not work for you.</LI>\n" ;
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