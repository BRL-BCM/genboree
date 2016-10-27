
// This file requires the following globals to be available on the web page:
// - projectsInGroup



String.prototype.trim = function() {
	return this.replace(/^\s+|\s+$/g,"");
}

String.prototype.isEmpty = function() {
  return (this.trim() == "")
}

function validateProjForm(form, event)
{
  var retVal = false ;
  var btn = document.getElementById('submitted') ;
  if(btn != undefined && btn != null)
  {
    var btnValue = btn.value.trim() ;
    if(btnValue == 'Create')
    {
      retVal = validateProjectName('projectName') ;
    }
    else if(btnValue == 'Rename')
    {
      retVal = validateProjectName('newProjectName') ;
    }
    else if(btnValue == 'Delete')
    {
      var projNameSelect = document.getElementById('projectName') ;
      var selProjIdx = projNameSelect.selectedIndex ;
      var selProjOption = projNameSelect.options[selProjIdx] ;
      var confirmed = confirm("Are you sure you want to delete the project '" + selProjOption.value + "' ?") ;
      retVal = confirmed ;
    }
    else if(btnValue == 'Move' || btnValue == 'Copy')
    {
      retVal = validateCopyOrMove(form) ;
    }
  }
  return retVal ;
}

function validateProjectName(projFieldId)
{
  var retVal = false ;
  var projNameInput = document.getElementById(projFieldId) ;
  var projNameValue = projNameInput.value.trim() ;
  projNameInput.value = projNameValue ;
  if(projNameValue.isEmpty())
  {
    alert('The Project Name cannot be empty') ;
    projNameInput.focus() ;
  }
  else
  {
    retVal = true ;
    for(var ii=0; ii<projectsInGroup.length; ii++)
    {
      if(projectsInGroup[ii] == projNameValue)
      {
        alert("The Project Name '" + projNameValue + "' already exists.") ;
        projNameInput.focus() ;
        retVal = false ;
        break ;
      }
    }
  }
  return retVal ;
}

/**
 * Build Object to be POSTed
 */
function makePayloadFromInput()
{
  var projects = [] ;
  for(var ii=0; ii<prjCheckboxes.length; ii++)
  {
    if(prjCheckboxes[ii].checked == true)
    {
      projects[ii] = { "id" : prjCheckboxes[ii].value,
                       "name" : prjNames[ii],
			                 "newName" : prjNewNameTexts[ii].value
								     } ;
				
    }
  }
  var payload = { "projects" : projects,
                  "targetGroupId" : $("targetGroupId").value,
                  "newGroupName"  : $("newGroupName").value
                } ;
  return payload ;
}

/**
 * This is executed onSubmit
 * Adds the payload object to the form 
 */ 
function validateCopyOrMove(formObj)
{
  if(!validateProjects()) { return false ; }
  if(!validateGroup()) { return false ; }
  payloadObj = makePayloadFromInput() ;
  /* Add the payload to the form as a hidden input element */
  $('payload').value = Ext.util.JSON.encode(payloadObj) ;
  return true ;
}

function validateGroup()
{
  var groupId = $('targetGroupId').value ;
  if(groupId == '')
  {
    return showFormError('targetGroupIdLabel', 'targetGroupId', "Please select a destination group.") ;
  }
  else if(groupId == 'new') 
  {
    if($('newGroupName').value.trim() == '')
    {
      return showFormError('targetGroupIdLabel', 'newGroupName', "If you would like to create a new group, please specify the name of the new group.") ;  
    }
    for (var ii=0; ii<targetGroups.length; ii++)
    {
      if ($('newGroupName').value.match(new RegExp("^"+targetGroups[ii]+"$", "i"))) {
        return showFormError('targetGroupIdLabel', 'newGroupName', "That group name is already in use, please specify a new name.") ;
      }
    }
  }
  return true ;
}

