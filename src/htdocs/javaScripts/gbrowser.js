var viewBox = document.viewbox;
var navBar = document.navbar;
var lastImgId = null;
var lastElemId = null;

function btnUp(a,imgId)
{
      document.images[imgId].src = "/images/" +imgId+ ".gif";
      a.blur();
}
function btnDown(a,imgId)
{
    document.images[imgId].src = "/images/" + imgId + "sd.gif";
    a.blur();
}
function btnLightup(a,imgId)
{
    document.images[imgId].src = "/images/" + imgId + "Ov.gif";
    a.blur();
}
function initMenus(viewGroupId, viewRefSeqId)
{
  form_groupIdNavBar = document.getElementById('groupIdNavBar');
  form_refSeqIdMenu = document.getElementById('refSeqIdMenu');
  if(form_groupIdNavBar != null)
  {
    form_groupIdNavBar.value = viewGroupId;
  }
  if(form_refSeqIdMenu != null)
  {
    form_refSeqIdMenu.value = viewRefSeqId;
  }
}

// Toggles display of track drop-lists for a given genboree class
function trackDisplayToggle(genbClass, action)
{
  // Deal with the show/hide buttons themselves
  var showBtn = $('genb_showTracksBtn_' + genbClass) ;
  var hideBtn = $('genb_hideTracksBtn_' + genbClass) ;
  if(showBtn && hideBtn)
  {
    if(action == 'hideTracks')
    {
      showBtn.show() ;
      hideBtn.hide() ;
    }
    else
    {
      showBtn.hide() ;
      hideBtn.show() ;
    }
  }

  // Deal with tracks
  var cssClass = ".genb_trackRow_" + genbClass ;
  var rows = $('tracksByClassTable').select(cssClass) ;
  for(var ii=0; ii<rows.length; ii++)
  {
    if(action == 'hideTracks')
    {
      rows[ii].hide() ;
    }
    else
    {
      rows[ii].show() ;
    }
  }
  return ;
}

function classDisplayToggle(genbClass, action)
{
  // Get the track selects up front
  var cssClass = '.genb_trackSelect_' + genbClass ;
  var trackSelects = $('tracksByClassTable').select(cssClass) ;
  // Process action
  switch(action)
  {
    case 'showBtns':
      var classTextDiv = $('genb_classDiv_' + genbClass) ;
      if(classTextDiv)
      {
        classTextDiv.setStyle( { width: '520px' } ) ;
      }
      var allBtnsDiv = $('genb_classDisplayAllBtnsDiv_' + genbClass) ;
      if(allBtnsDiv)
      {
        allBtnsDiv.show() ;
      }
      var noBtnsDiv = $('genb_classDisplayNoBtnsDiv_' + genbClass) ;
      if(noBtnsDiv)
      {
        noBtnsDiv.hide() ;
      }
      break ;
    case 'hideBtns':
      var classTextDiv = $('genb_classDiv_' + genbClass) ;
      if(classTextDiv)
      {
        classTextDiv.setStyle( { width: '625px' } ) ;
      }
      var allBtnsDiv = $('genb_classDisplayAllBtnsDiv_' + genbClass) ;
      if(allBtnsDiv)
      {
        allBtnsDiv.hide() ;
      }
      var noBtnsDiv = $('genb_classDisplayNoBtnsDiv_' + genbClass) ;
      if(noBtnsDiv)
      {
        noBtnsDiv.show() ;
      }
      break ;
    case 'expand':
      setTrackDisplays(trackSelects, 0) ;
      break;
    case 'compact':
      setTrackDisplays(trackSelects, 1) ;
      break;
    case 'hide':
      setTrackDisplays(trackSelects, 2) ;
      break ;
    case 'multicolor':
      setTrackDisplays(trackSelects, 3) ;
      break;
    case 'nameExpand':
      setTrackDisplays(trackSelects, 4) ;
      break;
    case 'commentExpand':
      setTrackDisplays(trackSelects, 5) ;
      break;
  }
  return ;
}

function setTrackDisplays(trackSelects, idx)
{
  for(var ii=0; ii< trackSelects.length; ii++)
  {
    var trackSelect = $(trackSelects[ii]) ;
    trackSelect.selectedIndex = idx ;
    syncTrackVisibility(trackSelect) ;
  }
  return ;
}

