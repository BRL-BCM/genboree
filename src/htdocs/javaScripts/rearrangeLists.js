// -----------------------------------------------------------------------------
// REARRANGEABLE LISTS -- DRAG-AND-DROP LIST REARRANGEMENT AS A WEB UI
// -----------------------------------------------------------------------------
// Author: Andrew R Jackson
// 3/18/2005 10:48AM
//
// The methods and [currently] global variables in this file are for the support
// of rearrangeable lists--HTML lists the user can drag-and-drop around.
// This is used as a list-order UI.
//
// Usage:
// To create a reorderable list, follow these steps:
//    1) Include the .js files "dom-drag.js" and "rearrangeLists.js" in your
//       <HEAD> section.
//    2) Create your list. Can be <OL> or <UL>. Make sure to have these features:
//        2.1) Give the list an ID attribute value...we'll call this the listID.
//        2.2) Make sure you write correct HTML...<LI></LI> not just <LI>.
//        2.3) Within each <LI> element, embed an <INPUT> tag. The type can
//             be hidden or text (or anything with a .value property actually).
//             The value of these will be its location in the list. You can
//             use this in a <FORM> to retrieve the user's selections upon
//             submission.
//        2.4) You can put other things in the <LI> too, like images and ctext,
//             etc. It's nice to have some image handle as well as text, for eg.
//    3) In the ONLOAD event for your <BODY> tag, make sure to call
//       "initRearrangeList(<listID>);" in addition to whatever else you call.
//
// -----------------------------------------------------------------------------

// GLOBALS
var rListItemOffsets; // For tracking offsets of list elements from the top
var rList;            // The rearrangable list (ordered or unordered...recommend ordered)

// Call this function ONLOAD to initialize the rearrangable list state.
// Provide the ID attribute value for the list you want to be rearrangable.
function initRearrangeList(listID)
{
  rListItemOffsets = new Array();
  rList = document.getElementById(listID);        // Get the list object.
  rListItems = rList.getElementsByTagName("li");  // Get all the list items.
  for(var ii = 0; ii < rListItems.length; ii++)   // Loop over each list item
  {
    Drag.init(rListItems[ii], null, 0, 0, null, null); // Init dragging on this list item (any DOM object).
    // Register a customized event handler function for onDrag for this list item:
    rListItems[ii].onDrag = 
        function(xx, yy, myItem)  // List-item-specific function called when dragged
        {
          yy = myItem.offsetTop ; // We're only really interested in the y value.
          recalcOffsets() ;       // Make sure starting offsets are set.
          var pos = whereAmI(myItem) ;  // Find the index of the dragged list item in the list.
          var rListItems = rList.getElementsByTagName("li") ; // Get all the list items (we're within the *handler*, remember)
          // Dragging Down?
          if(pos != rListItems.length-1 && yy > rListItemOffsets[pos + 1])
          { 
            rList.removeChild(myItem) ;     // Remove the list item from the list.
            if(pos >= rListItems.length-1)  // Ensure we aren't dragging the last item...which means pos is now off the end of the shorter list.
            {
              rList.appendChild(myItem) ;   // Append item back on, you can't drag the last item down further.
            }
            else
            {
              rList.insertBefore(myItem, rListItems[pos+1]) ;  // Re-insert the dragged item before the next one (we're dragging down remember)
            }
            myItem.style["top"] = "0px" ;
          }
          // Dragging Up?
          else if(pos != 0 && yy < rListItemOffsets[pos - 1])
          { 
            rList.removeChild(myItem) ;     // Remove the list item from the list.
            rList.insertBefore(myItem, rListItems[pos-1]) ; // Insert it before the previous one (we're dragging up remember)
            myItem.style["top"] = "0px" ;
          }
        }; // end of anonymous onDrag handler
    // Register a customized even handler function for onDragEnd for this list item:
    rListItems[ii].onDragEnd =
        function(xx, yy, myItem)
        {
          myItem.style["top"] = "0px" ;
          updateInputsForList(rListItems);  // Each List item here has a hidden input tag whose value needs with the new location to be updated for the form submission.
        };
    // Set initial state of the rearrangeList
    recalcOffsets() ;
    updateInputsForList(rListItems);
  }
}

// Update the input elements embedded in each list item.
function updateInputsForList(listItems)
{
  for(var ii=0; ii<listItems.length; ii++)
  {
    var inputElements = listItems[ii].getElementsByTagName("input") ;
    inputElements[0].value = ii+1 ;    
  }
}

// Update the offsets state
function recalcOffsets()
{
  var listItems = rList.getElementsByTagName("li") ;
  for(var ii=0; ii<listItems.length; ii++)
  {
    rListItemOffsets[ii] = listItems[ii].offsetTop ;
  }
}

// Where is this listItem in the rList?
function whereAmI(listItem)
{ 
  var listItems = rList.getElementsByTagName("li") ;
  for(var i = 0; i < listItems.length; i++)
  {
    if(listItems[i] == listItem) { return i }
  }
}
