
function validate()
{
  var trackBoxes = document.getElementsByName('trkId') ;
  var numChecked = 0 ;
  for(var ii=0; ii<trackBoxes.length; ii++)
  {
    if(trackBoxes[ii].checked)
    {
      numChecked += 1 ;
    }
  }
  // Is at least one track clicked?
  if(numChecked < 1 && !includeOtherSections.checked)
  {
    alert("You must select at least one track to download.") ;
    return false ;
  }
  else if(numChecked > 5) // Are too many tracks clicked, warn?
  {
    var lotsOK = confirm( "WARNING: you have " +
                          numChecked +
                          " tracks selected for download.\n\nThis could be a large amount of data and may take a while to complete.\n\nContinue anyway?") ;
    if(!lotsOK)
    {
      return false ;
    }
  }
  var from = $('from') ;
  var to = $('to') ;

  if(from && (entryPointId != null) && (!validatePositiveInteger(from.value) || parseInt(from.value) == 0)) // Do we need to fix the From?
  {
    alert("The 'From' coordinate must be an integer greater than 0.") ;
    from.focus() ;
    from.select() ;
    return false ;
  }
  else if(from && (entryPointId != null)) // Then a specific chromosome; check from vs the length
  {
    var chrLength = chromLengths[entryPointId] ;
    if(parseInt(from.value) > chrLength)
    {
      alert("The 'From' value is beyond the end of the chromosome.\n\nThe value has been trunctated for you.") ;
      from.value = chrLength ;
    }
  }
  if(to && (entryPointId != null) && (!validatePositiveInteger(to.value) || parseInt(to.value) == 0))  // Do we need to fix the To?
  {
    alert("The 'To' coordinate must be an integer greater than 0.") ;
    to.focus() ;
    to.select() ;
    return false ;
  }
  else if(to && (entryPointId != null)) // Then a specific chromosome; check the length
  {
    var chrLength = chromLengths[entryPointId] ;
    if(parseInt(to.value) > chrLength)
    {
      alert("The 'To' value is beyond the end of the chromosome.\n\nThe value has been trunctated for you.") ;
      to.value = chrLength ;
    }
  }
  if((from && to) && (entryPointId != null) && (parseInt(from.value) > parseInt(to.value))) // Is From > To? Fix it and warn
  {
    alert("The 'From' coordinate must be less than the 'To' coordinate.\n\nThis has been fixed for you.") ;
    var tmpVal = from.value ;
    from.value = to.value ;
    to.value = tmpVal ;
  }
  // Dialog about saving file/browsers.
  alert("NOTE: depending on the amount of data, the download may take some time to start. The download will be throttled.\n\nNOTE: Please 'SAVE' the LFF file rather than opening it, since your computer probably won't have an application for opening LFF files.\n\nDepending on your browser, you should make sure the file name makes sense (e.g. Internet Explorer 6 has a bug where the download file will have an inappropriate name, rather than our suggested name).");
  return true ;
}

function checkAll()
{
	var elems = document.getElementsByName('trkId') ;
	var i ;
	for( i=0 ; i<elems.length ; i++ )
	{
		elems[i].checked = true ;
	}
}

function clearAll()
{
	var elems = document.getElementsByName('trkId') ;
	var i ;
	for( i=0 ; i<elems.length ; i++ )
	{
		elems[i].checked = false ;
	}
}
