//------------------------------------------------------------------------------
//Initial variables
//------------------------------------------------------------------------------

//New Package Declaration
Ext.namespace("edu.bcm.brl") ;

// Init the singleton.  Any tag-based quick tips will start working.
Ext.QuickTips.init() ;

//Global Variable Declarations
var source = '' ;
var lffClass = '' ;
var lffType = '' ;
var build = null ;
var adminEmail = '' ;
var isLeaf = false ;
var dbName = '' ;
var groupName = '' ;
var checkedKeys = new Array() ;
var sourceList = new Array() ;
var recommendedTracks = new Array() ;
var trackDetails ;
var tree ;

// Used to store the results of the submition
var resultsStore = new Ext.data.SimpleStore(
{
  fields:
  [
    {
      name: "track"
    },
    {
      name: "source"
    },
    {
      name: 'className'
    },
    {
      name: 'description'
    }
  ]
}) ;

// Format of the records that are stored in the grid
var ResultsRecord = Ext.data.Record.create(
{
  fields:
  [
    {
      name: "track"
    },
    {
      name: "source"
    },
    {
      name: 'className'
    },
    {
      name: 'description'
    }
  ]
}) ;

// Used to store the information for the grid
var store = new Ext.data.SimpleStore(
{
  fields:
  [
    {
      name: "remove"
    },
    {
      name: "trackName"
    },
    {
      name: 'name'
    },
    {
      name: 'key'
    },
    {
      name: 'lastImport'
    }
  ]
}) ;

// Format of the records that are stored in the grid
var GridRecord = Ext.data.Record.create(
{
  fields:
  [
    {
      name: "remove"
    },
    {
      name: "trackName"
    },
    {
      name: 'name'
    },
    {
      name: 'key'
    },
    {
      name: 'lastImport'
    }
  ]
}) ;

//------------------------------------------------------------------------------
// AJAX Requests
//------------------------------------------------------------------------------

/**
  * Gets the build information using AJAX from a REST Service. If successfull
  * then it will display the page. If the build cannot be determined or is
  * invalid then it will display an error message.
  *
  * @returns <nothing>
*/
function getBuildInformation()
{
  dbName = dbName.toLowerCase() ;
  param = "/REST/v1/grp/" + fullEscape(groupName) +"/db/" + fullEscape(dbName) + "/version" ;
  var conn = new Ext.data.Connection() ;
  conn.request(
  {
    url: "apiCaller.jsp",
    method: "GET",
    params:
    {
      "rsrcPath": param,
      method : "GET"
    },
    success: function(responseObject)
    {
      build = eval('(' + responseObject.responseText + ')').data.text ;
      if(build != "")
      {
        Ext.EventManager.onDocumentReady(MyTree.init, MyTree, true) ;
      }
      else
      {
        var messageDiv = Ext.get("message") ;
        var importDiv = Ext.get("import") ;
        importDiv.hide() ;
        importDiv.remove() ;
        messageDiv.show() ;
        messageDiv.dom.innerHTML = "This database does not seem to be based on a known genome assembly (perhaps it is a custom genome?) and thus track import is not available." ;
        Ext.Msg.alert('Error', 'Unable to determine the build of your database') ;
      }
    },
    failure: function(responseObject)
    {
      var messageDiv = Ext.get("message") ;
      var importDiv = Ext.get("import") ;
      importDiv.hide() ;
      importDiv.remove() ;
      messageDiv.show() ;
      messageDiv.dom.innerHTML = "Currently we do not support this database version.<br>Please check back later for updates." ;
      Ext.Msg.alert('Error', 'Unable to determine the build of your database') ;
    }
  }) ;
}

/**
 * Gets the list of recommended tracks and if the list is greater then 0 then
 * display the "Recommended Tracks" button
 *
 * @returns <nothing>
 */
