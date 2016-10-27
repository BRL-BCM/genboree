function displaySuccessDialog(result, request)
{
  // NOTE NOTE:
  // REMOVE eval() approach if find better way to have ExtJs consider the <script> tag in the response
  // used for MessageBox.
  // The regexp below is NOT safe for MULTIPLE <script> blocks in response. USE ONLY ONE SCRIPT TAG AT MOST.
  var scripts ;
  var scriptsFinder=/<script[^>]*>([\s\S]+)<\/script>/gi ;
  var title ;
  var width ;
  var dialogHeader = wbGlobalSettings.get('successDialogHeader') ;
  if(dialogHeader != null && dialogHeader != undefined)
  {
    title = dialogHeader ;
  }
  else
  {
    title = "Job Submission Status" ;
  }
  var dialogWidth = wbGlobalSettings.get('successDialogWidth') ;
  if(dialogWidth != null && dialogWidth != undefined)
  {
    width = dialogWidth ;
  }
  else
  {
    width = 600 ; // default width for an Ext Message Box
  }

  /* show success message */
  var messBox = Ext.MessageBox.show(
  {
    title: title,
    id: 'wbJobStatusMessageBox',
    msg: result.responseText,
    buttons: Ext.MessageBox.OK,
    cls: "wbDialogAlert",
    ctCls: "wbDialogAlert",
    width: width,
    fn: performOperOnOK,
    maxWidth: 9000
  }) ;
  while( (scripts = scriptsFinder.exec(result.responseText)) )
  {
    if(!Ext.isOpera) // Opera does an automatic eval in the success dialog page. Hence this check has to be done since it will break (Opera) any tool that has javascript in the 'success dialog'
    {
      eval(scripts[1]) ;
    }
  }
  var divEls = $$("#jobSummaryGridPanel .x-grid3-cell-inner") ;
  var messWindow = messBox.getDialog() ;
  messWindow.center() ;
  wbDialogWindow.close() ;
  // This time out is required for removing the 'unselectable' attribute from the grid.
  setTimeout(function(){
    var divEls = $$("#jobSummaryGridPanel .x-grid3-cell-inner") ;
    for(ii=0; ii < divEls.length; ii++)
    {
      if(divEls[ii].attributes)
      {
        divEls[ii].removeAttribute("unselectable") ;
      }
    }
  },
  300) ;

}

/*
 Function registered with the message box on the 'success dialog' window.
 For most cases, will just cleanup the global vaiables like 'wbHash'.
 For special cases like the 'gridViewer' will make the 'OK' button open up a link to the grid
*/
function performOperOnOK(btnValue)
{
  if(btnValue == 'ok')
  {
    // instead of every tool adding their own event on OK here like this one has,
    // instead override the following function's definition in the tool-specific success dialog
    wbAcceptOkCallback() ;

    if(wbGlobalSettings.get('redirectOnOK') != null && wbGlobalSettings.get('redirectOnOK') != undefined) /* Used for grid viewer for making the 'OK" button open up the grid viewer instead of just closing the window */
    {
      var ii ;
      var dbListStr = wbGlobalSettings.get('escInputs') ;
      var wbHashSettings = wbHash.get('settings') ;
      var gbGridXAttr = wbHashSettings.get('gbGridXAttr') ;
      var gbGridYAttr = wbHashSettings.get('gbGridYAttr') ;
      var xlabel = wbHashSettings.get('xLabel') ;
      var ylabel = wbHashSettings.get('yLabel') ;
      var gridTitle = wbHashSettings.get('gridTitle') ;
      var pageTitle = wbHashSettings.get('pageTitle') ;
      var xtype = wbHashSettings.get('xtype') ;
      var ytype = wbHashSettings.get('ytype') ;
      var gridUrl = "/java-bin/multiGridViewer.jsp?dbList=" + dbListStr + "&gbGridXAttr=" + gbGridXAttr + "&gbGridYAttr=" + gbGridYAttr + "&xlabel=" + xlabel + "&ylabel=" + ylabel + "&gridTitle=" + gridTitle + "&pageTitle=" + pageTitle + "&xtype=" + xtype + "&ytype=" + ytype
      //alert(gridUrl) ;
      window.open(gridUrl, '_blank') ;
    }
    wbGlobalSettings.each(function(pair) {
      wbGlobalSettings.unset(pair.key) ;
    }) ;
    wbHash.set('context', new Hash(clientContext)) ;
    wbHash.set('settings', new Hash()) ;
  }
  else
  {
    /* the btnValue may also indicate that the box was closed perhaps via the "X" in the
       top right corner of the dialog */
    wbAcceptCloseCallback() ;
    /* cleanup */
    wbGlobalSettings.each(function(pair) {
      wbGlobalSettings.unset(pair.key) ;
    }) ;
    wbHash.set('context', new Hash(clientContext)) ;
    wbHash.set('settings', new Hash()) ;
  }

}

