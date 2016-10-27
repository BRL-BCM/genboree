
// NOTE: this file used prototype.js

// ---------------------------------------------------------------------------
// PAGE INITIALIZATION
// ---------------------------------------------------------------------------
// Add a custom event handler for the 'load' event of object 'window'.
addEvent(window, "load", sortableList_init);

// Put the ids of any lists you want made sortable upon page load here:
var SORTABLE_LISTS = [ "rearrange_list1" ] ;

function sortableList_init() {
  for(var ii=0; ii<SORTABLE_LISTS.length; ii++)
  {
    // Make the list sortable and submitable, if it really exists on the page
    if(document.getElementById(SORTABLE_LISTS[ii]))
    {
      Sortable.create(SORTABLE_LISTS[ii]);
    }
  }
}

function handleSubmit(form)
{
  // MODE values to handle:
  // "Rename", "Delete", "Order", "Styles", "URL", "Classify"
  var theMode = document.getElementById("mode").value;
  var retVal = true ;
  if(theMode == "Rename")
  {
    retVal = validateRename(form) ;
  }
  else if(theMode == "Delete")
  {
  }
  else if(theMode == "Order")
  {
    recordOrder() ;
  }
  else if(theMode == "Styles")
  {
  }
  else if(theMode == "URL")
  {
    retVal = validateURLFields() ;
  }
  else if(theMode == "Classify")
  {
  }
  else // What??
  {
    retVal = false ;
  }
  return retVal ;
}

function confirmDelete()
{

   if (countDelTracks() ==0){
     alert("You selected 0 tracks for deletion. ");
      return false;
   }

  var answer = confirm("Are you sure you want to delete " + countDelTracks() + " tracks??") ;
  if (answer) {
    var deleteTrack = document.getElementById('deleteTrack');
        deleteTrack.value = "1";
    var f = document.getElementById('trkmgr');
     f.submit();
  }

}

function countDelTracks()
{
  var numChecked = 0 ;
  var list = document.getElementsByTagName("input");
  for (var ii=0; ii<list.length; ii++)
  {
        if(list[ii].getAttribute("id") && (list[ii].getAttribute("id").indexOf("delTrkId") == 0) && list[ii].checked)
        {
            numChecked += 1;
        }
  }
  return numChecked ;
}

function checkAll(state) {
  var list = document.getElementsByTagName("input");
  for (var ii=0; ii<list.length; ii++)
  {
        if(list[ii].getAttribute("id").indexOf("delTrkId") == 0)
        {
            list[ii].checked = state;
        }
  }
}

function unSelectAll() {}


// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// PAGE-SPECIFIC JAVASCRIPT
// ---------------------------------------------------------------------------
function recordOrder()
{
  for(var ii=0; ii<SORTABLE_LISTS.length; ii++)
  {
    var rList ;
    var buff = '';
    if(rList = document.getElementById(SORTABLE_LISTS[ii]))
    {
      var listItems = rList.getElementsByTagName("li") ;
      for(var ii = 0; ii < listItems.length; ii++)
      {
        var inputs = listItems[ii].getElementsByTagName("input") ;
        inputs[0].value = ii + 1;
      }
    }
  }
  return true ;
}