function hasRecommendedTracks()
{
  var recommendedButton = Ext.get("recommendedButton") ;
  recommendedButton.hide() ;
  // Get a list of the recommendedTracks
  for(var sourceCounter = 0 ; sourceCounter < sourceList.length ; sourceCounter++)
  {
    tempSource = sourceList[sourceCounter] ;
    recommendedTracksParam = "/REST/v1/resources/importer/build/" + fullEscape(build) + "/src/" + tempSource + "/trks?recommended=yes" ;
    var recommendedTracksConn = new Ext.data.Connection() ;
    recommendedTracksConn.request(
    {
      url: "apiCaller.jsp",
      method: "GET",
      params:
      {
        "rsrcPath": recommendedTracksParam,
        method : "GET"
      },
      success: function(responseObject)
      {
        sourceRecommendedTracks = eval('(' + responseObject.responseText + ')').data ;
        if(sourceRecommendedTracks.length > 0)
        {
          recommendedTracks = recommendedTracks.concat(sourceRecommendedTracks) ;
        }
      },
      failure: function()
      { }
    }) ;
  }

  trackDetailsParam = "/REST/v1/grp/" + fullEscape(groupName) + "/db/" + fullEscape(dbName) + "/trks?detailed=yes&connect=no "
  var trackDetailsConn = new Ext.data.Connection() ;
  trackDetailsConn.request(
  {
    url: "apiCaller.jsp",
    method: "GET",
    params:
    {
      "rsrcPath": trackDetailsParam,
      method : "GET"
    },
    success: function(responseObject)
    {
      trackDetails = eval('(' + responseObject.responseText + ')').data ;
      if(recommendedTracks.length > 0)
      {
        // Show Button
        recommendedButton.show() ;
      }
    },
    failure: function()
    { }
  }) ;
}

/**
  * Gets a list of default checked tracks using AJAX from a REST Service.
  * If successfull then the checked items will be added to the grid and kept in
  * an array keeping track of default checked tracks.
  *
  * @returns <nothing>
*/
function getRecommendedTracks()
{
  for(recommendedTracksCounter = 0 ; recommendedTracksCounter < recommendedTracks.length ; recommendedTracksCounter++)
  {
    track = recommendedTracks[recommendedTracksCounter] ;
    trackName = "" ;
    lastUpdated = "" ;
    alreadyEntered = false ;

    if((track.overrideLffType != ".") || (track.overrideLffSubType != "."))
    {
      trackName = track.overrideLffType + ":" + track.overrideLffSubType ;
    }
    else
    {
      trackName = getTrackName(track.lffType, track.lffSubtype) ;
    }
    
    text = track.source + ' =&gt; ' + track.key ;
    id = track.key ;
    
    addToGrid(trackName, text, id) ;
  }
}

/**
  * If the user has over the a certain number of tracks selected it will display
  * a warning that stating that this may take a significant amount of time.
  *
  * @returns <retVal> Returns True/False to submit the form.
*/
function submitTracks()
{
  retVal = false ;
  if(store.getCount() >= trackWarningNumber)
  {
    btn = confirm('Importing this many tracks may take a significant amount of time. Are you sure you want to do this?') ;
    if (btn == true)
    {
      postTracks() ;
      retVal = true ;
    }
  }
  else
  {
    postTracks() ;
    retVal = true ;
  }

  return retVal ;
}

/**
  * Populates the hidden fields with the required information and masks over the
  * work area indicating that it is submitting the request.
  *
  * @returns <nothing>
*/
function postTracks()
{
  //Get Keys from Grid and add the to the key String
  trackString = "" ;
  for(var recordID = 0 ; recordID < store.getCount() ; recordID++)
  {
    if(recordID != 0)
    {
      trackString += "," ;
    }
    trackString += store.getAt(recordID).id ;
  }

  //Submit the data
  var build_ele = Ext.get("build") ;
  var tracks_ele = Ext.get("tracks") ;
  build_ele.dom.value = build ;
  tracks_ele.dom.value = encodeURI(trackString) ;
}

