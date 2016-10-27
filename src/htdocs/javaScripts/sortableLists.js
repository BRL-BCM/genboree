// NOTE: this file used prototype.js

// ---------------------------------------------------------------------------
// PAGE INITIALIZATION
// ---------------------------------------------------------------------------
// Add a custom event handler for the 'load' event of object 'window'.
addEvent(window, "load", sortableLists_init);

function sortableLists_init() {
  var lists = $$('.sortable_list') ;
  // Do any regular sortable lists
  for(var ii=0; ii<lists.length; ii++)
  {
    // Make list sortable and submitable, if it's really in the doc
    Sortable.create(lists[ii].id) ;
  }

  // Do any selectable sortable lists
  lists = $$('.sortable_select_list') ;
  for(var ii=0; ii<lists.length; ii++)
  {
    // Make list sortable and submitable, if it's really in the doc
    Sortable.create(lists[ii].id) ;
  }

  // Register the recordOrder function for all onSubmit events of all forms
  var formsList = document.getElementsByTagName('form') ;
  for(var ii=0; ii<formsList.length; ii++)
  {
    addEvent(formsList[ii], "submit", recordOrder);
  }
  return ;
}

function recordOrder()
{
  // Do any regular sortable lists
  var lists = $$('.sortable_list') ;
  for(var ii=0; ii<lists.length; ii++)
  {
    var listItems = lists[ii].getElementsByTagName("li") ;
    for(var jj=0; jj<listItems.length; jj++)
    {
      var inputs = listItems[jj].getElementsByTagName("input");
      for(var kk=0; kk<inputs.length; kk++)
      {
        if(Element.hasClassName(inputs[kk], 'trkOrderInput'))
        {
          inputs[kk].value = jj + 1 ; // there can be only on <input> tracking the order
          break ;
        }
      }
    }
  }
  var hasError = false;
  // Do any selectable sortable lists
  lists = $$('.sortable_select_list') ;
  for(var ii=0; ii<lists.length; ii++)
  {
    if(lists[ii].hasClassName('isValid')) // Absolutely vital for the list to ONLY be marked valid if the WHOLE FORM is valid.
    {
      var listItems = lists[ii].getElementsByTagName("li") ;
      for(var jj=0; jj<listItems.length; jj++)
      {
        // var inputs = listItems[jj].getElementsByTagName("input") ;
        var trkingInput = listItems[jj].select('.trkOrderInput')[0] ;
        var itemName = listItems[jj].select('.trkItemName')[0] ;
        if(!trkingInput)
        {
          hasError = true;
          break;
        }

        if(!itemName)
        {
          hasError = true;
          break;
       }
       // Find pseudo checkbox and use it to set the tracking input field.
        var pseudoChkbox = listItems[jj].select('.trkOrderChkbx')[0] ;
        trkingInput.value = itemName.value + ', ' + pseudoChkbox.value + ', ' + jj
        // Remove the hidden inputs, they aren't needed anymore
        Element.remove(itemName) ;
        Element.remove(pseudoChkbox) ;
      }
      if(hasError)
      {
        break;
      }
    }
  }
  return ;
}

function doCheckToggle(divElemId, recordElemId)
{
  var divElem = $(divElemId) ;        // Div with image backgroup to adjust
  var recordElem = $(recordElemId) ;  // Input tag (usually hidden) where to record the "un/checked" fact

  if(recordElem.value == 'true')
  {
    recordElem.value = 'false' ;
    divElem.style.backgroundPosition = "0px 0px" ;
  }
  else if(recordElem.value == 'false')
  {
    recordElem.value = 'true' ;
    divElem.style.backgroundPosition = "-10px 0px" ;
  }

  return ;
}