function syncTrackVisibility( formElem )
{
  var formObj = formElem.form ;
  var trackName = formElem.name ;
  var idx = formElem.selectedIndex ;
  for (var i=0; i<formObj.length; i++)
  {
    fldObj = formObj.elements[i] ;
    if( fldObj.type == 'select-one' && fldObj.id == trackName && fldObj.options[0].text == 'Expand' )
    {
      fldObj.selectedIndex = idx ;
    }
  }
  formObj.allTracksVisibility.selectedIndex = 0 ;
}

function getIntValue( formObj, def )
{
  var sVal = formObj.value;
  var ic = sVal.indexOf(",");
  while( ic >= 0 )
  {
    sVal = sVal.substring(0,ic)+sVal.substring(ic+1);
    ic = sVal.indexOf(",");
  }
  ic = sVal.indexOf(".");
  if( ic >= 0 )
  {
    sVal = sVal.substring(0, ic);
  }
  var iVal = def;
  if( sVal != "" && !isNaN(parseInt(sVal)) ) iVal = parseInt(sVal);
  return iVal;
}

function setEPLimits(chrSize)
{
  var arr =  transformLimits(chrSize);
  var myFrom = arr[0];
  var myTo = arr[1];

  $('entryPointFrom').value = putCommas(myFrom);
  $('entryPointTo').value = putCommas(myTo);
}

function updateEntryPointSelected()
{
  var chrName = $('entryPointIdSelection').value ;
  var chrSize = entryPointSize[chrName];
  setEPLimits(chrSize);
}

function validateNavbar()
{
  var chromosomeName = $('entryPointIdSelection').value;
  // ARJ 8/23/2005 3:00PM:
  //  We check as much as we can. But the last case--if the FROM or TO are too
  //  big--can only be checked if we have all the entrypoint information on the
  //  page. For large number of entrypoints, we may not.
  var iFrom = remCommas( $('entryPointFrom').value, -1);
  var iTo = remCommas( $('entryPointTo').value, -1);
  var minStart = 1;
  // CASE 1: are either FROM or TO less than 1 ?
  if(iFrom < minStart || iTo < minStart)
  {
    alert('"From" and "To" values must be greater or equal to 1. Fixed.') ;
    if(iFrom < minStart)
    {
      $('entryPointFrom').value = iFrom = minStart ;
    }
    if(iTo < minStart) // Maybe both were wrong, so we check to fix both independently.
    {
      $('entryPointTo').value = iTo = minStart ;
    }
    $('entryPointTo').focus() ;
    return false ;
  }

  // CASE 2: is FROM larger than TO ?
  if( iFrom > iTo )
  {
    alert( '"From" value must be less than "To" value.' ) ;
    $('entryPointFrom').value = iTo ;
    $('entryPointTo').value = iFrom ;
    $('entryPointFrom').focus();
    return false;
  }

  // CASE 3: are either FROM or TO larger than the chromosome length?
  //  We only attempt to validate the selected entrypoint and from/to if
  //  we have provided an EP droplist (i.e. there are only a few EPs). If the
  //  user is entering things manually (there are lots of EPs) then we don't
  //  check the coords vs the entrypoint length--we don't even have all the
  //  entrypoint lengths available for Javascript.
  var  numEps =0 ;
  for(var ii in entryPointSize)
  {
    numEps += 1 ;
  }

  if(numEps > 0)
  {
    var maxSize = entryPointSize[chromosomeName];
    if(iFrom > maxSize || iTo > maxSize )
    {
      alert('"From" and "To" values must be less than the entrypoint length (' + maxSize + ').' ) ;
      if(iFrom > maxSize)
      {
        $('entryPointFrom').value = iFrom = maxSize - 5 ;
      }
      if(iTo > maxSize) // Maybe both were wrong, so we check to fix both independently.
      {
        $('entryPointTo').value = iTo = maxSize ;
      }
      navBar.from.focus() ;
      return false;
    }
  }

  updateCoordWidgets(iFrom, iTo) ;

  return true;
}

  // Will apply the coords to all from/start/to/stop form widgets scattered about the page.