/**
  * Handles the JSON results from the request for tracks from the REST API. It
  * parses the data so that it can be better displayed in the tree.
  *
  * @returns <nothing>
*/
Ext.Ajax.on('requestcomplete', function(conn, response, options)
{
  var myData = eval('(' + response.responseText + ')').data ;

  if(sourceList.length == 0)
  {
    for(var id = 0 ; id < myData.length ; id++)
    {
      sourceList[id] = myData[id].text ;
    }
    hasRecommendedTracks() ;
  }

  for(var id = 0 ; id < myData.length ; id++)
  {
    var tempData = myData[id] ;

    // If it is a leaf then it needs to be displayed as a leaf with a checkbox
    if(isLeaf == false)
    {
      var mySource = source ;
      var myLffClass = lffClass ;
      var myLffType = lffType ;
      position = escape(tempData.text) ;
      tempData.id = "" ;
      if(source == '')
      {
        mySource = position ;
      }
      else if (lffClass == '')
      {
        myLffClass = position ;
      }
      else if (lffType == '')
      {
        myLffType = position ;
      }
      tempData.cls= "folder" ;
      tempData.leaf = false ;
      tempData.lffSource = position ;
      tempData.source = mySource ;
      tempData.lffClass = myLffClass ;
      tempData.lffType = myLffType ;
    }
    else
    {
      tempData.text = tempData.lffType + " : " + tempData.lffSubtype + " (" + tempData.key + ")" ;
      tempData.id = tempData.key ;
      tempData.cls = "leaf" ;
      tempData.leaf = true ;
      tempData.checked = false ;
      if(tempData.recommended == true)
      {
        clickedNode = store.query('key', tempData.id).first() ;
        if(clickedNode != null)
        {
          tempData.checked = true ;
        }
      }
    }
    tempData.draggable = false ;
    myData[id] = tempData ;
  }

  // Take the converted data and override the responseText origionaly submitted
  var outData = JSON.stringify(myData) ;
  response.responseText = outData ;
}) ;

//------------------------------------------------------------------------------
//Grid Section
//------------------------------------------------------------------------------

/**
  * Checks to see when the last time a given track was imported using an AJAX
  * call to the REST API. If the request is successfull the date is added to the
  * grid. If the request fails or the track has not been imported before then
  * the date is display as never.
  * 
  * @param trackName
  *   The track name as it will be seen inside Genboree
  * @param text
  *   The text as it is seen in the tree structure
  * @param id
  *   The id of the track.
  * 
  * @returns <nothing>
*/
function addToGrid(trackName, text, id)
{
  lastUpdated = "" ;
  alreadyEntered = false ;

  for(trackDetailsCounter = 0 ; trackDetailsCounter < trackDetails.length ; trackDetailsCounter++)
  {
    trackDetail = trackDetails[trackDetailsCounter] ;
    if(trackName == trackDetail.name)
    {
      alreadyEntered = true ;
      attributes = trackDetail.attributes ;
      attributeFound = false ;
      for(attributeCounter = 0 ; attributeCounter < attributes.length ; attributeCounter++)
      {
        if(attributes[attributeCounter].name == "gbTrackImportTime")
        {
          attributeFound = true ;
          myTime = parseFloat(attributes[attributeCounter].value) * 1000 ;
          dt = new Date(myTime) ;
          lastUpdated = dt.format('F j, Y') ;
        }
      }
      if(attributeFound == false)
      {
        lastUpdated = "unknown" ;
      }
    }
  }

  if(alreadyEntered == false)
  {
    finalToGrid(trackName, text, id, "never") ;
  }
  else
  {
    finalToGrid(trackName, text, id, lastUpdated) ;
  }
}

/**
  * Adds the given data to the grid.
  *
  * @param trackName
  *   The track name as it will be seen inside Genboree
  * @param text
  *   The text as it is seen in the tree structure
  * @param id
  *   The id of the track.
  * @myTime
  *   The time of the last import.
  *
  * @returns <nothing>
*/
function finalToGrid(trackName, text, id, myTime)
{
  removeText = "<IMG ext:qwidth='100' ext:qtip=\'Remove Track' name=\"Remove\" src=\"/images/silk/cross.png\" style=\"width: 12px ; height: 12px ;\" onclick=\"removeFromGrid('" + id + "')\">" ;
  trackName = "<div ext:qwidth='100' ext:qtip=\'" + trackName + "'>" + trackName + "</div>" ;
  text = "<div ext:qwidth='300' ext:qtip=\'" + text + "'>" + text + "</div>" ;
  myTime = "<div ext:qwidth='100' ext:qtip=\'" + myTime + "'>" + myTime + "</div>" ;
  
  var newRecord = new GridRecord(
  {
    remove: removeText,
    trackName: trackName,
    name: text,
    key: id,
    lastImport: myTime
  },
  id) ;

  if(store.getById(id) == null)
  {
    store.add(newRecord) ;
  }

  store.sort("trackName", "ASC") ;
  
  treeNode = tree.getNodeById(id) ;
  if(treeNode != null)
  {
    treeNode.getUI().toggleCheck(true) ;
  }
  
  Ext.get('importButton').dom.disabled = false ;
}