function validateURLFields()
{
  var trkmgrElem = document.getElementById('trkmgr');
  var evtVal = true ;
  if(trkmgrElem)
  {
    var urlLink ;
    var urlLabel ;
    var urlDesc;
    if(trkmgrElem.url_label)
    {
      urlLabel = trkmgrElem.url_label.value ;
    }
    if(trkmgrElem.track_url)
    {
      urlLink = trkmgrElem.track_url.value ;
    }

    if(urlLabel=='' && urlLink=='') // then user didn't enter optional URL stuff
    {
      evtVal = true ;
    }
    else // the user did enter optional URL stuff, so we need to check it
    {
      if(urlLink=='') // then urlLabel is filled in but not the link
      {
        alert("OOPS! You entered a URL label, but no URL (web address)!") ;
        document.getElementById("url_headerText").style.color = "red" ;
        evtVal = false ;
      }
      else if(urlLabel=='') // then urlLink is filled in, but no label for it
      {
        document.getElementById("urlLabel_headerText").style.color = "red" ;
        var trackName = trkmgrElem.ftypeid.options[trkmgrElem.ftypeid.selectedIndex].text ;
        trkmgrElem.url_label.value = trackName ;
        evtVal = false ;
      }
      else if(!urlLink.match(/^\s*(http|ftp|file):\/\//))
      {
        evtVal = confirm("WARNING: the value you entered for the URL doesn't look normal.\ni.e. it doesn't start with http:// or similar.\n\nProceed anyway?") ;
      }
      else // everything is ok, I guess
      {
        evtVal = true ;
      }
    }
  }
  return evtVal ;
}

function makeReadOnly()
{
  var xx = document.forms.trkmg ;
  xx[0].readOnly = true
}

function changePic( elem, picId )
{
	var idx = elem.selectedIndex ;
	document.images[picId].src = styleSampleList[elem.getValue(elem.selectedIndex)].src ;
}

function resetGclassId (h) {

document.setElementById('trackchange') = "1231221";
//document.trkmgr.gclassId.value = null;
h.value = "xnjxnjjidnjisdjidji";
// document.submit();

}

function validateRename( form )
{
	var ii ;
	var trkInputs = Form.getInputs(form, "text") ;
	var numTracks = trkInputs.length / 2 ;
	var trkLookup = new Object();
	var retVal = true ;
  var hasBlankTypes = false ;
  var hasBlankSubtypes = false ;
  var hasDuplicates = false ;
  var hasTooLongNames = false ;
  var errors = new Array() ;
  var duplicateTracks = $H(new Array()) ;
  var toolLongTracks = $H(new Array()) ;

	// FirstGet all track names
	var trackNames = new Array() ;
	for(ii=0; ii < numTracks; ii++)
	{


		var typeObj = trkInputs[ 2*ii ];
		var subtypeObj = trkInputs[ 2*ii+1 ];
		var trkName = typeObj.value + ":" + subtypeObj.value ;
		if(trackNames[trkName]) // count number times each track occurs
		  trackNames[trkName] += 1 ;
		else
		  trackNames[trkName] = 1 ;



	}
	var trackNamesHash = $H(trackNames) ;
      var redColor = "#ff6574";
   var redColor2=  "#ef5272"
  // Validate each track.
  // Collect errors and warnings for later display.
	for( ii=0; ii < numTracks; ii++ )
	{
		var typeObj = trkInputs[ 2*ii ] ;
		var subtypeObj = trkInputs[ 2*ii+1 ] ;
		var trkName = typeObj.value + ":" + subtypeObj.value ;

        var hasBlankTypes1 = false ;
        var hasBlankSubtypes1 = false ;
        var hasDuplicates1 = false ;
        var hasTooLongNames1 = false ;
    // Is track type empty string or all whitespace? Error.
		if( typeObj.value.match(/^\s*$/) )
		{
		  typeObj.style.backgroundColor = redColor;
		  typeObj.focus() ;
		  if(!hasBlankTypes)
		    errors.push(" - Some tracks have empty or blank Types.") ;
		  hasBlankTypes = true ;
		  hasBlankTypes1 = true ;
		}


		// Is track type empty string or all whitespace? Error.
		if( subtypeObj.value.match(/^\s*$/) )
		{
            subtypeObj.style.backgroundColor = redColor;
            subtypeObj.focus() ;
            if(!hasBlankSubtypes)
            errors.push(" - Some tracks have empty or blank Subtypes.") ;
            hasBlankSubtypes = true ;
             hasBlankSubtypes1 = true ;
		}


		// Are there duplicates for this track? Confirm OK.
		var trkCount = trackNamesHash[trkName] ;

		if( (typeof(trkCount) != 'undefined') && (trkCount > 1)) // Look for duplicate track names
		{
		  typeObj.style.backgroundColor = redColor;
			subtypeObj.style.backgroundColor = redColor ;
			typeObj.focus();
			if(!hasDuplicates)
			  errors.push(" - Some of the tracks have duplicate names.") ;
			hasDuplicates = true ;
			hasDuplicates1 = true ;
			duplicateTracks[trkName] = true ;
		}


		// Are there tracks with long names? Confirm OK.
		if(trkName.length > 19)
		{
		  typeObj.style.backgroundColor = "pink" ;
			subtypeObj.style.backgroundColor = "pink" ;
			typeObj.focus() ;
			hasTooLongNames = true ;
			hasDuplicates1 = true ;
			toolLongTracks[trkName] = true ;
		}


		if(!hasBlankTypes1 && !hasBlankSubtypes1 && !hasDuplicates1 && !hasTooLongNames1)
		{
		  typeObj.style.backgroundColor = "white" ;
          subtypeObj.style.backgroundColor = "white" ;
		}

	}



    var warnStr1 = '' ;
   if(hasTooLongNames )
  {    var warnStr = '' ;
    if(hasTooLongNames)
    {
      warnStr += "WARNING: some of the tracks have long names (over 18 letters, highlighted in PINK):\n - " ;

      warnStr += toolLongTracks.keys().join("\n - ") ;
        warnStr1 = warnStr;
      warnStr += "\n\nThey will be truncated in the browser view." ;
    }
    warnStr += "\nProceed anyway?\n" ;
     if(!hasBlankTypes && !hasBlankSubtypes && !hasDuplicates)
    retVal = confirm(warnStr) ;
  }


  // Done looking at all possible issues.
	// Now decide what to do.
	if(hasBlankTypes || hasBlankSubtypes || hasDuplicates)
	{
	  var errorStr = errors.join("\n") ;
	  alert("ERROR: there are problems with your new track names highlighted in RED:\n" + errorStr + "\n\n\n" + warnStr1) ;
	  retVal = false ;
	}

	return retVal ;
}


function confirmReset(message) {
     if (confirm (message) ){
        $("btnReset2Default").value="btnReset2Default";
        $('trkmgr').submit();
    }
    else {
       $("btnReset2Default").value="";
    }
}
