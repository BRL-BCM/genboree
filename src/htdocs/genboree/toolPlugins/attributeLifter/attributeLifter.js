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
var fixedAttrValues = [
                        "CLASS",
                        "NAME",
                        "TYPE",
                        "SUBTYPE",
                        "CHROM",
                        "START",
                        "STOP",
                        "STRAND",
                        "PHASE",
                        "SCORE",
                        "QSTART",
                        "QSTOP",
                        "SEQUENCE",
                        "FREEFORM"
                      ] ;
var fixedAttrDisplays =  [
                          "Anno. Class",
                          "Anno. Name",
                          "Anno. Type",
                          "Anno. Subtype",
                          "Anno. Chrom",
                          "Anno. Start",
                          "Anno. Stop",
                          "Anno. Strand",
                          "Anno. Phase",
                          "Anno. Score",
                          "Anno. Qstart",
                          "Anno. Qstop",
                          "Anno. Sequence",
                          "Anno. Free Comments"
                        ] ;
var fixedAttrAliases =  [
                          "lffClass",
                          "lffName",
                          "lffType",
                          "lffSubtype",
                          "lffChrom",
                          "lffStart",
                          "lffStop",
                          "lffStrand",
                          "lffPhase",
                          "lffScore",
                          "lffQstart",
                          "lffQstop",
                          "lffSequence",
                          "lffFreeform"
                        ] ;