/**
 * Adds the data to the results Grid
 *
 * @param trackName
 *   The name of the track as it will appear in the results grid
 * @param source
 *   The source of the track as it will appear in the results grid
 * @param class
 *   The class of the track as it will appear in the results grid
 * @param description
 *   The description of the track as it will appear in the results grid
 * @param id
 *   The id of the track.
 *
 * @returns <nothing>
 */
function addToResultsGrid(trackName, source, className, description, id)
{
  trackName = "<div ext:qwidth='100' ext:qtip=\'" + trackName + "'>" + trackName + "</div>" ;
  source = "<div ext:qwidth='100' ext:qtip=\'" + source + "'>" + source + "</div>" ;
  className = "<div ext:qwidth='100' ext:qtip=\'" + className + "'>" + className + "</div>" ;
  description = "<div ext:qwidth='100' ext:qtip=\'" + description + "'>" + description + "</div>" ;

  var newRecord = new ResultsRecord(
  {
    track: trackName,
    source: source,
    className: className,
    description: description
  },
  id) ;

  resultsStore.add(newRecord) ;
  resultsStore.sort("track", "ASC") ;
}

/**
 * Remove the given node from the grid
 *
 * @param node
 *   The node name to search for to uncheck it on the tree and remove it from the
 *   grid
 *
 * @returns <nothing>
*/
function removeFromGrid(node)
{
  clickedNode = store.query('key', node).first() ;
  //Put in to prevent a condition that happens when you click to fast
  if(clickedNode != null)
  {
    treeNode = tree.getNodeById(clickedNode.id) ;
    if(treeNode != null)
    {
      treeNode.getUI().toggleCheck(false) ;
    }
    for(var ii = 0 ; ii < checkedKeys.length ; ii++)
    {
      if(checkedKeys[ii] == clickedNode.id)
      {
        checkedKeys.splice(ii,1) ;
      }
    }
    store.remove(clickedNode) ;

    if(store.getCount() == 0)
    {
      Ext.get('importButton').dom.disabled = true ;
    }
  }
}

//------------------------------------------------------------------------------
//Tree Section
//------------------------------------------------------------------------------

/**
 * Create a custom treeloader that will handle the REST API requests
 *
 * @returns <nothing>
*/
edu.bcm.brl.TreeLoader = Ext.extend(Ext.tree.TreeLoader,
{
  requestData : function(node, callback, scope)
  {
    if(build == null)
    {
      var databaseSelection = Ext.get("rseq_id") ;
      var databaseValue = databaseSelection.value ;
      var importDiv = Ext.get("import") ;

      if(databaseValue != "")
      {
        importDiv.display = "block" ;
        getBuildInformation() ;
      }
      else
      {
        importDiv.display = "none" ;
      }
    }
    else
    {
      if(this.fireEvent("beforeload", this, node, callback) !== false)
      {
        if(this.directFn)
        {
          var args = this.getParams(node) ;
          args.push(this.processDirectResponse.createDelegate(
            this,
            [
              {
                callback: callback,
                node: node,
                scope: scope
              }
            ],
            true)) ;
          this.directFn.apply(window, args) ;
        }
        else
        {
          this.transId = Ext.Ajax.request(
          {
            method: this.requestMethod,
            url: this.dataUrl,
            timeout: this.requestTimeout,
            success: this.handleResponse,
            failure: function(responseObject)
            {
              var messageDiv = Ext.get("message") ;
              var importDiv = Ext.get("import") ;
              importDiv.hide() ;
              messageDiv.show() ;
              importDiv.remove() ;
              statusCode = eval('(' + responseObject.responseText + ')').status.statusCode ;
              if(statusCode == "Not Found")
              {
                messageDiv.dom.innerHTML = "Currently, importing tracks from remote sites is not supported for this genome [" + build + "].<br><br>Please contact us at <a href='mailto:" + adminEmail + "'>" + adminEmail + "</a> if you would like to request track import support for this genome.<br><br>" ;
                Ext.Msg.alert('Error', 'Currently, importing tracks from remote sites<br>is not supported for this genome [' + build + '].') ;
              }
              else
              {
                messageDiv.dom.innerHTML = "A communication error has occurred" ;
                Ext.Msg.alert('Error', 'A communication error has occurred') ;
              }
            },
            scope: this,
            argument:
            {
              callback: callback,
              node: node,
              scope: scope
            },
            disableCaching : false,
            params:
            {
              rsrcPath: getRsrcPath(node),
              method: "GET"
            }
          }) ;
        }
      }
      else
      {
        // if the load is cancelled, make sure we notify
        // the node that we are done
        this.runCallback(callback, scope || node, []) ;
      }
    }
  }
}) ;