function updateCoordWidgets(from, to, coordColor)
{
  // Want to use values in [here, hidden] "from" and "to" inputs.
  // BUG: this page has MULTIPLE tags with the id 'from' and MULTIPLE tags with the id 'to'.
  //      This is very very bad design and against HTML standards. We will attempt to keep them
  //      in sync by selecting them all by name and updating each.
  // FROM/START:
  var elems = $A(document.getElementsByName('from')) ;
  elems.each( function(elem)
  {
    elem.value = from ;
  } ) ;
  elems = $A(document.getElementsByName('start')) ;
  elems.each( function(elem)
  {
    elem.value = from ;
  } ) ;
  // TO/STOP:
  elems = $A(document.getElementsByName('to')) ;
  elems.each( function(elem)
  {
    elem.value = to ;
  } ) ;
  elems = $A(document.getElementsByName('stop')) ;
  elems.each( function(elem)
  {
    elem.value = to ;
  } ) ;
  // Change highlighting if asked
  if(coordColor)
  {
    var elem = $('entryPointFrom') ;
    if(elem)
    {
      elem.setStyle(
      {
        color : coordColor
      }) ;
    }
    elem = $('entryPointTo') ;
    if(elem)
    {
      elem.setStyle(
      {
        color : coordColor
      }) ;
    }
    elem = $('btnView') ;
    if(elem)
    {
      elem.setStyle(
      {
        color : coordColor
      }) ;
    }
  }
  return ;
}

function validateViewbox()
{
  var searchStr = $('searchstr').value
  if(searchStr)
  {
    searchStr = trimString(searchStr) ;
  }
  if(!searchStr || searchStr == "")
  {
    if( $('searchState').value=='1')
    {
      alert("Search string is empty.") ;
      $('searchState').value='0' ;
      return false ;
    }
  }

  var iPictWidth = getIntValue( viewBox.pictWidth, -1 ) ;
  if( iPictWidth < minPictureWidth || iPictWidth > maxPictureWidth )
  {
    alert( '"Picture width" must be an integer from ' + minPictureWidth + ' to ' + maxPictureWidth + '.' ) ;
    if( iPictWidth < minPictureWidth )
    {
      viewBox.pictWidth.value = minPictureWidth ;
    }
    else
    {
      viewBox.pictWidth.value = maxPictureWidth ;
    }
    viewBox.pictWidth.focus() ;
    return false ;
  }
  return true ;
}

function handleNav( nFrom, nTo )
{
  var iFrom = getIntValue( viewBox.from, 0 );
  var iTo = getIntValue( viewBox.to, 0 );
  if( nFrom != iFrom || nTo != iTo )
  {
    viewBox.from.value = nFrom;
    viewBox.to.value = nTo;
    viewBox.nav.value = "autonav";
    viewBox.submit();
  }
  else if( lastImgId != null )
  {
    document.images[lastImgId].src = "navbtn?id="+lastElemId;
  }
}

function handleLeft()
{
  var iFrom = getIntValue( viewBox.from, 0 );
  var iTo = getIntValue( viewBox.to, 0 );
  var iVal = getIntValue( viewBox.extVal, 0 );
  if( iVal <= 0 )
  {
    alert( '"Extend" value must be an integer number greater than 0.' );
    viewBox.extVal.value = "2,000";
    viewBox.extVal.focus();
  }
  else
  {
    iFrom = iFrom - iVal;
    if( iFrom < 1 )
    {
      iFrom = 1 ;
    }
    handleNav( iFrom, iTo );
  }
}

function handleRight()
{
  var iVal = getIntValue( viewBox.extVal, 0 );
  var iFrom = getIntValue( viewBox.from, 0 );
  var iTo = getIntValue( viewBox.to, 0 );
  if( iVal <= 0 )
  {
    alert( '"Extend" value must be an integer number greater than 0.' );
    viewBox.extVal.value = "2,000";
    viewBox.extVal.focus();
  }
  else
  {
      iTo = iTo + iVal;
      if( iTo < 1 || iTo > maxTo ) iTo = maxTo;
    handleNav( iFrom, iTo );
  }
}

function setAllbuttons( idx )
{
  if( idx <= 0 ) return;
  idx = idx - 1;

  var formObj = viewBox;
  for (var i=0; i<formObj.length; i++)
  {
    fldObj = formObj.elements[i];
    if(fldObj.type == 'select-one' && fldObj.options[0].text == 'Expand')
    {
      fldObj.selectedIndex = idx;
    }
  }
}