/**
 * This should handle a variety of response formats and display as prettily as possible
 * The response could be an API json response
 * or html text
 */
function displayFailureDialog(result, windowTitle)
{
  var message ;
  var scripts ;
  var scriptsFinder=/<script[^>]*>([\s\S]+)<\/script>/gi ; // Sameer: This regexp picks up everything from <script> to the last </script> (which may include html content).
  while( (scripts = scriptsFinder.exec(result.responseText)) )
  {

    scriptToEval = scripts[1].split("</script>")[0] ; // See jobWarnings for 'Add New User To Group'
    //alert(scriptToEval) ;
    if(!Ext.isOpera)
    {
      eval(scriptToEval) ;
    }
  }
  if(windowTitle == undefined || typeof(windowTitle) != 'string')
  {
    windowTitle = 'Problem Submitting Job';
  }
  try
  {
    /* Try parsing an API JSON response, and display it */
    var jsonData = Ext.util.JSON.decode(result.responseText) ;
    var reLogin = false ;
    if(jsonData.status.statusCode == undefined)
    {
      throw "Not an API JSON response" ;
    }
    var statusMsg = null ;
    var message = null ;
    var cssHeight = 'height:auto;' ;
    if(result.status == 412 && jsonData.status.msg.match(/^SESSION EXPIRED/))
    {
      reLogin = true ;
      statusMsg = "Your login session appears to have expired. You will now be directed to sign in." ;
      message = '<div class="wbDialog" style="height:auto; width:auto;"><div class="wbDialogFeedback wbDialogFail">' +
      '  <div class="wbDialogFeedbackTitle">Login session expired.</div>' +
      '  <b>Message:</b><br><div style="margin-bottom:10px; ' + cssHeight + '">' + statusMsg + "</div>" ;
    }
    else // Some error other than session timeout
    {

      statusMsg = (jsonData.status.msg) ? jsonData.status.msg.gsub(/\n/, "<br>") : 'No error message provided' ;
      cssHeight = (statusMsg.length > 300 ? 'height:125px; overflow-y: auto;' : 'height:auto;') ;
      message = '<div class="wbDialog" style="height:auto; width:auto;"><div class="wbDialogFeedback wbDialogFail">' +
      '  <div class="wbDialogFeedbackTitle">There has been an error here.  See below for more information.</div>' +
      '  <b>Status Code:</b> ' + jsonData.status.statusCode + "<br>" +
      '  <b>Message:</b><br><div style="margin-bottom:10px; ' + cssHeight + '">' + statusMsg + "</div>" ;
      if(wbHash.get('context').get('gbAdminEmail') != undefined)
      {
        message += '  If you have questions or wish help with this error, please contact' +
        '  <a href="mailto:' + wbHash.get('context').get('gbAdminEmail') + '">' + wbHash.get('context').get('gbAdminEmail') + '</a>' +
        '  with the above information and any relevant details.' ;
      }
    }
    message += ('  <br>' + '</div></div>') ;
  }
  catch(err)
  {
    /* Should be html or text so display that */
    message = (result.responseText) ? result.responseText : "No response from server." ;
  }
  /* Define response codes that require a confirm dialog rather than alert */
  if(result.status == 417)
  {

    Ext.MessageBox.show(
    {
      title: 'Warnings',
      msg: message,
      buttons: Ext.MessageBox.YESNO,
      fn: warningsCallback,
      cls: "wbDialogAlert",
      ctCls: "wbDialogAlert"
    }) ;
  }
  else if(reLogin)
  {
    Ext.MessageBox.show(
    {
      title: windowTitle,
      msg: message,
      buttons: Ext.MessageBox.OK,
      cls: "wbDialogAlert",
      ctCls: "wbDialogAlert",
      fn: relogin
    }) ;
    if(wbDialogWindow) wbDialogWindow.enable() ;
  }
  else
  {

    Ext.MessageBox.show(
    {
      title: windowTitle,
      msg: message,
      buttons: Ext.MessageBox.OK,
      cls: "wbDialogAlert",
      ctCls: "wbDialogAlert"
    }) ;
    if(wbDialogWindow) wbDialogWindow.enable() ;
  }
}

