
/* ------------------------------------------------------------------------- */
/* Generic Helper Methods                                                    */
/* ------------------------------------------------------------------------- */
// Gets the currently selected text on the current page, in case you want it.
function getSel()
{
	var txt = '' ;            // The selected text.
	var foundVia = '' ;       // The method that succeeded in returning selected text.
	
	// Try to get selection from a few objects.
	if(window.getSelection)
	{
		txt = window.getSelection() ;
		foundVia = 'window.getSelection()' ;
	}
	else if(document.getSelection)
	{
		txt = document.getSelection() ;
		foundVia = 'document.getSelection()' ;
	}
	else if(document.selection)
	{
		txt = document.selection.createRange().text ;
		foundVia = 'document.selection.createRange()' ;
	}
	else
	{
	  txt = null ;
	  foundVia = 'No selected text found' ;
	}
	return txt ;
}


// This function returns the index of the cursor location in
// the value of the input text element.
// (NOTE: Make sure that the markerString variable contains
// a series of characters that will not be encountered normally in your
// text...this is part of the trick.)
function getCursorPos(textElement)
{
  // Save the current text's value to restore it later:
  var sOldText = textElement.value ;
  alert('sOldText: ' + sOldText) ;
  
  // Create a range object and save its text
  var objRange = getSel() ;
  alert('objRange : ' + objRange + ' ( ' + (objRange ? true : false) + ' ) ') ;
  var sOldRange = (objRange ? objRange.text : '' );
  alert('sOldRange : ' + sOldRange) ;
  
  // Set this string to a small string that will not normally be encountered
  var markerString = '~#%~';

  // Insert the markerString where the cursor is at:
  objRange.text = sOldRange + markerString ; // <-- the 'cursor' is now at the end of the objRange.text
  
  objRange.moveStart('character', (0 - sOldRange.length - markerString.length)) ; // <-- the 'cursor' is moved to where the cursor was in the original (i.e. backwards from the end)

  // Save the new string with the markerString in it:
  var sNewText = textElement.value ;

  // Set the actual text value back to how it was:
  objRange.text = sOldRange ;

  // Look through the new string we saved and find the location of
  // the markerString that was inserted and return that value:
  for(ii=0; ii <= sNewText.length; ii++)
  {
    var sTemp = sNewText.substring(ii, ii + markerString.length);
    if(sTemp == markerString)
    {
      var cursorPos = (ii - sOldRange.length);
      return cursorPos;
    }
  }
  return null ;
}

// This function inserts the input string into the textarea
// where the cursor was at.
function insertString(textElement, cursorPos, stringToInsert)
{
  var firstPart = textElement.value.substring(0, cursorPos) ;
  var secondPart = textElement.value.substring(cursorPos, cursorPos.value.length) ;
  cursorPos.value = firstPart + stringToInsert + secondPart ;
  return ;
}