//-------------------------------------------------------------------
// VALIDATE *WHOLE* FORM
// - Call *each* specific validator method from here
//-------------------------------------------------------------------
// REQUIRED: Implement a validate() function that will validate your form and
// decide whether to submit (return true) or not (return false).
function validate()
{
  var retVal = false ;
  // Standard validations:
  if(validate_expname())
  {
    if(validate_emptyTrack())
    {
      if(unique_expname())
      {
        if(validate_track())
        {
          // Custom validations:
          if(validate_radius())
          {
            if(validate_secondTrack())
            {
              if(validate_attributes())
              {
                if(validate_aliases())
                {
                  if(validate_genboreeTrack())
                  {
                    // Parse and final validate:
                    if(parseInput())
                    {
                      retVal = true ;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  return retVal  ;
}

//-------------------------------------------------------------------
// IMPLEMENT EACH VALIDATION
// - keep each validation method focused to 1 field...maybe 2 for special validations
//-------------------------------------------------------------------
// Validate anno size to tile
function validate_radius()
{
  var radius = $F('radius') ;
  if( !radius || !validatePositiveInteger(radius)  || radius < 0 )
  {
    return showFormError('radius_lbl', 'radius', "The radius must be a positive non-zero integer!") ;
  }
  else
  {
    unHighlight( 'radius_lbl' ) ;
  }
  return true ;
}

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

// Validate anno size to tile
function validate_secondTrack()
{
  var boxes = $$('.2ndTrackChkbx') ;
  var found = 0 ;
  var ii = 0;
  for(ii=0; ii < boxes.length; ii++)
  {
    if(boxes[ii].checked)
    {
      found = 1 ;
    }
  }
  if(found == 0)
  {
    return showFormError('secondTrackLabel', 'null', "One or more second tracks must be selected") ;
  }
  else
  {
    unHighlight( 'secondTrackLabel' ) ;
  }
  return true ;
}

// Validate anno size to tile
function validate_attributes()
{
  var boxes = $$('.attrCheck') ;
  var found = 0 ;
  var ii = 0;
  for(ii=0; ii < boxes.length; ii++)
  {
    if(boxes[ii].checked)
    {
      found = 1 ;
    }
  }
  if(found == 0)
  {
    return showFormError('secondTrackLabel', 'null', "Select at least one attribute to lift/copy from at least one track.") ;
  }
  else
  {
    unHighlight( 'secondTrackLabel' ) ;
  }
  return true ;
}

// Validate new attribute names
function validate_aliases()
{
  var inputs = $$('.attrAlias') ;
  for(ii=0; ii < inputs.length; ii++)
  {
    var input = inputs[ii] ;
    var inputVal = input.value ;
    if(inputVal.strip().length < 1)
    {
      return showFormError('secondTrack_lbl', 'secondTrack', "One of your new attribute names is blank. Please fix it before submitting.") ;
    }
    else if(matchObj = /(;|=)/.exec(inputVal))
    {
      return showFormError('secondTrack_lbl', 'secondTrack', "One of your new attribute names has a '" + matchObj[1] + "' character in it, which is not allowed. Please fix it before submitting.") ;
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
    return showFormError('trackClass_lbl', 'trackClass', "You must enter a Genboree track class for the output track!" ) ;
  }
  else
  {
    unHighlight( 'trackClass_lbl' ) ;
  }
  var trackTypeName = $F('trackType') ;
  if( !trackTypeName || trackTypeName.length == 0 )
  {
    return showFormError('trackType_lbl', 'trackType', "You must enter a Genboree track type for the output track!" ) ;
  }
  else
  {
    unHighlight( 'trackType_lbl' ) ;
  }

  var trackSubtypeName = $F('trackSubtype') ;
  if( !trackSubtypeName || trackSubtypeName.length == 0 )
  {
    return showFormError('trackSubtype_lbl', 'trackSubtype', "You must enter a Genboree track subtype for the output track!" ) ;
  }
  else
  {
    unHighlight( 'trackSubtype_lbl' ) ;
  }

  // Check if track name is already present.
  var userTrackEncoded = fullEscape(trackTypeName) + ":" + fullEscape(trackSubtypeName).gsub(/\+/, "%2B") ;
  // -- ASSUMES the page has the variable 'jsTrackMap' set up as a Prototype Hash
  if( jsTrackMap.get(userTrackEncoded) )
  {
    // If so, show dialog asking if it's ok to load data into existing track.
    // We need to block going any further until answer is given.
    var existingTrackOK =   confirm(  "The track you provided, '" + unescape(userTrackEncoded) + "', already exists.\n\n" +
                                      "Do you still want to add the tool output to the existing track?") ;
    if(!existingTrackOK)
    {
      return false ;
    }
  }
  return true ;
}

//-----------------------------------------------------------------------------
// UI-SPECIFIC FUNCTIONS
//-----------------------------------------------------------------------------
function toggleAlias(chkbox)
{
  if(chkbox)
  {
    var aliasDivId = chkbox.id + "div" ;
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

function toggleAllAttrs(chkbox)
{
  if(chkbox)
  {
    var baseId = chkbox.id.gsub(/:ALL_ATTRS$/, '') ;
    // Get all the other attributes' checkboxes from their container div:
    var attrChkboxes = $(baseId + ':attrsListDiv').select(".attrCheck") ;
    attrChkboxes.each(  function(attrChkbox)
    {
      attrChkbox.checked = chkbox.checked ;
      toggleAlias(attrChkbox) ;
    });
  }
  return ;
}

var currSelectIdx = 0 ;
function toggleFirstTrack(selectElem)
{
  if(selectElem)
  {
    var selOptions = selectElem.options ;
    var selIndex = selectElem.selectedIndex ;
    // Show the hidden 2nd track if any.
    if(currSelectIdx > 0)
    {
      var oldTrackOption = selOptions[currSelectIdx] ;
      var oldTrack = oldTrackOption.value ;
      var trackDiv = $('trackDiv' + oldTrack) ;
      trackDiv.show() ;
    }
    // Hide the selected track if appropriate
    if(selIndex > 0)
    {
      var trackOption = selOptions[selIndex] ;
      var track = trackOption.value ;
      var trackDiv = $('trackDiv' + track) ;
      trackDiv.hide() ;
    }
    currSelectIdx = selIndex ;
  }
  return ;
}

//-----------------------------------------------------------------------------
// Called when user checks a second track to include
// displays table box listing attributes for that
// track
function attsDisplay(selectObj)
{
  // See which options what selected
  var track = selectObj.value ;
  var isChecked = selectObj.checked ;
  // Get paramsTable
  var paramsTable = $('paramsTable' + track) ;
  // Get paramsRow
  var paramCell = $('paramCell' + track) ;
  // Remove existing paramDiv
  var paramDiv = $('paramDiv' + track) ;
  if(paramDiv)
  {
    paramDiv.remove() ;
  }

  if(isChecked)
  {
    // Make a new paramDiv with correct form fields and such
    paramDiv = document.createElement("div") ;
    Element.extend(paramDiv) ;
    paramDiv.id = paramDiv.name = 'paramDiv' + track ;

    // -- ASSUMES the page has the variable jsAttrMap set up as a hash of track names, with
    // each key containing an array of its attribute names
    // This array should also include standard lff fields, since we can lift these over too:
    // CLASS NAME TYPE SUBTYPE CHROM START STOP STRAND PHASE SCORE QSTART QSTOP
    divString = "<b><nowrap>Select attributes to copy from this track to the new track:</b></nowrap><br>" ;
    divString +=  '<div style="padding:0px; margin:0px; width:60%; float:left;">' +
                    '<input name="' + track + ':ALL_ATTRS" id="' + track + ':ALL_ATTRS" value="" type="checkbox" class="ALL_ATTRS" style="vertical-align: middle;" onclick="toggleAllAttrs(this)"></input>' +
                    'ALL ATTRIBUTES' +
                  '</div><br clear="all">'

    divString += '<div id="' + track + ':attrsListDiv" name="' + track + ':attrsListDiv" style="padding:0px; margin:0px; width:100%; float:left;">'
    // Add fixed-field as 'attributes' to lift:
    for(var ii=0; ii<fixedAttrDisplays.length; ii++)
    {
      var fixVal = fixedAttrValues[ii] ;
      var escFixVal = fullEscape(fixVal) ;
      var fixDisp = fixedAttrDisplays[ii] ;
      var escFixDisp = fixDisp.escapeHTML() ;
      var fixAlias = fixedAttrAliases[ii] ;
      var escFixAlias = fixAlias.escapeHTML() ;
      divString +=  '<div style="padding:0px; margin:0px; width:60%; float:left;">' +
                      '<input name="' + track + ':' + escFixVal + '" id="' + track + ':' + escFixVal + '" value="" type="checkbox" class="attrCheck" style="vertical-align: middle;" onclick="toggleAlias(this)"></input>' +
                      escFixDisp +
                    '</div>' +
                    '<div id="' + track + ':' + escFixVal + 'div" name="' + track + ':' + escFixVal + 'div" style="padding:0px; margin:0px; width:39%;float:left;display:none;">' +
                      ' as ' +
                      '<input type="text" id="' + track + ':' + escFixVal + '_genbAlias" name="' + track + ':' + escFixVal + '_genbAlias" value="' + escFixAlias + '" class="attrAlias" style="font-size:8pt; width: 12em; vertical-align: middle;">' +
                    '</div><br clear="all">' ;
    }
    if(jsAttrMap.get(track)) // If this track has extra attributes
    {
      // Add each custom attribute in the track
      jsAttrMap.get(track).each( function(escAttr)
      {
        unescAttr = unescape(escAttr) ;
        if(unescAttr.strip() != '')
        {
          divString +=  '<div style="padding:0px; margin:0px; width:60%; float:left;">' +
                          '<input name="' + track + ':' + escAttr + '" id="' + track + ':' + escAttr + '" value="" type="checkbox" class="attrCheck" style="vertical-align: middle;" onclick="toggleAlias(this)"></input>' +
                          unescAttr.escapeHTML() +
                        '</div>' +
                        '<div id="' + track + ':' + escAttr + 'div" name="' + track + ':' + escAttr + 'div" style="padding:0px; margin:0px; width:39%;float:left;display:none;">' +
                          ' as ' +
                          '<input type="text" id="' + track + ':' + escAttr + '_genbAlias" name="' + track + ':' + escAttr + '_genbAlias" value="' + unescAttr + '" class="attrAlias" style="font-size:8pt; width: 12em; vertical-align: middle;">' +
                        '</div><br clear="all">' ;
        }
      });
      divString += '</div><br clear="all">'
    }

    paramDiv.update(divString)

    paramCell.appendChild(paramDiv) ;
    paramsTable.show() ;
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

function checkRadiusField()
{
  var radius = $('radius') ;
  if(radius)
  {
    radius.style.color = 'black' ;
    if(! /^\s*$/.test(radius.value) )
    {
      var radiusValue = radius.value.strip() ;

      if( ! /^\+?\d*(?:\.\d+)?(?:(?:e|E)(?:\+|\-)?\d+)?$/.test(radiusValue))
      {
        radius.style.color = 'red' ;
        return false ;
      }
    }
  }
  return true ;
}

//after validation, hide unneccessary fields and get the info from the rest
function parseInput()
{
  var tracksCheckedCount = 0 ;
  var attrsCheckedCount = 0 ;
  // -- ASSUMES the page has the variable jsAttrMap set up as a hash of track names, with
  // each key containing an array of its attribute  names
  var secondTrackStr = "" ;
  // for each URL escaped track in the hash
  var tracks = jsTrackMap.keys() ;
  var ii = 0 ;
  for(ii=0; ii<tracks.length; ii++)
  {
    // The track names are escaped(type):escaped(subtype)
    // We've used them as escaped(type:subtype) in our ids. So need to hack them back
    var unescTrack = unescape(tracks[ii]) ;
    var escTrack = fullEscape(unescTrack);
    // Now can use to look things up
    var escTrackObj = $(escTrack) ;
    if(escTrackObj)
    {
      // Is this the first track? If so, we'll want to skip storing its 2nd track settings (should be hidden, but maybe stuff was selected before hidden)
      var trackDivId = "trackDiv" + escTrack ;
      var trackDiv = $(trackDivId) ;
      if(!trackDiv.visible())
      {
        trackDiv.remove() ;
      }
      else
      {
        if(escTrackObj.checked)
        {
          tracksCheckedCount += 1 ;
          // Look for fixed-field attributes
          for(var kk=0; kk<fixedAttrDisplays.length; kk++)
          {
            var fixVal = fixedAttrValues[kk] ;
            var escFixVal = fullEscape(fixVal) ;
            // add to attribute string if it is checked
            var baseId = escTrack + ':' + escFixVal ;
            var attrChkbox = $(baseId) ;
            if(attrChkbox)
            {
              var attrAlias = $(baseId + '_genbAlias') ;
              if(attrChkbox.checked)
              {
                attrsCheckedCount += 1 ;
                // combine to make string of form required (type:subtype:attribute=newName)
                secondTrackStr += unescape(escTrack) + ':' + unescape(escFixVal) + '=' + attrAlias.value + ';' ;
              }
              // remove the attrubute check and alias inputs from the page
              attrChkbox.remove() ;
              attrAlias.remove() ;
            }
          }
          // Look for custom attributes in the track (may not have any custom attributes)
          var escAttrs = jsAttrMap.get(escTrack) ;
          if(escAttrs)
          {
            for(var jj=0; jj<escAttrs.length; jj++)
            {
              var escAttr = escAttrs[jj] ;
              // add to attribute string if it is checked
              var baseId = escTrack + ':' + escAttr ;
              var attrChkbox = $(baseId) ;
              if(attrChkbox)
              {
                var attrAlias = $(baseId + '_genbAlias') ;
                if(attrChkbox.checked)
                {
                  attrsCheckedCount += 1 ;
                  // combine to make string of form required (type:subtype:attribute=newName)
                  secondTrackStr += unescape(escTrack) + ':' + unescape(escAttr) + '=' + attrAlias.value + ';' ;
                }
                // remove the attrubute check and alias inputs from the page
                attrChkbox.remove() ;
                attrAlias.remove() ;
              }
            }
          }
          // remove the :ALL_ATTRS checkbox for this track from the page
          var allAttrs = $(escTrack + ':ALL_ATTRS') ;
          if(allAttrs)
          {
            allAttrs.remove() ;
          }
        }
        // remove track checkbox
        escTrackObj.remove() ;
      }
    }
  }
  // Unescape the value for the first track (template_lff) so it can be sent normally.
  // (it was escaped to ensure it will display)
  var templateLff = $('template_lff') ;
  var options = templateLff.options ;
  var sIdx = templateLff.selectedIndex ;
  options[sIdx].value = unescape(templateLff.value) ;

  if(tracksCheckedCount > 0 && attrsCheckedCount > 0)
  {
    // store final string in assigned hidden input for submission
    $('secondTrackStr').value = secondTrackStr ;
    return true ;
  }
  else
  {
    alert("ERROR: you need to check 1+ secondary tracks and 1+ attributes to lift/copy.") ;
    // need to reload the page because we've probably stripped out some widgets post first validation
    window.location.reload() ;
    return false ;
  }
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
  else if(helpSection == "first_track")
  {
    overlibTitle = "Help: First Track" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Select an annotation track to which to add attributes from intersecting annotations in the other tracks.</LI>" ;
    helpText += "</UL>\n\n" ;
  }
  else if(helpSection == "requireIntersect" )
  {
    overlibTitle = "Help: Require Intersect Condition" ;
    helpText = "\n<ul>\n" ;
    helpText += "  <li>Check this to ONLY output annotations in the first track that intersect something in one of the second tracks.</li>\n" ;
    helpText += "  <li>i.e. <i>skip</i> any annotation in the first track that doesn't overlap anything in the second track(s).</li>\n" ;
    helpText += "  <li>Note: your radius value will be used when determining intersection.</li>\n" ;
    helpText += "</ul>\n\n" ;
  }

  else if(helpSection == "second_track" )
  {
    overlibTitle = "Help: Second Track" ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>Name(s) of the second operand track(s). These are the tracks that the first annotation track will be compared to.</LI>\n" ;
    helpText += "  <LI>This tool extracts attributes from the second tracks and appends them to the intersecting annotations in the first track.</LI>\n"
    helpText += "  <LI>If more than one annotation overlaps, the annotation will be copied as a comma separated list. (for example: score=0.1, 0.6, 1.0)</LI>\n" ;
    helpText += "</UL>\n\n" ;
  }

  else if(helpSection == "outputTrack" )
  {
    overlibTitle = 'Help: Output Track' ;
    helpText = "\n<UL>\n" ;
    helpText += "  <LI>The resulting annotations will be placed in this track.</LI>\n" ;
    helpText += "  <LI>A Track 'Type' and Track 'Subytpe' must be provided for this option.</LI>\n" ;
    helpText += "  <LI>The track name will look like:<BR>&nbsp; &nbsp;  Type:Subtype</LI>\n" ;
    helpText += "  <LI>The 'Class' is a sort of category for the track.</LI>\n" ;
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