function relogin(btn)
{
  window.location = '/java-bin/workbench.jsp' ;
}

function warningsCallback(btn)
{
  if (btn == 'yes') {
    /* Add warningsConfirmed to context and resubmit the job */
    wbHash.get('context').set('warningsConfirmed', true) ;
    submitToolJob($('wbDialogForm')) ;
  }
  else
  {
    resetWarningSettings() ;
    /* do nothing, return to dialog */
    wbDialogWindow.enable() ;
  }
}

// Function for reseting inputs solicited via the warnings dialog
function resetWarningSettings()
{
  // Set the special setting 'warningsSelectRadioBtn' to empty if present.
  if(wbFormSettings.get('warningsSelectRadioBtn') != null && wbFormSettings.get('warningsSelectRadioBtn') != undefined)
  {
    wbFormSettings.set('warningsSelectRadioBtn', '') ;
  }
}

// Handler for on click of Workbench toolbar buttons:
// Most buttons are associated with a tool and in such a case the function opens either:
//   (1) the settings dialog (if the tool is activated) or 
//   (2) the help dialog (if the tool is not activated)
// However, some tools serve as links to other pages -- these are intended to opened
//   in a new tab with no request for tool dialog of any kind
function windowDispatcher(toolIdStr, toolObj)
{
  if(toolObj.href == null) {
    if(toolActivated.get(toolIdStr))
    {
      showDialogWindow(toolIdStr) ;
    }
    else
    {
      showHelpWindow(toolIdStr) ;
    }
  }
  // otherwise do nothing -- link is handled natively via href attribute
}

/** Use this to show the tool settings dialog with rest of page masked. i.e. MODAL */
function showDialogWindow(toolIdStr, title, addThisToSettings)
{
  /* Be sure resources that are in the inputs/outputs are loaded to hash in the order displayed */
  updateWorkbenchObj() ;
  pageMask = new Ext.LoadMask(Ext.getBody(), { msg: null } ) ;
  pageMask.show() ;
  /* initialize, and ensure we don't have data from a previous dialog */
  wbHash.set('context', new Hash(clientContext)) ;
  wbHash.set('settings', new Hash()) ;
  if(addThisToSettings != null && addThisToSettings != undefined && addThisToSettings != '')
  {
    wbHash.get('settings').set(addThisToSettings, true) ;
  }
  wbHash.get('context').set('toolIdStr', toolIdStr) ;
  wbFormContext = new Hash() ;
  wbFormSettings = new Hash() ;
  globalToolIdStr = toolIdStr ;
  delete wbDialogWindow ;
  // Close the help window if it is already open and does not match the newly opened dialog
  if(Ext.WindowMgr.get('wbToolSettingsHelpWin'))
  {
    if(helpWindowToolId != null && helpWindowToolId != toolIdStr)
    {
      Ext.WindowMgr.get('wbToolSettingsHelpWin').close() ;
      helpWindowToolId = null ;
    }
    else
    {
      var helpWindowToolSettingBtn = Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn') ;
      helpWindowToolSettingBtn.disable() ;
      helpWindowToolSettingBtn.handler = function() {
      } ;
      helpWindowToolSettingBtn.disabled = true ;
      helpWindowToolSettingBtn.setTooltip('The settings/configuration window of this tool is already open.') ;
    }
  }
  if(title == null || title == undefined || title == '')
  {
    title = "Tool Settings" ;
  }
  wbDialogWindow = new Ext.Window(
  {
    id: 'wbToolSettingsWin',
    modal: false,
    autoScroll: true,
    constrainHeader: true,
    title: title,
    stateful: false,
    autoLoad: {
      url : '/REST/v1/genboree/ui/tool/' + toolIdStr + '/workbenchDialog?gbKey=TNkdABu0&_method=GET',
      jsonData: wbHash.toJSON(),
      method: 'POST',
      scripts: true,
      callback: dialogCallback,
      timeout: 60
    }
  }) ;
  wbDialogWindow.addListener('close', closeToolWindows, wbDialogWindow, { single: true } ) ;
  /* Workaround for 'jumpy' window when loaded, hide it immediately, use pageMask, then unhide it in the callback */
  wbDialogWindow.show() ;
  wbDialogWindow.hide() ;

}

