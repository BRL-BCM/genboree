

// Hides/shows all the divs with the given class
function setDivDisplayByClass(classToToggle, state)
{
		var divs = document.getElementsByTagName("div") ;
		
		for(var ii = 0; ii < divs.length; ii++)
		{
		  var divId = divs[ii].getAttribute("id") ;
		  if(divId && divId.indexOf(classToToggle) == 0)
		  {
		    divs[ii].style.display = state ? "block" : "none" ;
		  }
		}
		return ;
}

// Hides/shows all the Genboree images and special cases in "egDiv" class divs
// when the checkbox is clicked
function toggleDivDisplay(checkbox)
{
  var isChecked = checkbox.checked ;
  setDivDisplayByClass("egDiv", isChecked) ;
  return ;
}
