function submitRefresh(isPublic)
{

    var tgtForm = $('refresh');
    var srcForm = $('viewbar');
    var idx = -1;
    if (srcForm && srcForm.refSeqId)
          idx = srcForm.refSeqId.selectedIndex;
    if(  idx >= 0 )
    {
        tgtForm.refSeqId.value = srcForm.refSeqId.options[idx].value;
    }

    if (srcForm)
        idx = srcForm.entryPointId.selectedIndex;

    if( idx >= 0 )
    {
        tgtForm.entryPointId.value = srcForm.entryPointId.options[idx].value;
    }
   
     if( !isPublic ) {
            idx = srcForm.groupId.selectedIndex;

            if( idx > -1  )
            {
                tgtForm.groupId.value = srcForm.groupId.options[idx].value;
            }
      }


    if (srcForm && srcForm.entryPointId.selectedIndex) {
       if (tgtForm) {
        tgtForm.startPos.value = srcForm.from.value;
        tgtForm.endPos.value = srcForm.to.value;
        }
    }

    if (tgtForm)
        tgtForm.submit();

}


function changeDB(isPublic)
{

    var tgtForm = $('refresh');
    var srcForm = $('viewbar');
    var idx = -1;
    if (srcForm && srcForm.refSeqId)
          idx = srcForm.refSeqId.selectedIndex;
    if(  idx >= 0 )
    {
        tgtForm.refSeqId.value = srcForm.refSeqId.options[idx].value;
    }

    if (srcForm)
        idx = srcForm.entryPointId.selectedIndex;

    if( idx >= 0 )
    {
        tgtForm.entryPointId.value = '';
    }
 
     if( !isPublic ) {
            idx = srcForm.groupId.selectedIndex;

            if( idx > -1  )
            {
                tgtForm.groupId.value = srcForm.groupId.options[idx].value;
            }
      }


    if (srcForm && srcForm.entryPointId.selectedIndex) {
       if (tgtForm) {
        tgtForm.startPos.value = srcForm.from.value;
        tgtForm.endPos.value = srcForm.to.value;
        }
    }

    if (tgtForm)
        tgtForm.submit();

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

function validateViewbar() {

    var searchStr = $('searchstr').value
        if (searchStr)
          searchStr = trimString(searchStr);

         if (!searchStr || searchStr == "") {
            if ( $('rtnSearch').value=='1'){
                alert("Search string is empty.");
                $('rtnSearch').value='0';
                return false;
            }
          }


    var fromInput = $('from') ;
    var toInput = $('to') ;
  
	var chromosomeName = viewbar.entryPointId.value;
  // ARJ 8/23/2005 3:00PM:
  //  We check as much as we can. But the last case--if the FROM or TO are too
  //  big--can only be checked if we have all the entrypoint information on the
  //  page. For large number of entrypoints, we may not.
  var iFrom = remCommas( $('from').value, -1);
  var iTo = remCommas( $('to').value, -1);
 	var minStart = 1;
 	// CASE 1: are either FROM or TO less than 1 ?
 	if(iFrom < minStart || iTo < minStart)
 	{
 	  alert('"From" and "To" values must be greater or equal to 1. Fixed.') ;
 	  if(iFrom < minStart)
 	  {
 	    $('from').value = minStart ;
 	  }
 	  if(iTo < minStart) // Maybe both were wrong, so we check to fix both independently.
 	  {
 	    $('to').value = minStart ;
 	  }
 	   fromInput.focus() ;
 	  return false ;
 	}
 	
 	
 	// CASE 2: is FROM larger than TO ?
 	if( iFrom > iTo )
	{
		alert( '"From" value must be less than "To" value.' ) ;
		$('from').value = iTo ;
		$('to').value = iFrom ;
		//navBar.from.focus();
		return false;
	}
	
	// CASE 3: are either FROM or TO larger than the chromosome length?
	  //  We only attempt to validate the selected entrypoint and from/to if
    //  we have provided an EP droplist (i.e. there are only a few EPs). If the
    //  user is entering things manually (there are lots of EPs) then we don't
    //  check the coords vs the entrypoint length--we don't even have all the
    //  entrypoint lengths available for Javascript.
       var  numEps =0; 
        for (var ii in entryPointSize)
          numEps += 1 ;

	if(numEps > 0){
        var maxSize = entryPointSize[chromosomeName];
       
        if(iFrom > maxSize || iTo > maxSize )
        {
        alert('"From" and "To" values must be less than the entrypoint length (' + maxSize + ').' );
        if(iFrom > maxSize)
        {
        $('from').value = maxSize-5 ;
        }
        if(iTo > maxSize) // Maybe both were wrong, so we check to fix both independently.
        {
        $('to').value = maxSize ;
        }
        fromInput.focus();
        return false;
        }
	}

	return true;
   
    
}


function setEPLimits(chrSize )
{
  var arr =  transformLimits(chrSize);
    var myFrom = arr[0];
    var myTo = arr[1];
    $('from').value = putCommas(myFrom);
    $('to').value = putCommas(myTo);
}

function updateEntryPointSelected(){
 
   var defForm = $('refresh');
   var browserForm = $('viewbar');
   var chrName = browserForm.entryPointId.value ; 
    var chrSize = entryPointSize[chrName];
    setEPLimits(chrSize);
}

function processEvent (e) {
    if (e.keyCode ==13){
          $('rtnSearch').value='1';
    }
}

function trimString(sInString) {
    sInString = sInString.replace( /^\s+/g, "" );// strip leading
    return sInString.replace( /\s+$/g, "" );// strip trailing
}