function validateProjects()
{
  prjsCheckedCount = 0 ;
	for (var ii=0; ii<prjCheckboxes.length; ii++)
	{
	  if(prjCheckboxes[ii].checked)
	  {
      if($('mode').value == 3) /* COPY */
      { /* Perform new name validation for copy, but not for move */
        if (prjNewNameTexts[ii].value.trim() == '')
        {
          return showFormError('', prjNewNameTexts[ii].name, 'The project name cannot be blank.') ;
        }
        else
        {
          var newNameRegExp = new RegExp("^"+prjNewNameTexts[ii].value+"$", 'i') ;
          for(var jj=0; jj<prjNames.length; jj++)
          {
            if(prjNames[jj].match(newNameRegExp))
            {
              return showFormError('', prjNewNameTexts[ii].name, "That project name is already in use, please specify a unique project name.") ;
            } 
          }
        }
      }
		  prjsCheckedCount++ ;
	  }
	}
  if(prjsCheckedCount == 0)
  {
    alert("Please select at least one project to copy to the destination group.") ;
    return false ;
  }
  return true ;
}

function toggleNewNameDiv(obj) {
  selectDisplayStyle = (obj.checked) ? 'inline' : 'none' ;
  $('div_'+obj.name).setStyle({display: selectDisplayStyle}) ;
}

function showFormError(labelId, elemId, msg)
{
  alert(msg) ;
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

/**
 *
 * Dependencies:
 *   - ExtJS 2.2
 *     Since the popup dialog is an ExtJS dialog, that must be included by
 *     whatever file includes this .js file.
 */
var helpMessages = {
  'targetGroup' : {
    'title' : 'Help: Destination Group',
    'text' : '<ul class="extHelpPopup">' +
             '  <li>Select a group for the projects.</li>' +
             '  <li>To create a new group, select "New Group" and enter the name of the group</li>' +
             '</ul>' 
  },
  'selectProjectsMove' : {
    'title' : 'Help: Select Projects',
    'text' : '<ul class="extHelpPopup">' +
             '  <li>Select the Projects that you would like to move to another group.</li>' +
             '</ul>'
  },
  'selectProjectsCopy' : {
    'title' : 'Help: Select Projects',
    'text' : '<ul class="extHelpPopup">' +
             '  <li>Select the Projects that you would like to copy to another group.</li>' +
             '  <li>When copying a project, you must specify a unique name for the project.</li>' +
             '</ul>'
  }  
} ;

/**
 * Display a popup dialog with the specified title and help string.  The title
 * will default to "Help" if it was not passed to the function.
 * @param button
 *   The button that was pressed to generate this dialog (for position).
 * @param text
 *   The help text to display in the main body of the dialog.
 * @param title
 *   (optional) The title of the help dialog.  Defaults to "Help".
 */
function displayHelpPopup(button, text, title)
{
  if (!title) title = "Help" ;

  Ext.Msg.show(
  {
    title: title,
    msg : text,
    height: 120,
    width: 385,
    minHeight: 100,
    minWidth: 150,
    modal: false,
    proxyDrag: true
  }) ;
  Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;

  return false ;
}


/**
 * Sets input elements to values that were submitted
 * Used by the Copy/Move Form
 */
function initFormFromPayload()
{
  if(payload != undefined)
  {
    payloadObj = payload ;
    $('newGroupName').value = payloadObj.newGroupName ;
    $('targetGroupId').value = payloadObj.targetGroupId ;
    if($('targetGroupId').value == 'new')
    {
      $('newGroupDiv').setStyle({display: 'inline'}) ;
    }
    for(var ii=0; ii<payloadObj.projects.length; ii++)
    {
      $('prjIds['+payloadObj.projects[ii].id+']').checked = true ;
      if($('mode').value == 3) /* Copy */
      {
        $('prjNewName['+payloadObj.projects[ii].id+']').value = payloadObj.projects[ii].newName ;
        $('div_prjIds['+payloadObj.projects[ii].id+']').setStyle({display: 'block'}) ;
        if (payloadObj.projects[ii].status != 'OK')
        {
          showFormError('', 'prjNewName['+payloadObj.projects[ii].id+']', payloadObj.projects[ii].newName + ' :' +payloadObj.projects[ii].status) ;
        }
        
      }
    }
  }
}