function dialogCallback(el, success, response)
{
  /* For IE8 protection against 6000px-wide dialogs: */
  if(wbDialogWindow.container)
  {
    var wbDialogContent = wbDialogWindow.container.child('form.wbDialog.wbForm') ;
    if(!wbDialogContent) // Then must be a help dialog
    {
      wbDialogContent = wbDialogWindow.container.child('div.wbDialog.wbHelp') ;
    }
    if(wbDialogContent)
    {
      // Force width of wbDialogWindow based on contents
      var scrollBarWidth = (Ext.isIE ? 52 : 64) ;
      var widthExtras = (Ext.isIE ? (12 + 2) : 0) ;
      var divWidth = parseInt(wbDialogContent.getStyle('width')) ;
      divWidth = (isNaN(divWidth) ? wbDialogContent.getComputedWidth() : divWidth) ;
      wbDialogWindow.setWidth(divWidth + scrollBarWidth + widthExtras) ;
      // Force height of wbDialogWindow based on contents (adding in window border, title,etc )
      var divHeight = parseInt(wbDialogContent.getStyle('height')) ;
      var heightExtras = 25 + 6 + 40 + 2 + (Ext.isIE ? -30 : 0) ;
      divHeight = (isNaN(divHeight) ? wbDialogContent.getComputedHeight() : divHeight) ;
      wbDialogWindow.setHeight(divHeight + heightExtras) ;
    }
  }
  if(!success)
  {
    displayFailureDialog(response) ;
    wbDialogWindow.show() ; /* need to show before we try to close */
    wbDialogWindow.close() ;
  }
  else
  {
    /* Check to see if we got back the actual settings dialog or the help window with the error message */
    if(!wbDialogWindow.container.child('form.wbDialog.wbForm'))
    {
      /* We got back the help window with the error message. We need to close the window and reopen the help window as 'wbHelpWindow' */
      wbDialogWindow.close() ;
      setTimeout(function(){
        openFailedHelpWindow() ;
      },
      30) ;
    }
    else // the actual settings window
    {
      wbDialogWindow.center() ; /* center before showing so it doesn't jump */
      wbDialogWindow.show() ;
    }
  }
  // pageMask.hide() ;
}

/* This function is called when some of the rules aren't satisfied in the first pass of the rules helper and therefore the server responded with an error in the help window */
/* Hence, we will make the same API call which gets us the 'failed' response but this time we will open the help window with that information. */
function openFailedHelpWindow()
{
  helpWindowToolId = globalToolIdStr ;
  wbHelpWindow = new Ext.Window(
  {
    id: 'wbToolSettingsHelpWin',
    modal: false,
    autoScroll: true,
    constrainHeader: true,
    title: 'Help: Tool Settings',
    stateful: false,
    autoLoad: {
      url : '/REST/v1/genboree/ui/tool/' + helpWindowToolId + '/workbenchDialog?gbKey=TNkdABu0&_method=GET',
      jsonData: wbHash.toJSON(),
      method: 'POST',
      scripts: true,
      callback: failedHelpCallBack,
      timeout: 60
    }
  }) ;
   /* Workaround for 'jumpy' window when loaded, hide it immediately then unhide it in the callback */
  wbHelpWindow.show() ;
  wbHelpWindow.hide() ;
}

