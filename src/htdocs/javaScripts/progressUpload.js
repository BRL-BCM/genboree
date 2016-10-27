var ProgressUpload = {
  /**
   * Configurable parameters for the progress meter.
   *
   * TODO: Some of the style/html could be pulled out from the methds below and made configurable
   */
  
  /* milliseconds in between upload progress requests */  
  statusUpdateInterval : 2000,
  /* milliseconds to wait before timeout warning message is displayed */
  activityTimeOut : 60000,
  /* milliseconds before the redirect page is loaded after upload is complete */
  reloadDelay : 1000,
  /* milliseconds to wait before forcing a reload, after waiting for the response from the upload POST
   * This is used to reduce the wait time for the connection lost timeout on genboree.org for big uploads */
  forceReloadDelay : 20000,
  /* milliseconds to wait before warning that there may be a problem due to receiving too many 'starting' responses */
  startingTimeOut : 60000,
  /* Width of the progress bar in pixels */  
  progressBarWidth : 400,
  /* URL of the location of the upload page */
  currentLoc : window.location.href,
  /* URL of the location that will be loaded when upload is complete */
  redirectLoc : window.location.href,
  /* Interval opject that schedules the progress update requests */
  progressIntervalObj : null,
  /* Tracks the size of the file uploaded so far */
  lastReceivedSize : 0,
  /* Tracks consecutive requests that haven't changed in size */
  sameSizeCount : 0,
  /* Tracks consecutive requests that respond with status 'starting' */
  startingCount : 0,
  /* Used by workbench dbFile uploads */  
  useExtJsProgressBar : false,
  /**
   * Method returning the html that will be the progress bar
   */
  getLoadingMsgDiv : function() {
    return  'File is uploading...<br><br><span style="font-size:80%">Please be patient.  The page will refresh when the upload is complete.  If the upload takes a long time, you may be signed out when the upload completes.  Sign back in to view your data.<span><br><br>'
          + '  <div id="progress" style="width: ' + (ProgressUpload.progressBarWidth + 2) + 'px; border: 1px solid black">'
          + '    <div id="progressbar" style="width: 1px; background-color: black; border: 1px solid white; height:10px;"></div>'
          + '  </div>';  
  },
  
  /**
   * This method performs the upload, displaying the progress bar
   *
   * [form]       The html form element
   * [uploadUrl]  The action URL that will handle the upload, if null default if form.action
   * [redirctUrl] After the upload is complete this page will be loaded, if null default is the current location
   */
  startUpload : function (form, uploadUrl, redirectUrl, uploadCallback, useExtJsProgressBar) {
    if(!uploadUrl)
    {
      uploadUrl = form.action ;
    }
    if(redirectUrl)
    {
      ProgressUpload.redirectLoc = redirectUrl ;
    }
    if(!uploadCallback)
    {
      uploadCallback = ProgressUpload.uploadCallback ;
    }
    if(useExtJsProgressBar)
    {
      ProgressUpload.useExtJsProgressBar = true ;
    }
    // Generate random X-Progress-ID and append to action url
    var uuid = ProgressUpload.getUuid() ;
    uploadUrl += (uploadUrl.indexOf('?') > 0) ? '&' : '?' ;
    uploadUrl += 'X-Progress-ID=' + uuid ;
    
    /* Warning, this request is not what it appears. See ExtJS docs about 'isUpload' option */
    Ext.Ajax.request({
      url: uploadUrl,
      method: 'post',
      callback: uploadCallback,
      isUpload: true,
      form: form,
      async: false
    }) ;
    /* call the progress-updater every ?ms */
    ProgressUpload.progressIntervalObj = window.setInterval( function () {  ProgressUpload.getUploadProgress(uuid, useExtJsProgressBar);  }, ProgressUpload.statusUpdateInterval ) ;
    return false ;
  },

  /**
   * Generate unique id for the upload, which will be used to query the progress module
   */
  getUuid : function() {
    var uuid = "";
    for (i = 0; i < 32; i++) {
      uuid += Math.floor(Math.random() * 16).toString(16);
    }
    return uuid;  
  },

  /**
   * Called at each interval, gets progress status and displays the updated bar.
   *
   * [uuid]   unique id for the upload
   */
  getUploadProgress : function(uuid) {
    /**
     * In any WebKit based browsers (Chrome and Safari), we do a synchronous XMLHttpRequest because of this bug
     * https://bugs.webkit.org/show_bug.cgi?id=23933
     * and using async: false for Ext.Ajax.request doesn't work either so we'll do it the old fashioned way
     */
    if(navigator.userAgent.toLowerCase().indexOf('webkit') > -1) {
      req = new XMLHttpRequest();
      req.open("GET", "/genbUploadProgress", false);
      req.setRequestHeader("X-Progress-ID", uuid);
      req.onreadystatechange = function() {
        if (req.readyState == 4) {
          if (req.status == 200) {
            ProgressUpload.getProgressCallback(req);
          }
        }
      };
      req.send(null);
    } else {
      Ext.Ajax.request({
        url: "/genbUploadProgress",
        method: 'get',
        success: ProgressUpload.getProgressCallback,
        headers: {"X-Progress-ID": uuid}
      });
    }
  },
  
  /**
   * Callback function for the progress status GET
   */
  getProgressCallback : function(resp) {
    if(ProgressUpload.useExtJsProgressBar)
    {
      ProgressUpload.updateExtProgressBar(resp.responseText);
    }
    else
    {
      ProgressUpload.updateProgressBar(resp.responseText);
    }
  },

  /**
   * Update the Ext.progressbar
   */
  updateExtProgressBar : function(respText) {
    var upload = eval(respText);
    /* change the width if the progress-bar */
    if (upload.state == 'uploading') {
      if(upload.received != ProgressUpload.lastReceivedSize) {
        ProgressUpload.lastReceivedSize = upload.received;
        ProgressUpload.sameSizeCount = 0;
      }
      extUploadProgressBar.updateProgress(upload.received / upload.size, 'Uploaded ' + Ext.util.Format.fileSize(upload.received) + ' of ' + Ext.util.Format.fileSize(upload.size));    
    }
    if(upload.received == ProgressUpload.lastReceivedSize) {
      /* the value hasn't changed */
      ProgressUpload.sameSizeCount++;
      if(ProgressUpload.sameSizeCount * ProgressUpload.statusUpdateInterval == ProgressUpload.activityTimeOut) {
        window.clearInterval(ProgressUpload.progressIntervalObj);
        if(confirm("There has been a problem with the upload.  The upload appears incomplete and you may need to upload again.  Would you like to reload the page?")) {
//          wbDialogWindow.close();
        }
      }
    }
    /* If the status is 'starting' for too long there's proabably a problem
     * Also, a problem if receiving 'started' after having received 'uploading' */
    if (upload.state == 'starting') {
      ProgressUpload.startingCount++;
      if(ProgressUpload.startingCount * ProgressUpload.statusUpdateInterval == ProgressUpload.startingTimeOut || ProgressUpload.lastReceivedSize > 0) {
        window.clearInterval(ProgressUpload.progressIntervalObj);
        if(confirm("There has been a problem (not started) with the upload.  You may need to upload again.  Would you like to reload the page?")) {
 //         wbDialogWindow.close();
        }
      }      
    }
    /* done, stop the interval */
    if (upload.state == 'done') {
      extUploadProgressBar.updateProgress(1, 'Upload complete');    
      window.clearInterval(ProgressUpload.progressIntervalObj);
      /* The page should reload at this point, but the uploader callback,
       * but due to the genboree.org connection issue, we can force this here after a brief pause. */
//      wbDialogWindow.close();
    }
  },


  /**
   * Update the divs that are the progress bar
   */
  updateProgressBar : function(respText) {
    var upload = eval(respText);
    var bar = $('progressbar');
    /* change the width if the inner progress-bar */
    if (upload.state == 'uploading') {
      if(upload.received != ProgressUpload.lastReceivedSize) {
        ProgressUpload.lastReceivedSize = upload.received;
        ProgressUpload.sameSizeCount = 0;
      }
      var w = ProgressUpload.progressBarWidth  * upload.received / upload.size;
      bar.style.width = w + 'px';
    }
    if(upload.received == ProgressUpload.lastReceivedSize) {
      /* the value hasn't changed */
      ProgressUpload.sameSizeCount++;
      if(ProgressUpload.sameSizeCount * ProgressUpload.statusUpdateInterval == ProgressUpload.activityTimeOut) {
        window.clearInterval(ProgressUpload.progressIntervalObj);
        if(confirm("There has been a problem with the upload.  The upload appears incomplete and you may need to upload again.  Would you like to reload the page?")) {
          window.location = ProgressUpload.currentLoc;
        }
      }
    }
    /* If the status is 'starting' for too long there's proabably a problem
     * Also, a problem if receiving 'started' after having received 'uploading' */
    if (upload.state == 'starting') {
      ProgressUpload.startingCount++;
      if(ProgressUpload.startingCount * ProgressUpload.statusUpdateInterval == ProgressUpload.startingTimeOut || ProgressUpload.lastReceivedSize > 0) {
        window.clearInterval(ProgressUpload.progressIntervalObj);
        if(confirm("There has been a problem (not started) with the upload.  You may need to upload again.  Would you like to reload the page?")) {
          window.location = ProgressUpload.currentLoc;
        }
      }      
    }
    /* done, stop the interval */
    if (upload.state == 'done') {
      bar.style.width = ProgressUpload.progressBarWidth  + 'px';
      window.clearInterval(ProgressUpload.progressIntervalObj);
      /* The page should reload at this point, but the uploader callback,
       * but due to the genboree.org connection issue, we can force this here after a brief pause. */
      ProgressUpload.loadRedirectLoc(ProgressUpload.forceReloadDelay);
    }
  },

  loadRedirectLoc : function(delay) {
    if(!delay) {
      delay = ProgressUpload.reloadDelay;
    }
    (new Ext.util.DelayedTask()).delay( ProgressUpload.reloadDelay, function() { window.location = ProgressUpload.redirectLoc; }) ;
  },
  
  /**
   * Callback for the upload POST
   *
   * There is an issue uploading to genboree.org
   *
   * The issue is that when a Big file is uploaded (~3GB) but results may vary,
   * It appears that the connection is lost before the response is sent so the clients
   * The upload completes but browser times out with a "Connection Lost" error message.
   *
   * Because of this, we can't rely on the response from the upload POST and always redirct assuming the upload was successful.
   * Not great, but works for now.
   *
   */
  uploadCallback : function(request, success, response) {
    /* After a brief pause, reload */
    if(true === success)
    {
        ProgressUpload.loadRedirectLoc();
    } else {
      if(confirm("There has been a problem with the upload.  Did not receive a response from the server.  You may need to upload again.  Would you like to reload the page?")) {
        window.location = ProgressUpload.currentLoc;
      }
    }
  }
} ;