function expandTrack( trackName )
{
  var formObj = viewBox;
  for (var i=0; i<formObj.length; i++)
  {
    fldObj = formObj.elements[i];
    if( fldObj.type == 'select-one' &&
      fldObj.id == trackName &&
      fldObj.options[0].text == 'Expand' )
      fldObj.selectedIndex = 0;
  }
  viewBox.nav.value = "autonav";
  viewBox.submit();
}
function getdna()
{
  if(hasSequence)
  {
    var formObj = document.getdnaform;
    formObj.submit();
  }
}

function switchGroup(groupId, refSeqId)
{
  if(groupId)
  {
    var formObj = document.getdefaultBrowserForm;
    $('newGroupId').value = groupId;
    if(refSeqId)
      $('newRefSeqId').value = refSeqId;
    formObj.submit();
  }
}

function switchToPublicDefaultBrowser(refSeqId)
{
  if(refSeqId)
  {
    var formObj = document.getdefaultPublicBrowserForm;
    $('newRefSeqId').value = refSeqId;
    formObj.submit();
  }
}

function centerAnnotation( gclass, gname, track )
{
  viewBox.center_gclass.value = gclass;
  viewBox.center_gname.value = gname;
  viewBox.center_track.value = track;
  viewBox.nav.value = "ctrnav";
  viewBox.submit();
}


function commify( src )
{
  src = src.toString().strip() ;
  src = src.gsub(/,/, '') ;
  var match = src.match(/([^\.]+)(\..+)?/) ;
  var numerator = match[1] ;
  var denominator = match[2] || "" ;
  var len = numerator.length - 3 ;
  while(len > 0)
  {
    numerator = numerator.substring(0, len) + "," + numerator.substring(len) ;
    len -= 3;
  }
  return (numerator + denominator) ;
}

var trgWinHdl = null ; // JavaScript Handle to the target popup window
var trgWinName = "_newWin" ;  // Name of the target popup window
function winPopFocus() // This will do the actual popping up when the link is clicked
{
  trgWinName = winPopFocus.arguments[1] ;
  var trgWinUrl = winPopFocus.arguments[0] ;
  if(trgWinHdl == null || trgWinHdl.closed)
  {
    trgWinHdl = window.open(trgWinUrl, trgWinName, '') ;
  }
  else // winHandle not null AND not closed
  {
    trgWinHdl.location = trgWinUrl ;
  }

  if(!(trgWinHdl == null) && self.focus)
  {
    trgWinHdl.focus() ;
  }
  return false ;
}

function popTrack( tName, tUrl, tLabel, tDescr )
{
  var st = "<TABLE BORDER='0' WIDTH='100%' CELLSPACING='0' CELLPADDING='2'><TR><TD>" ;
  st += '<DIV style=font-size:8pt;>' ;
  if(tLabel.length > 0)
  {
    st += tLabel ;
    if(tDescr.length > 0)
    {
      st += '<hr>' ;
    }
  }
  if( tDescr.length > 0 )
  {
    st +=  tDescr;
  }
  st += '</DIV></TD></TR>' ;

  // Add draggable hint
 // First: what key will be be pressing?
 var dragKeyStr = 'ALT' ;// The default for Windows and unknown platforms
 if(navigator.platform)// Then the navigator object works ok
 {
    var osStr = navigator.platform.toLowerCase() ;
    if(osStr.indexOf('mac') != -1) // Then we have some sort of Mac
    {
      dragKeyStr = 'ALT or OPTION' ;
    }
    else if(osStr.indexOf('linux') != -1) // Then we have some sort of Linux
    {
      dragKeyStr = 'ALT-SHIFT' ;
    }
  }
  st += '<TR><TD ALIGN="right"><FONT SIZE="-3">[ Hold ' + dragKeyStr + ' to Drag ]</FONT></TD></TR></TABLE>';

  // Uses overlib, overlib_hide, overlib_cssstyle, and overlib_draggable.
  // The title bar style is set in a defined class--see jsp.css.
  return overlib( st, STICKY, DRAGGABLE, CLOSECLICK,
    FGCOLOR, '#EBEBEB', BGCOLOR, '#9F833F',
    CAPTIONFONTCLASS, 'capFontClass', CAPTION, '&nbsp;' + tName,
    CLOSEFONTCLASS, 'closeFontClass',
    CLOSETEXT, '&nbsp;&nbsp;<FONT COLOR="white">X</FONT>&nbsp;', WIDTH, '320' );
}