function failedHelpCallBack(el, success, response)
{
   /* For IE8 protection against 6000px-wide dialogs: */
  if(wbHelpWindow.container)
  {
    var wbDialogContent = wbHelpWindow.container.child('div.wbDialog.wbHelp') ; // Should be the help dialog content
    if(wbDialogContent)
    {
      // Force width of wbHelpWindow based on contents
      var scrollBarWidth = (Ext.isIE ? 52 : 64) ;
      var widthExtras = (Ext.isIE ? (12 + 2) : 0) ;
      var divWidth = parseInt(wbDialogContent.getStyle('width')) ;
      divWidth = (isNaN(divWidth) ? wbDialogContent.getComputedWidth() : divWidth) ;
      wbHelpWindow.setWidth(divWidth + scrollBarWidth + widthExtras) ;
      // Force height of wbHelpWindow based on contents (adding in window border, title,etc )
      var divHeight = parseInt(wbDialogContent.getStyle('height')) ;
      var heightExtras = 25 + 6 + 40 + 2 + (Ext.isIE ? -30 : 0) ;
      divHeight = (isNaN(divHeight) ? wbDialogContent.getComputedHeight() : divHeight) ;
      wbHelpWindow.setHeight(divHeight + heightExtras) ;
    }
  }
  wbHelpWindow.center() ; /* center before showing so it doesn't jump */
  wbHelpWindow.show() ;
}