/**
 * Overrides the default TreeEventModel. This is done to eliminate mouse over
 * and mouse out problems with EXT. Also adds checked and unchecked
 * functionality to the tree.
 *
 * @returns <nothing>
 */
Ext.override(Ext.tree.TreeEventModel,
{
  trackExit : function(event)
  {
    if(this.lastOverNode)
    {
      if(this.lastOverNode.ui && !event.within(this.lastOverNode.ui.getEl()))
      {
        this.onNodeOut(event, this.lastOverNode) ;
      }
      delete this.lastOverNode ;
      Ext.getBody().un('mouseover', this.trackExit, this) ;
      this.trackingDoc = false ;
    }
  },
  delegateOut : function(event, target)
  {
    var node = this.getNode(event) ;
    if(this.disabled || !node || !node.ui)
    {
      event.stopEvent() ;
      return ;
    }
    if(event.getTarget('.x-tree-ec-icon', 1))
    {
      var node = this.getNode(event) ;
      this.onIconOut(event, node) ;
      if(node == this.lastEcOver)
      {
        delete this.lastEcOver ;
      }
    }
    if((target = this.getNodeTarget(event)) && !event.within(target, true))
    {
      this.onNodeOut(event, this.getNode(event)) ;
    }
  },
  delegateOver : function(event, target)
  {
    var node = this.getNode(event) ;
    if(this.disabled || !node || !node.ui)
    {
      event.stopEvent() ;
      return ;
    }
    if(this.lastEcOver)
    {
      this.onIconOut(event, this.lastEcOver) ;
      delete this.lastEcOver ;
    }
    if(event.getTarget('.x-tree-ec-icon', 1))
    {
      this.lastEcOver = this.getNode(event) ;
      this.onIconOver(event, this.lastEcOver) ;
    }
    if(target = this.getNodeTarget(event))
    {
      this.onNodeOver(event, this.getNode(event)) ;
    }
  },
  onCheckboxClick : function(event, node)
  {
    if(node != undefined)
    {
      var checked = node.attributes.checked ;
      if(checked == false)
      {
        type = node.attributes.lffType ;
        subType = node.attributes.lffSubtype ;

        trackName = "" ;
        if((node.attributes.overrideLffType != ".") || (node.attributes.overrideLffSubType != "."))
        {
          trackName = node.attributes.overrideLffType + ":" + node.attributes.overrideLffSubType ;
        }
        else
        {
          trackName = getTrackName(type, subType) ;
        }
        addToGrid(trackName, node.attributes.source + ' =&gt; ' + node.id, node.id) ;
      }
      else
      {
        removeFromGrid(node.id) ;
      }
      node.attributes.checked = !checked ;
    }
  },
  onIconClick : function(event, node)
  {
    if(this.disabled || !node || !node.ui)
    {
      event.stopEvent() ;
      return ;
    }
    node.ui.ecClick(event) ;
  },
  onNodeClick : function(event, node)
  {
    if(this.disabled || !node || !node.ui)
    {
      event.stopEvent() ;
      return ;
    }
    node.ui.onClick(event) ;
  }
}) ;

/**
 * Creates the tree and defines what functions to use for loading data.
 *
 * @returns <nothing>
 */
