
// THIS FILE USES prototype.js FEATURES

function handleSubmit(event)
{
  var doSubmit = true ;
  var evtObj = Event.element(event) ;
  var formObj = $('usrfsq') ; 
  var groupSelObj = $('groupId') ;
  var dbSelObj = $('refSeqId') ;
  var toolSelObj = $('tool') ;
  var expname = $('expname') || document.createElement("select") ;
  
  // Deal with special case of the "Select XXX" entry being selected
  if(groupSelObj.selectedIndex == 0 || evtObj == groupSelObj) // "Select Group" is set or group changed
  {
    dbSelObj.selectedIndex = 0 ;
    toolSelObj.selectedIndex = 0 ;
    expname.selectedIndex = 0 ;
    if(evtObj != groupSelObj) 
    {
      alert("You must select a group first.") ;
      doSubmit = false ;
    }
  }
  else if(dbSelObj.selectedIndex == 0 || evtObj == dbSelObj)  // "Select Database" is set or db changed
  {
    toolSelObj.selectedIndex = 0 ;
    expname.selectedIndex = 0 ;
    if((evtObj != dbSelObj) && (evtObj != groupSelObj))
    {
      alert("You must select a database first.") ;
      doSubmit = false ;
    }
  }
  else if(toolSelObj.selectedIndex == 0) // "Select Tool" is set or changed
  {
    expname.selectedIndex = 0 ;
    if((evtObj != toolSelObj) && (evtObj != dbSelObj) && (evtObj != groupSelObj))
    {
      alert("You must select a tool.") ;
      doSubmit = false ;
    }
  }
  else
  {
    doSubmit = true ;
  }
  
  // Ready to submit or not?
  if(doSubmit)
  {
    formObj.submit() ;
  }
  else
  {
    return false ;
  }
}