function closeToolWindows()
{
  // Try to get rid of the pageMask
  if(pageMask && pageMask.hide)
  {
    pageMask.hide() ;
  }
  // Try to close the help window if also up.
  var toolWindow = Ext.WindowMgr.get('wbToolSettingsHelpWin') ;
  if(toolWindow && toolWindow.show && toolWindow.close)
  {
    if(Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn'))
    {
      Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn').destroy ;
    }
    toolWindow.show() ;
    toolWindow.close() ;
  }
  // Actual tool settings dialog
  toolWindow = Ext.WindowMgr.get('wbToolSettingsWin') ;
  if(toolWindow && toolWindow.show && toolWindow.close)
  {
    toolWindow.show() ;
    toolWindow.close() ;
  }
  if(helpWindowToolId && Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn'))
  {
    Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn').destroy() ;
  }
  /* Special color palette window for setting track style and color */
  if(Ext.ComponentMgr.get('colorPalette'))
  {
    Ext.ComponentMgr.get('colorPalette').destroy() ;
  }
  if(Ext.ComponentMgr.get('colorWindow'))
  {
    Ext.ComponentMgr.get('colorWindow').close() ;
  }
}

/** Use this to show a NON-MODAL help dialog for the tool. For use when user is ALSO
  * viewing that tool's setting dialog. */
function showHelpWindow(toolIdStr)
{
  /* We need to provide server with Workbench Form Entity. But without all
     the correct inputs/outputs, etc. Just context. Then server will give back help HTML. */
  var tmpHash = new Hash( { inputs:[], outputs:[], context:new Hash(), settings:new Hash() } ) ;
  /* initialize, and ensure we don't have data from a previous dialog */
  tmpHash.set('context', new Hash(clientContext)) ;
  tmpHash.get('context').set('toolIdStr', toolIdStr) ;
  if(helpWindowToolId && Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn'))
  {
    Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn').destroy ;
  }
  if(Ext.WindowMgr.get('wbToolSettingsHelpWin'))
  {
    Ext.WindowMgr.get('wbToolSettingsHelpWin').close() ;
  }
  helpWindowToolId = toolIdStr ;
  delete wbHelpWindow ;
  wbHelpWindow = new Ext.Window(
  {
    id: 'wbToolSettingsHelpWin',
    modal: false,
    autoScroll: true,
    constrainHeader: true,
    title: 'Help: Tool Settings',
    stateful: false,
    autoLoad: {
      url : '/REST/v1/genboree/ui/tool/' + toolIdStr + '/workbenchDialog?gbKey=TNkdABu0&_method=GET',
      jsonData: tmpHash.toJSON(),
      method: 'POST',
      scripts: true,
      callback: helpCallback,
      timeout: 60
    }
  }) ;
  /* Workaround for 'jumpy' window when loaded, hide it immediately then unhide it in the callback */
  wbHelpWindow.show() ;

  wbHelpWindow.hide() ;
}

function helpCallback(el, success, response)
{
  /* For IE8 protection against 6000px-wide dialogs: */
  if(wbHelpWindow.container)
  {
    var wbHelpContent = wbHelpWindow.container.child('div.wbDialog.wbHelp') ;
    if(wbHelpContent) // Could be some settings dialog if done correctly, or otherwise failed. Play it safe.
    {
      // Force width of wbDialogWindow based on contents
      var scrollBarWidth = (Ext.isIE ? 52 : 64) ;
      var divWidth = parseInt(wbHelpContent.getStyle('width')) ;
      divWidth = (isNaN(divWidth) ? wbHelpContent.getComputedWidth() : divWidth) ;
      wbHelpWindow.setWidth(divWidth + scrollBarWidth) ;
      // Force height of wbDialogWindow based on contents
      var divHeight = parseInt(wbHelpContent.getStyle('height')) ;
      divHeight = (isNaN(divHeight) ? wbHelpContent.getComputedHeight() : divHeight) ;
      wbHelpWindow.setHeight(divHeight) ;
    }
  }
  if(!success)
  {
    displayFailureDialog(response) ;
    wbHelpWindow.show() ; /* need to show before we try to close */
    wbHelpWindow.close() ;
  }
  else
  {
    wbHelpWindow.setPosition(20, 70) ; /* move before showing so it doesn't jump */
    wbHelpWindow.show() ;
    if(Ext.WindowMgr.get('wbToolSettingsWin'))
    {
      var helpWindowToolSettingBtn = Ext.ComponentMgr.get(helpWindowToolId + '_toolSettingsBtn') ;
      helpWindowToolSettingBtn.addClass('wbHelpWindowBtnReady') ;
      helpWindowToolSettingBtn.addClass('x-btn-text-icon') ;
      helpWindowToolSettingBtn.setIcon('/images/silk/accept.png') ;
      helpWindowToolSettingBtn.disable() ;
      helpWindowToolSettingBtn.setTooltip('The settings/configuration window of this tool is already open.') ;
    }
  }
}

function submitToolJob(dialogForm)
{
  if(wbDialogWindow.getEl().dom)
  {
    wbDialogWindow.disable() ;
  }

  /* capture the form element values into object */
  /* Must use the class method serialize because IE can't handle the instance method */
  var dialogFormObj = Form.serialize(dialogForm, true) ;
  /* Merge that with wbFormSettings from the tool's UI */
  var combinedFormSettings = wbFormSettings.merge(dialogFormObj) ;

  /* Set wbHash['settings'] to wbFormSettings */
  wbHash.set('settings', combinedFormSettings) ;
  /* Merge wbFormContext into wbHash['context'] */
  wbFormContext = wbHash.get('context').merge(wbFormContext) ;
  /* Set wbHash['context'] to wbFormContext */
  wbHash.set('context', wbFormContext) ;
  /* if this.action is set, this.method using Ajax.request */
  if(dialogForm.method.isNull)
  {
    dialogForm.method = 'POST' ;
  }
  if(dialogForm.action.match(/wbDefault/)) /* use the default for the workbench (else use whatever tool's <form> has for "action" attribute) */
  {
    dialogForm.action = '/java-bin/apiCaller.jsp' ;
  }
  /* IE will default to http://host/java-bin/ if action is empty, need to default to apiCaller.jsp  */
  /* Need to check if our action is workbench.jsp because WebKit will fill action with the referring page if it was blank */
  if(dialogForm.action.match(/java-bin\/?$/g) || dialogForm.action.match(/java-bin\/workbench.jsp/)) /* use the default based on toolIdStr */
  {
    dialogForm.action = '/java-bin/apiCaller.jsp' ;
  }
  /*
   * Careful, wbHash must be submitted as JSON text of a parameter called payload
  */
  /* Ext.Ajax.timeout = 90000 ; */
  /* Allow tools to clean the wbHash aka WorkbenchJobObj before submitting */
  if(typeof cleanJobObj === 'function') {
    wbHash = cleanJobObj(wbHash);
  }

  Ext.Ajax.request(
  {
    url : dialogForm.action,
    timeout : 90000,
    params:
    {
      rsrcPath: '/REST/v1/genboree/tool/' + wbHash.get('context').get('toolIdStr') + '/job?responseFormat=html',
      apiMethod : 'PUT',
      payload: wbHash.toJSON()
    },
    method: dialogForm.method,
    success: displaySuccessDialog,
    failure: displayFailureDialog
  }) ;
  return false ;
}