var MyTree = function()
{
  var Tree = Ext.tree ;
  return {
    init : function()
    {
      //Setup and use our new loader
      var loadme = new edu.bcm.brl.TreeLoader(
      {
        preloadChildren: true,
        clearOnLoad: true,
        requestMethod: "GET",
        dataUrl: "apiCaller.jsp"
      }) ;
      //Setup the TreePanel
      tree = new Tree.TreePanel(
      {
        el:'tree',
        animate:true,
        autoScroll:true,
        containerScroll:true,
        width:660,
        rootVisible:false,
        loader: loadme,
        enableDD:false
      }) ;

      // add a tree sorter in folder mode
      new Tree.TreeSorter(tree,
      {
        folderSort:true
      }) ;

      var root = new Tree.AsyncTreeNode(
      {
        text: 'Root',
        draggable:false,
        id: 'Root',
        source: '',
        lffClass: '',
        lffType: ''
      }) ;

      tree.setRootNode(root) ;
      if(Ext.get('tree') != null)
      {
        tree.render() ;
        root.expand(false, false) ;
      }
    }
  } ;
}() ;

//------------------------------------------------------------------------------
//Help Section
//------------------------------------------------------------------------------

//An array of help messages to be displayed.
var helpMessages =
{
  'trackImporterInstructions' :
  {
    'title' : 'Help: Track Importer Instructions',
    'text' : '<p class="helpWindow">' +
    'The track importer allows you to select one or more tracks from public repositories and schedule them for upload into your Genboree database.' +
    '</p>' +
    '<ul class="helpWindow">' +
    '<li type=disc><p>The latest version of the track will be imported.</p></li>' +
    '<li type=disc><p>Although uploading multiple tracks can take time and is subject to resource availability, you will receive an email as each track is imported.</p></li>' +
    '</ul>' +
    '<p class = "helpWindow">Use the tree to below to locate the track(s) you want import, starting with the remote repository hosting the data.' +
    '</p>' +
    '<ul class="helpWindow">' +
    '<li type=disc><p>Check the box next to track(s) you want to import ; it will be added to the list.</p></li>' +
    '<li type=disc><p>When the list contains all the tracks you want, click the Import button.</p></li>' +
    '<li type=disc><p>To remove a track from the import list, click the X icon</p></li>' +
    '</ul>' +
    '<p class = "helpWindow">Some template genomes have a recommended set of tracks already selected. Click on the Recommended Tracks button to get these tracks</p>' +
    '</p>'
  }
} ;

/**
  * Display a popup dialog with the specified title and help string. The title
  * will default to "Help" if it was not passed to the function.
  * @param button
  *   The button that was pressed to generate this dialog (for position).
  * @param text
  *   The help text to display in the main body of the dialog.
  * @param title
  *   (optional) The title of the help dialog. Defaults to "Help".
  * @returns <nothing>
*/
function displayHelpPopup(button, text, title)
{
  if (!title)
  {
    title = "Help" ;
  }

  Ext.Msg.show(
  {
    title: title,
    msg : text,
    height: 150,
    width: 385,
    minHeight: 150,
    minWidth: 150,
    modal: false,
    proxyDrag: true
  }) ;
  Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;

}

//------------------------------------------------------------------------------
//Utilities Section
//------------------------------------------------------------------------------

/**
 * Returns the track name that will be seen inside Genboree. This involves
 * reviewing the type and subtype to ensure that they confine by the rules for
 * displaying data inside Genboree.
 *
 * @param origType
 *   The origional Type
 * @param origSubType
 *   The origional Subtyp
 * @returns The new track name.
 */
function getTrackName(origType, origSubType)
{
  type = origType ;
  subType = origSubType ;

  if(origType.length + subType.length > 18)
  {
    type = origType.match(/^(\S+)(.+)$/)[1].trim() ;
    subType = origType.match(/^(\S+)(.+)$/)[2].trim() ;

    if(subType.length <= 1)
    {
      type = origSubType.match(/^(\S+)(.+)$/)[1].trim() ;
      subType = origSubType.match(/^(\S+)(.+)$/)[2].trim() ;
    }

    if(type.indexOf(" ") != " ")
    {
      type = type.split(" ")[0] ;
    }

    if(subType.indexOf(" ") != " ")
    {
      subType = subType.split(" ")[0] ;
    }

    if(type.length + subType.length > 18)
    {
      if(type.length > subType.length)
      {
        newLength = 18 - subType.length ;
        type = type[0, newLength] ;
      }
      else
      {
        newLength = 18 - type.length ;
        subType = subType[0, newLength] ;
      }
    }
  }

  trackName = type + ":" + subType ;
  return trackName ;
}

