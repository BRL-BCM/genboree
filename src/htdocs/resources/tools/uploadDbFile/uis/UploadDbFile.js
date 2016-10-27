var extUploadProgressBar = null;

UploadDbFile = {
  uploadForm : null,
  submitJob : function(form) {
    UploadDbFile.uploadForm = form
    // display the upload progress bar
    extUploadProgressBar = Ext.MessageBox.show({
      title: 'Please wait',
      msg: 'Uploading file.',
      progressText: 'Initializing...',
      width: 200,
      progress: true,
      closable: false
    });
    /* Set the context to a hidden form var */
    $('wbContext').value = wbHash.toJSON() ;
    /* POST to an rhtml script */
    ProgressUpload.startUpload(form, "/genbUpload/genboree/uploadDbFile.rhtml", null, UploadDbFile.uploadCallback, true);
    /* The callback of the upload should execute the secondary request, update attributes in this case. */
    return false ;
  },

  /**
   * Callback for the upload POST
   *
   * There is an issue uploading to genboree.org
   *
   * The issue is that when a Big file is uploaded (~3GB) but results may vary,
   * It appears that the connection is lost before the response is sent so the clients
   * The upload completes but browser times out with a "Connection Lost" error message.
   */
  uploadCallback : function(request, success, response) {
    /* After a brief pause, reload */
    if(true == success)
    {
      extUploadProgressBar.hide() ;
      /* Clear the wbContext on the form...not needed for the JSON phase, only for data upload phase (it only will confuse debugging). */
      $('wbContext').value = "" ;
      var json = response.responseText ;
      try {
        var respObj = Ext.decode(json) ;
        if(respObj.status.statusCode == 'OK')
        {
          /**
           * Once file is uploaded the script appends the new file resource to inputs and then submit another request.
           * In this case it would update the file attributes.
           **/
          wbHash.set('inputs', new Array()) ;
          wbHash.get('inputs').push(respObj.data.refUri) ;
          submitToolJob(UploadDbFile.uploadForm) ;
          /* Then remove the file resource from the inputs. */
          //wbHash.set('inputs', new Array()) ;
        }
        else
        {
          displayFailureDialog(response, 'Problem uploading file.') ;
        }
      }catch(err){
        displayFailureDialog(response, 'Problem uploading file.') ;
      }
//    wbDialogWindow.close() ;
    }
    else {
      if(confirm("There has been a problem with the upload.  Did not receive a response from the server.  You may need to upload again.  Would you like to reload the page?")) {

      }
    }
  }
}