function processEvent(e)
{
  if(e  && e.keyCode == 13)
  {
    $('searchState').value='1';
  }
}

function trimString(sInString)
{
    sInString = sInString.replace( /^\s+/g, "" );// strip leading
    return sInString.replace( /\s+$/g, "" );// strip trailing
}


// ------------------------------------------------------------------
// Better util/helper functions for this page
// - some of the functions above are highly inefficient or overly complex for simple tasks (getting int from string with , in it is example)

// Get current value in From field, as actual integer.
function getEpFromAsInt()
{
  var fromValStr = $F('entryPointFrom') ;
  return parseInt(fromValStr.gsub(/,/, "")) ;
}

// Get current value in To field, as actual integer.
function getEpToAsInt()
{
  var toValStr = $F('entryPointTo') ;
  return parseInt(toValStr.gsub(/,/, "")) ;
}

// Calc bp width based on values in From and To fields.
function getEpWidth()
{
  var from = getEpFromAsInt() ;
  var to = getEpToAsInt() ;
  return Math.abs(from - to) + 1 ;
}

// Get original From value (since user/crop selection may have changed it), as actual integer.
// - 'origFrom' assumed to be defined on including page
function getOrigFromAsInt()
{
  return origFrom ;
}

// Get original To value (since user/crop selection may have changed it), as actual integer.
// - 'origTo' assumed to be defined on including page
function getOrigToAsInt()
{
  return origTo ;
}

// Calc bp width based on original From/To values.
function getOrigWidth()
{
  var from = getOrigFromAsInt() ;
  var to = getOrigToAsInt() ;

  return Math.abs(origFrom - origTo) ;
}

// Full chrom bp width. Provided by the "maxTo" variable on the including page
function getChromBpWidth()
{
  return maxTo ;
}

// Restore the From/To fields to their original values.
// - origFrom and origTo assumed to be defined on including page
function restoreOrigFromTo()
{
  // Restore the various wigets named 'from/to/start/stop' that exist within various forms on this page (ugh, what a mess).
  // Anyway, now they will act on the selected region
  updateCoordWidgets(origFrom, origTo, 'black') ;
  // Restore the displayed from/to text inputs
  $('entryPointFrom').value = commify(origFrom) ;
  $('entryPointTo').value = commify(origTo) ;
}

// Calculate the bp/px resolution of the image.
function getImgBpPerPx(type)
{
  var imgObj = (type == 'thumb' ? $('chromThumb') : $('bimg')) ;
  var fullImgWidth = imgObj.width ;
  var genomePxWidth = fullImgWidth ;
  if(type != 'thumb')
  {
    genomePxWidth -= (imgLeftMarginPxWidth + imgRightMarginPxWidth) ;
  }
  var bpWidth = (type == 'thumb' ? getChromBpWidth() : getOrigWidth()) ;
  return bpWidth / genomePxWidth ;
}

// Convert an x-axis coordinate on the image to a bp coord in the chromosome.
// Take into account the left margin size (provided by including page).
function imgXToBpCoord(xPos, type)
{
  var bpPerPx = getImgBpPerPx(type) ;
  var pxOffsetForGenome = xPos ;
  if(type != 'thumb')
  {
    pxOffsetForGenome -= imgLeftMarginPxWidth ;
  }
  var bpOffsetForGenome = pxOffsetForGenome * bpPerPx ;
  var from = (type == 'thumb' ? 1 : getOrigFromAsInt()) ;
  return Math.round(from + bpOffsetForGenome) ;
}

// Convert a bp coordinate to an x-axis pixel coordinate on the image.
function bpCoordToImgX(bpPos, type)
{
  if(type != 'thumb')
  {
    var origFrom = getOrigFromAsInt() ;
    var orgiTo = getOrigToAsInt() ;
    bpPos = ((bpPos - origFrom) < origFrom ? origFrom : ((bpPos - origFrom) > origTo ? origTo : (bpPos - origFrom))) ;
  }
  var pxPerBp = 1.0 / getImgBpPerPx(type) ;
  var xPos = Math.round(bpPos * pxPerBp) ;
  if(type != 'thumb')
  {
    xPos += imgLeftMarginPxWidth ;
  }
  return xPos ;
}