/**
 * Based on the NodeID return the correct REST API resource path. This is used
 * by the tree loader to make sure the correct call is made.
 *
 * @param node
 *   The node that is being asked to expand in the tree structure
 *
 * @returns the REST API resource path needed
 */
function getRsrcPath(node)
{
  retVal = "NULL" ;
  var myID = unescape(node.id) ;
  var mySource = unescape(node.attributes.source) ;
  var myClass = unescape(node.attributes.lffClass) ;
  var myType = unescape(node.attributes.lffType) ;

  if(myID == "Root")
  {
    source = '' ;
    lffClass = '' ;
    lffType = '' ;
    isLeaf = false ;
    retVal = "/REST/v1/resources/importer/build/" + fullEscape(build) + "/srcs" ;
  }
  else if((mySource != 'Root') && (myClass == '') && (myType == ''))
  {
    source = mySource ;
    lffClass = '' ;
    lffType = '' ;
    isLeaf = false ;
    retVal = "/REST/v1/resources/importer/build/" + fullEscape(build) + "/src/" + fullEscape(source) + "/classes" ;
  }
  else if((mySource != '') && (myClass != '') && myType == '')
  {
    source = mySource ;
    lffClass = myClass ;
    lffType = '' ;
    isLeaf = false ;
    retVal = "/REST/v1/resources/importer/build/" + fullEscape(build) + "/src/" + fullEscape(source) + "/class/" + fullEscape(lffClass) + "/types" ;
  }
  else if((mySource != '') && (myClass != '') && (myType != ''))
  {
    source = mySource ;
    lffClass = myClass ;
    lffType = myType ;
    isLeaf = true ;
    retVal = "/REST/v1/resources/importer/build/" + fullEscape(build) + "/src/" + fullEscape(source) + "/trks/class/" + fullEscape(lffClass) + "/type/" + fullEscape(lffType) ;
  }

  return retVal ;
}

//------------------------------------------------------------------------------
// Page Startup
//------------------------------------------------------------------------------

/**
 * Setup the Grid and render it to the Grid Panel
 *
 * @returns <nothing>
 */
Ext.onReady(function()
{
  dbPullDown = Ext.get("rseq_id") ;
  if(dbPullDown.getValue() == "")
  {
    var messageDiv = Ext.get("message") ;
    var importDiv = Ext.get("import") ;
    importDiv.hide() ;
    messageDiv.show() ;
    importDiv.remove() ;
    messageDiv.dom.innerHTML = "Please select a database to import into." ;
  }
  else
  {
    if(Ext.get('importButton') != null)
    {
      Ext.get('importButton').dom.disabled = true ;
    }
    Ext.state.Manager.setProvider(new Ext.state.CookieProvider()) ;

    var grid = new Ext.grid.GridPanel(
    {
      store: store,
      columns: [
      {
        id: 'remove',
        menuDisabled: true,
        header: "",
        width: 20,
        sortable: false,
        dataIndex: 'remove'
      },
      {
        header: "Track",
        width: 200,
        sortable: true,
        dataIndex: 'trackName'
      },
      {
        header: "Key",
        width: 270,
        sortable: true,
        dataIndex: 'name'
      },
      {
        header: "Last Imported",
        width: 170,
        sortable: true,
        dataIndex: 'lastImport'
      }],
      height:255,
      width:660,
      viewConfig:
      {
        scrollOffset: 0,
        forceFit: true
      }
    }) ;

    if(Ext.get('grid') != null)
    {
      grid.render('grid') ;
    }

    var resultsGrid = new Ext.grid.GridPanel(
    {
      store: resultsStore,
      columns: [
      {
        header: "Track",
        width: 120,
        sortable: true,
        dataIndex: 'track'
      },
      {
        header: "Source",
        width: 80,
        sortable: true,
        dataIndex: 'source'
      },
      {
        header: "Class",
        width: 120,
        sortable: true,
        dataIndex: 'className'
      },
      {
        header: "Description",
        width: 350,
        sortable: true,
        dataIndex: 'description'
      }],
      height: 194,
      width: 660,
      viewConfig:
      {
        scrollOffset: 0,
        forceFit: true
      }
    }) ;

    if(Ext.get('gridResults') != null)
    {
      resultsGrid.render('gridResults') ;
      addSubmittedToGrid() ;
    }

    MyTree.init() ;
  }
}) ;
