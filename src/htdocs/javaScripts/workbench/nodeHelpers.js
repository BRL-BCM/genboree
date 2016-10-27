/**
 * This is the base class which provides the generic functionality for loading nodes into the tree
 * and loading information into the Details Panel. The tree is provided by Ext.tree.TreeLoader.
 * Note a couple of things about this tree:
 *   Ext.tree.AsyncTreeNode(s) are populated only if a node does not have its children defined.
 *   AsyncTreeNodes without children make async requests via an Ext.tree.TreeLoader
 *   Tree nodes (Async or other) require a couple Ext JS "configs": "text" (the label for the node) 
 *     and "iconCls" (which icon to display next to the node as a css image)
 *   Tree nodes can (and do here) take other configs. When a node is loaded onto the tree, there are
 *     two relevant objects: the "node attributes" which are the configs that the node was created with,
 *     and the node object itself, which contains a reference to the attributes at node.attributes
 * Specific node helpers are defined for two purposes: (1) displaying avps in a details panel when a node is
 *   clicked and (2) getting the child nodes when a node is expanded. The methods for these are defined
 *   in the generic NodeHelper class and are overriden by specific node helpers e.g. DbNodeHelper.
 * When a node is clicked or expanded its "rsrcType" attribute is used to associate the node with its NodeHelper
 *   via the "NodeHelperSelector" class.
 */
NodeHelper = function()
{
  /**
   * Use this array to configure the display order of attributes.
   * Array can contain a subset of the attributes in the API response.
   * Attributes not in this array will be appended to the end.
   */
  this.DETAILS_ATTR_ORDER = [] ;

  /**
   * Use this array to hide certain attributes. By default 'refs' is hidden
   */
  this.DETAILS_HIDDEN_ATTRS = ["refs"] ;

  /**
   * Use object to reformat certain attribute,
   * example:  { attrKey: function(attrValue) { return formatValue(attrValue); } }
   */
  this.DETAILS_ATTR_FORMATTERS = {} ;

  /**
   * Update the information displayed in the details panel, override this for custom Details behavior
   *
   * This function makes an ajax request to the URL defined in the node attribute 'detailsPath'.
   */
  this.updateDetails = function(node)
  {
    /* alert(node.attributes.detailsPath) ; */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS, this.DETAILS_LOADER_SETTINGS) ;
    loader.loadFromAPI() ;
  } ;

  /**
   * This method takes the API response and converts it to ExtJS TreeNodes
   * API response should be an array of objects.
   *
   * Override this for custom node behavior
   *
   * Important attributes of a TreeNode that are specific to the workbench
   * refsUri:     The API URI that represents the resource and is used in the inputs/outputs hashes.
   * detailsPath: The API URI path used for populating the details panel.
   * rsrcPath:    The API URI path used for populating the nodes children.
   * rsrcType:    The node API resource type (grp, db, prj, etc...).  Corresponds to the type of API resource that it represents
   *
   * Important attribute that should be defined. See ExtJS docs
   * text:        The label for the node
   *
   * Optional attributes. See ExtJS docs
   * leaf:        Boolean
   * children:    Array of node configuration objects
   * iconCls:     css class used for defining custom TreeNode icon
   *
   */
  this.translateResponseForNodes = function(restData)
  {
    if(restData.length == 0) {
      restData.push(this.EMPTY_LEAF);
    }
    return restData ;
  } ;

  /**
   * An extJS config object used for an empty directory
   */
  this.EMPTY_LEAF =
  {
    text: '(empty)',
    rsrcType: 'empty',
    expandable: false,
    draggable: false,
    leaf: true,
    iconCls: 'wbNoIconTreeNode'
  } ;

  /***********/
  /* Helpers */
  /***********/

  /**
   * Get the refs formats from an API refs object
   */
  this.getRefsFormats = function(refsObj)
  {
    var retVal = null ;
    // Return the value of first refs key
    for(var key in refsObj)
    {
      retVal = key ;
      break ;
    }
    return retVal ;
  } ;

  /**
   * Get the refs URI from an API refs object
   */
  this.getRefsUri = function(refsObj)
  {
    var retVal = null ;
    // Return the value of the first refs key found
    for(var key in refsObj)
    {
      retVal = refsObj[key] ;
      // Clean up the URI a little
      // - remove terminal "?" if present.
      retVal = retVal.trim().replace(/\?$/, "") ;
      break ;
    }
    return retVal ;
  } ;

  /**
   * Get the refs URI from an API refs object
   */
  this.getRefsHost = function(refsUri)
  {
    var retVal = '' ;
    if(refsUri)
    {
      match = refsUri.match(/:\/\/([^\/]+)/) ;
      retVal = match[1] ;
    }
    return retVal ;
  } ;

  /**
  * Get the resource count path for an entity
  * Get for example, /REST/v1/grp/{grp}/hubs/count? from /REST/v1/grp/{grp}/hubs? 
  */
  
  this.getRsrcCountPath = function(refsUri)
  {
    var retVal = '';
    if(refsUri)
    {
      retVal = refsUri.replace('?', '/count?');
    }
    return retVal ; 
  } ;
   

  /**
   * Try to get the name of the entity in a REST API URL
   * This function is also like a basename() function in some languages
   */
  this.getEntityName = function(uri)
  {
    var retVal = '' ;
    if(uri)
    {
      qsIndex = uri.indexOf('?') ;
      partialUri = (qsIndex >= 0 ? uri.slice(0, qsIndex) : uri) ;
      match = partialUri.match(/\/([^\/]+)$/)
      if(match)
      {
        retVal = match[1] ;
      }
    }
    return retVal ;
  }

  /* Construct child URI from parent URI
   * @param [String] parentUri must end in "s" indicating children which are
   *   assumed to be accessible by the API by removing the "s", adding a slash,
   *   and inserting the child name
   * @param [String] selfName the name of the child
   * @return [String] the URI to self
   * @todo gbKey ?
   */
  this.getRefsUriFromParent = function(parentUri, selfName) 
  {
    var encSelfName = encodeURIComponent(selfName) ; 
    var retVal = '';
    var qmIndex = parentUri.indexOf("?") ;
    parentUri = (qmIndex >= 0 ? parentUri.slice(0, qmIndex) : parentUri) ;
    var match = parentUri.match(/(.+)s\??$/) ;
    if(match)
    {
      retVal = match[1] + '/' + encSelfName + '?';
    }
    return retVal
  }

  /**
   * Transform refsUri to optionally add a "detailed" query parameter and/or a "connect" query parameter
   *   for use in the details panel for a node associated with the refsUri
   * [+useDetailed+]  bool: default is false, if true, the path that is returned will contain the URL param detailed=true
   */
  this.getDetailsPath = function(refsUri, useDetailed, detailedValue, noConnect)
  {
    var detailsPath = refsUri ;
    /* and append the details=true parameter if specified */
    if(useDetailed)
    {
      /**
       * First, determine if we've been given a value to use for "detailed" parameter or whether we have to add it ourselves
       */
      var detailVal = "true" ;
      if(detailedValue) // then looks like we were given a value; use it, as string
      {
        detailVal = "" + detailedValue ;
      }
      /**
       * If detailed=anything already exists in the path, it will be overwritten
       */
      if(detailsPath.match(/[?&]detailed=/))
      {
        detailsPath = detailsPath.replace(/([?&]detailed=)\w+/, ("$1" + detailVal) ) ;
      }
      else // add detailed parameter to uri
      {
        paramStartPos = detailsPath.indexOf('?') ;
        if(paramStartPos > 0)
        {
          /* Already has params don't need to prepend '?' */
          if((paramStartPos + 1) == detailsPath.length)
          {
            detailsPath += ('detailed=' + detailVal) ;
          }
          else
          {
            detailsPath += ('&detailed=' + detailVal) ;
          }
        }
        else
        {
          detailsPath += ('?detailed=' + detailVal) ;
        }
      }
    }
    /**
     * Finally, if noConnect is true, strip any existing "connect=XXXX" and then put in "connect=no"
     */
    if(noConnect)
    {
      detailsPath = detailsPath.replace(/([?&]connect=)\w+&?/, '' ) ;
      detailsPath += "&connect=no" ;
    }
    return detailsPath ;
  } ;

  /**
   * Convert grp details path from /REST/v1/grp/{grp} to /REST/v1/grp/{grp}/usr/{usr}/role
   */
  this.getRolePath = function(dbDetailsPath) {
    var uriArr = dbDetailsPath.match(/.+\/REST\/v1\/grp\/[^\/?\s]+/) ;
    var roleDetailsPath = uriArr[0] + '/usr/' + userLogin + '/role' ;
    return roleDetailsPath ;
  }

  /**
   * Returns the gbKey kvp that will be appended to refUri's if the db is 'public unlocked'
   */
  this.getGbKeyParamFromNode = function(dbNode) {
    return this.getGbKeyParam(dbNode.attributes.gbKey) ;
  }
  /**
   * Returns the gbKey kvp that will be appended to refUri's if the db is 'public unlocked'
   */
  this.getGbKeyParam = function(gbKey) {
    var gbKeyParam = '' ;
    if(gbKey != undefined)
    {
      gbKeyParam = 'gbKey=' + gbKey ;
    }
    return gbKeyParam ;
  }

  /**
   * Returns the css class suffix for 'public unlocked' resources
   */
  this.getPublicStyle = function(dbNodeAttrs) {
    var pubCls = '';
    if(dbNodeAttrs.gbKey != undefined || this.isNodePublic(dbNodeAttrs))
    {
      pubCls = 'wbPublicResource' ;
    }
    return pubCls ;
  }

  /* Create a node attributes aka node config object based on information from the URL
   *   that is to be the refsUri for the node, its type (which @todo can be inferred from the URL)
   *   and its parentNode
   * @todo will want to change how the public style is applied based on the parent in the near future
   */
  this.defineNodeAttrs = function(refsUri, rsrcType, parentNodeOrAttrs)
  {
    var nodeName = this.getEntityName(refsUri) ;
    var nodeAttrs = {} ;
    nodeAttrs.name = decodeURIComponent(nodeName) ;
    nodeAttrs.text = decodeURIComponent(nodeName) ;
    nodeAttrs.rsrcType = rsrcType ; 
    nodeAttrs.iconCls = rsrcTypeToIconClass[rsrcType] ;
    var qsIndex = refsUri.indexOf("?") ;
    if(qsIndex >= 0) {
      nodeAttrs.refsUri = refsUri ;
    }
    else {
      nodeAttrs.refsUri = refsUri + "?"
    }
    nodeAttrs.detailsPath = this.getDetailsPath(nodeAttrs.refsUri, true) ;
    nodeAttrs.rsrcHost = this.getRefsHost(nodeAttrs.refsUri) ;
    // if parent is public, child is public (this will change) @todo
    if(parentNodeOrAttrs != undefined) {
      if(this.isNodePublic(parentNodeOrAttrs)) {
        this.setPublicStyle(nodeAttrs) ;
      }
    }
    return nodeAttrs ;
  } ;

  this.getNodeAttrs = function(nodeOrAttrs) {
    var nodeAttrs = null ;
    if(nodeOrAttrs.attributes == undefined) {
      nodeAttrs = nodeOrAttrs ;
    }
    else {
      nodeAttrs = nodeOrAttrs.attributes ;
    }
    return nodeAttrs ;
  } ;

  this.isNodePublic = function(nodeOrAttrs) {
    var nodeAttrs = this.getNodeAttrs(nodeOrAttrs) ;
    var retVal = false ;
    if(nodeAttrs.cls != undefined) {
      if(nodeAttrs.cls.indexOf("wbPublicResource") >= 0) {
        retVal = true ;
      }
    }
    return retVal ;
  }

  /* Add to the class of a node or its node attributes config
   * @param [Object] nodeOrAttrs the Ext JS node object or the config used to define it
   * @param [String] cls the class to add to the object
   */
  this.setNodeCls = function(nodeOrAttrs, cls) {
    var attrs = null ;
    if(nodeOrAttrs.attributes == undefined) {
      // then nodeOrAttrs is attrs
      attrs = nodeOrAttrs ;
    }
    else {
      // then nodeOrAttrs is a node
      nodeOrAttrs.ui.addClass(cls) ;
      attrs = nodeOrAttrs.attributes ;
    }

    if(attrs.cls != undefined) {
      if(attrs.cls.indexOf(cls) < 0) {
        attrs.cls += (' ' + cls) ;
      }
      // otherwise attrs has the class
    }
    else {
      // attrs has no class make it add ours
      attrs.cls = cls ;
    }
    return attrs.cls ;
  } ;

  /* Set the style of a node or its config to be public
   * @param [Object] nodeOrAttrs either an Ext JS node already in the tree or its config object
   *   defined so that it can be added to the tree
   */
  this.setPublicStyle = function(nodeOrAttrs) {
    this.setNodeCls(nodeOrAttrs, "wbPublicResource") ;
  } ;

  this.setChildrenPublicStyle = function(nodeOrAttrs) {
    var children = null ;
    if(nodeOrAttrs.attributes == undefined) {
      children = nodeOrAttrs.children ;
    }
    else {
      children = nodeOrAttrs.attributes.children ;
    }
    if(children != undefined) {
      for(var ii=0; ii<children.length; ii++) {
        this.setPublicStyle(children[ii]) ;
      }
    }
  } ;

  /* Define a function that can be used in the {listeners: { 'dblclick': { fn: dblclickHandler }}}
   *   config for AsyncTreeNodes ; this allows even nodes with explictly defined children
   *   to be refreshed on double click (as long as they have a rsrcPath to do the refreshing)
   * @param [Object] node the Ext JS AsyncTreeNode this event is fired for
   * @note a similar function is defined in ajax.js */
  this.dblclickHandler = function(node) {
    if(!this.leaf) {
      Workbench.mainTreeFilter.clear();
      // force refresh of even statically added children if a rsrcPath is defined to do the refresh
      if(this.attributes.rsrcPath != undefined) {
        delete this.attributes.children ;
      }
      this.reload();
    }
  } ;
} ;

/** *******************************************************************
 * HOST-RELATED
 * ****************************************************************** */
HostNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['Refs'] ;
  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS) ;
    hostName = node.attributes.text ;
    loader.addDataToGrid([["Host Name", hostName]]);
  } ;

  /* Get the URL for a group that belongs to the host */
  this.getGrpUri = function(hostName, grpName) {
    return 'http://'+hostName+'/REST/v1/grp/'+encodeURIComponent(grpName) ;
  }

  /**
   * A response from a grps request will contain an array of grp resources.
   * Each group will contain a dbs resource and a prjs resource.
   */
  this.translateResponseForNodes = function(restData, hostNode)
  {
    var grpNodeAttrsList = new Array ;

    // Can we just skip the special "Public" group specifically?
    var newRestData = new Array;
    for(var ii=0; ii<restData.length; ii++)
    {
      if(restData[ii].text != "Public")
      {
        newRestData.push(restData[ii]) ;
      }
    }
    restData = newRestData ;

    for(var ii=0; ii<restData.length; ii++)
    {
      /* Set the attributes for a grp node 
       * including request details for retrieving the database names, project names, and hub names
       * that belong to the group */
      var hostName = hostNode.attributes.text ;
      var grpName = restData[ii].text ;
      var encGrpName = encodeURIComponent(grpName) ;
      var grpUri = this.getGrpUri(hostNode.attributes.name, grpName)
      var grpNodeAttrs = this.defineNodeAttrs(grpUri, "grp", hostNode) ;
      grpNodeAttrs.rsrcPath = 'http://'+hostName+'/REST/v1/grp/'+encGrpName+'?detailed=immediates' ;
      grpNodeAttrs.detailsPath = this.getDetailsPath(grpNodeAttrs.refsUri, true) ;

      grpNodeAttrsList.push(grpNodeAttrs) ;
    }
    return grpNodeAttrsList ;
  }
}
HostNodeHelper.prototype = new NodeHelper() ;

HostsNodeHelper = function()
{
  this.iconCls = 'wbGrpsTreeNode' ;
  /**
   * A response from a hosts request will contain an array of text entities with the hosts we know for the user.
   * The first host will be "this" one (the local one, which is providing the Workbench) and others will be known remote ones for the user.
   * First one should be expanded.
   * The expansion should show all the groups they have access to at the host...
   * Each group will contain a dbs resource and a prjs resource.
   */
  this.translateResponseForNodes = function(restData)
  {
    /* Each host: */
    for(var ii=0; ii<restData.length; ii++)
    {
      /* Set the attributes for a grp node */
      var serverName = restData[ii].text ;
      var encHostName = encodeURIComponent(serverName) ;
      restData[ii].text = serverName ;
      restData[ii].name = serverName ;
      restData[ii].rsrcType = 'host' ;
      restData[ii].iconCls = 'wbHostTreeNode' ;
      restData[ii].rsrcHost = serverName ;
      restData[ii].rsrcPath = 'http://' + serverName + '/REST/v1/usr/' + encodeURIComponent(userLogin) + '/grps?connect=yes&includePublicContent=true&requireUnlockedPublicDBs=true' ;
      restData[ii].refsUri = 'http://' + serverName + '/REST/v1/usr/' + encodeURIComponent(userLogin) + '/grps?' ;
      restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
      restData[ii].expanded = (ii == 0) ; /* Only expand the first server (the local one) */
    }
    return restData ;
  }
}
HostsNodeHelper.prototype = new NodeHelper();


/** *******************************************************************
 * GROUP-RELATED
 * ****************************************************************** */
GrpNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['Refs', 'PermissionBits'] ;
  this.DETAILS_ATTR_ORDER = ['Name', 'Description']
  this.groupDisplayCallback = function(transport)
  {
    this.replaceRespToGrid(transport) ;
    var roleDetailsPath = this.nodeHelper.getRolePath(this.nodeHelper.node.attributes.detailsPath) ;
    var loader = new DetailsLoader(roleDetailsPath, this.nodeHelper.DETAILS_HIDDEN_ATTRS) ;
    loader.loadFromAPI(null, false) ;
  } ;
  /* perform the default functionality for getting details but also include a request for the users role in the group */
  this.updateDetails = function(node)
  {
    /* Make request and load to details */
    this.loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    // Save this nodeHelper & current info, so it's all available in the loader when he calls the custom callback
    this.node = node ;
    this.loader.nodeHelper = this ;
    this.loader.loadFromAPI(this.groupDisplayCallback) ;
  } ;

  /* A bit different from other nodes: restData is a response from /grp/{grp}?detailed=immediates
   * rather than some child names as an array; we also will setup the grandchildren so that
   * no additional request is made when our child nodes are expanded */
  this.translateResponseForNodes = function(restData, grpNode)
  {
    var grpChildrenToAppend = new Array ;
    var host = grpNode.attributes.rsrcHost ;
    var encGrpName = encodeURIComponent(grpNode.attributes.text) ;
    var listenersConfig = { 'dblclick': { fn: this.dblclickHandler } } ;
    if(restData.isPublic) {
      // style this node as public and every child node beneath it
      this.setPublicStyle(grpNode) ;
    }

    // display an error message if the underlying API server does not provided the expected response format
    if(restData.children == undefined || restData.children.dbs == undefined || restData.children.kbs == undefined || 
       restData.children.prjs == undefined || restData.children.hubs == undefined) {
       error = {
         type: "GenboreeError",
         message: "The Genboree API server at " + host + " is outdated and incompatible with " +
                  "this version of the Genboree Workbench. Please contact the administrator " +
                  "there before attempting further cross-host activity or log in at " + host + " if you are not already logged in there.",
         windowTitle: "Outdated API Server"
       } ;
       throw error ;
     }

    if(restData.children.dbs.length > 0)
    {
      // then we have databases to add, organize them under a "Dbs" node
      var dbsUri = 'http://'+host+'/REST/v1/grp/'+encGrpName+'/dbs?' ;
      var dbsNodeAttrs = {
        iconCls: rsrcTypeToIconClass['dbs'],
        text: 'Databases',
        rsrcType: 'dbs',
        refsUri: dbsUri,
        rsrcPath: dbsUri,
        children: new Array,
        listeners: listenersConfig
      }
      if(restData.isPublic) {
        this.setPublicStyle(dbsNodeAttrs) ;
      }

      // add each db node as a child under this dbs node
      var dbsNodeHelper = NodeHelperSelector.getNodeHelperForType(dbsNodeAttrs.rsrcType) ;
      for(var ii=0; ii<restData.children.dbs.length; ii++)
      {
        var dbName = restData.children.dbs[ii] ;
        var dbUrl = this.getRefsUriFromParent(dbsNodeAttrs.refsUri, dbName) ;
        var dbNodeAttrs = dbsNodeHelper.defineNodeAttrs(dbUrl, "db", dbsNodeAttrs) ;
        dbNodeAttrs.children = dbsNodeHelper.defineDbChildren(dbNodeAttrs, dbUrl) ;
        dbsNodeAttrs.children.push(dbNodeAttrs) ;
      }

      // register the "Dbs" node as a child of the "Grp" node
      grpChildrenToAppend.push(dbsNodeAttrs) ;
    }

    if(restData.children.prjs.length > 0)
    {
      // then we have projects to add, organize them under a "Prjs" node
      var prjsUri = 'http://'+host+'/REST/v1/grp/'+encGrpName+'/prjs?' ;
      var prjsNodeAttrs = {
        iconCls: rsrcTypeToIconClass['prjs'],
        text: 'Projects',
        rsrcType: 'prjs',
        refsUri: prjsUri,
        rsrcPath: prjsUri,
        children: new Array,
        listeners: listenersConfig
      }
      if(restData.isPublic) {
        this.setPublicStyle(prjsNodeAttrs) ;
      }

      // add each "Prj" node under this "Prjs" node
      var prjsNodeHelper = NodeHelperSelector.getNodeHelperForType(prjsNodeAttrs.rsrcType) ;
      for(var ii=0; ii<restData.children.prjs.length; ii++)
      {
        var prjName = restData.children.prjs[ii] ;
        var prjUrl = this.getRefsUriFromParent(prjsNodeAttrs.refsUri, prjName) ;
        var prjNodeAttrs = prjsNodeHelper.defineNodeAttrs(prjUrl, "prj", prjsNodeAttrs) ;
        // each project may contain sub projects, define the URL to retrieve them
        prjNodeAttrs.rsrcPath = prjsNodeHelper.getSubProjectsUri(prjUrl) ;
        prjsNodeAttrs.children.push(prjNodeAttrs) ;
      }

      // register the "Prjs" node as a child of the "Grp" node
      grpChildrenToAppend.push(prjsNodeAttrs) ;
    }

    if(restData.children.hubs.length > 0)
    {
      // then we have hubs to add, organize them under a "Hubs" node
      var hubsUri = 'http://'+host+'/REST/v1/grp/'+encGrpName+'/hubs?';
      var hubsNodeAttrs = {
        iconCls: rsrcTypeToIconClass['hubs'],
        text: 'Hubs',
        rsrcType: 'hubs',
        refsUri: hubsUri,
        rsrcPath: hubsUri,
        children: new Array,
        listeners: listenersConfig
      }
      if(restData.isPublic) {
        this.setPublicStyle(hubsNodeAttrs) ;
      }

      // add each "Hub" node under this "Hubs" node
      var hubsNodeHelper = new HubsNodeHelper() ;
      for(var ii=0; ii<restData.children.hubs.length; ii++)
      {
        var hubName = restData.children.hubs[ii] ;
        var hubUrl = this.getRefsUriFromParent(hubsNodeAttrs.refsUri, hubName) ;
        var hubNodeAttrs = this.defineNodeAttrs(hubUrl, "hub", hubsNodeAttrs) ;
        // setup children of "Hub" node
        hubsNodeHelper.setHubChildren(hubNodeAttrs) ;
        // register "Hub" nodes as children of "Hubs" node
        hubsNodeAttrs.children.push(hubNodeAttrs) ;
      }

      // register the "Hubs" node as a child of the "Grp" node
      grpChildrenToAppend.push(hubsNodeAttrs) ;
    }

    if(restData.children.kbs.length > 0) {
      // then we have kbs to add, organize them under a "Kbs" node
      var kbsUri = 'http://'+host+'/REST/v1/grp/'+encGrpName+'/kbs?detailed=false' ;
      var kbsNodeAttrs = {
        iconCls: rsrcTypeToIconClass['kbs'],
        text: 'Knowledge Bases',
        rsrcType: 'kbs',
        refsUri: kbsUri,
        rsrcPath: kbsUri,
        children: new Array,
        listeners: listenersConfig
      };
      if(restData.isPublic) {
        this.setPublicStyle(kbsNodeAttrs) ;
      }

      var kbsNodeHelper = new KbsNodeHelper() ;
      for(var ii=0; ii<restData.children.kbs.length; ii++)
      {
        var kbName = restData.children.kbs[ii] ;
        var kbUrl = this.getRefsUriFromParent(kbsNodeAttrs.refsUri, kbName) ;
        var kbNodeAttrs = this.defineNodeAttrs(kbUrl, "kb", kbsNodeAttrs) ;
        // setup children of "Kb" node
        kbsNodeHelper.setKbChildren(kbNodeAttrs) ;
        delete kbNodeAttrs.detailsPath ; // override request for details panel
        // register "Kb" nodes as children of "Kbs" node
        kbsNodeAttrs.children.push(kbNodeAttrs) ;
      }

      // register the "Kbs" node as a child of the "Grp" node
      grpChildrenToAppend.push(kbsNodeAttrs) ; 
    }

    if(restData.children.redminePrjs && restData.children.redminePrjs.length > 0) {
      // then we have redminePrjs to add, organize them under a "Redmine Projects" node
      var redminePrjsUri = 'http://'+host+'/REST/v1/grp/'+encGrpName+'/redminePrjs?detailed=false';
      var redminePrjsNodeAttrs = {
        iconCls: rsrcTypeToIconClass['redminePrjs'],
        text: "Redmine Projects",
        rsrcType: "redminePrjs",
        refsUri: redminePrjsUri,
        rsrcPath: redminePrjsUri,
        children: new Array,
        listeners: listenersConfig
      };
      if(restData.isPublic) {
        this.setPublicStyle(redminePrjNodeAttrs);
      }

      // add each redmine project underneath the redmine projects node
      var redminePrjsNodeHelper = new RedminePrjsNodeHelper() ; // @todo
      for(var ii=0; ii<restData.children.redminePrjs.length; ii++) {
        var redminePrjName = restData.children.redminePrjs[ii];
        var redminePrjUrl = this.getRefsUriFromParent(redminePrjsNodeAttrs.refsUri, redminePrjName) ;
        var redminePrjNodeAttrs = this.defineNodeAttrs(redminePrjUrl, "redminePrj", redminePrjsNodeAttrs);
        redminePrjNodeAttrs.leaf = true;
        redminePrjsNodeAttrs.children.push(redminePrjNodeAttrs);
      }

      // register the redmine projects node as a child of the group node
      grpChildrenToAppend.push(redminePrjsNodeAttrs) ;
    }

    if(restData.children.dbs.length == 0 && restData.children.prjs.length == 0 && restData.children.hubs.length == 0 && restData.children.kbs.length == 0 && restData.children.redminePrjs.length == 0)
    {
      // then this group is empty, add the empty leaf node
      grpChildrenToAppend.push(this.EMPTY_LEAF) ;
    }

    return grpChildrenToAppend ;
  }
}
GrpNodeHelper.prototype = new NodeHelper() ;

GrpsNodeHelper = function()
{
  this.iconCls = 'wbGrpsTreeNode' ;
  /**
   * A response from a grps request will contain an array of grp resources.
   * Each group will contain a dbs resource and a prjs resource.
   *
   */
  this.translateResponseForNodes = function(restData) {
    for(var ii=0; ii<restData.length; ii++) {
      /* Set the attributes for a grp node */
      var grpName = restData[ii].text ;
      var encGrpName = encodeURIComponent(grpName) ;
      restData[ii].name = grpName ;
      restData[ii].rsrcType = 'grp' ;
      restData[ii].iconCls = 'wbGrpTreeNode' ;
      restData[ii].refsUri = this.getRefsUri(restData[ii].refs) ;
      restData[ii].rsrcHost = this.getRefsHost(restData[ii].refsUri) ;
      restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
      restData[ii].children =
      [
        {
          iconCls: 'wbDbsTreeNode',
          text: 'Databases',
          rsrcType: 'dbs',
          rsrcPath: 'http://'+restData[ii].rsrcHost+'/REST/v1/grp/'+encGrpName+'/dbs?detailed=true',
          refsUri: 'http://'+restData[ii].rsrcHost+'/REST/v1/grp/'+encGrpName+'/dbs?'
        },
        {
          iconCls: 'wbPrjsTreeNode',
          text: 'Projects',
          rsrcType: 'prjs',
          rsrcPath: 'http://'+restData[ii].rsrcHost+'/REST/v1/grp/'+encGrpName+'/prjs?detailed=true',
          refsUri: 'http://'+restData[ii].rsrcHost+'/REST/v1/grp/'+encGrpName+'/prjs?'
        }
      ]
    }
    return restData ;
  }
}
GrpsNodeHelper.prototype = new NodeHelper();


/** *******************************************************************
 * DATABASE-RELATED
 * ****************************************************************** */
DbNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ["Refs", "PermissionBits"] ;
  this.DETAILS_ATTR_ORDER = ['Name', 'Description', 'Species', 'Version'] ;
  this.DETAILS_ATTR_FORMATTERS =
  {
    // Manually fill the grid since we want control over the entrypoints:
    gbFullDetailsFormatter: function(respDataObj, detailsPath, loaderObj)
    {
      /* Collect key-value pairs in 2-col array to hand off to the grid */
      if(respDataObj)
      {
        // Get Role from the details grid (only row currently there)
        var detailsStore = Ext.ComponentMgr.get('wbDetailsGrid').store ;
        var rowModel = detailsStore.getAt(0) ;
        var roleVal = null ;
        if(rowModel != null && rowModel != undefined)
        {
          roleVal = rowModel.get("value") ;
        }
        var retVal = [] ;
        var grpName = ApiUriHelper.extractRsrcName(detailsPath, 'grp') ;
        retVal.push(['Group', grpName]) ;
        retVal.push(['Role', roleVal]) ;
        for(var ii=0; ii<loaderObj.attrDisplayOrder.length; ii++)
        {
          retVal.push([loaderObj.attrDisplayOrder[ii], respDataObj[loaderObj.attrDisplayOrder[ii].toLowerCase()]]) ;
        }
        // Add gbKey. The loop above will not add gbKey because it lowercases all characters
        retVal.push(['gbKey', respDataObj['gbKey']]) ;
        if(respDataObj['public'] == true)
        {
          retVal.push(['Public', 'Yes']) ;
        }
        else
        {
          retVal.push(['Public', 'No']) ;
        }
        retVal.push(['Entrypoints:']) ;
        var eps = respDataObj['entrypoints']['entrypoints'] ;
        for(var ii=0 ; ii < eps.length; ii++)
        {
          if(ii < 500) // Only display the first 500 entrypoints
          {
            retVal.push( [eps[ii]['name'], eps[ii]['length'] ] ) ;
          }
          else
          {
            retVal.push( [eps.length - 500 + ' more entrypoints...'] ) ;
            break ;
          }
        }
      }
      return retVal ; // table of attr<->value not just one like usual
    }
  } ;

  // This is a CUSTOM success function for the Role API call. Oonce that returns, we THEN do the DB DETAILS call in here.
  // - NOTE: this is a callback called in the context of a DetailsLoader object. Therefore "this" is the DetailsLoader, not this DbNodeHelper instance.
  this.customDetailsDisplayCallback = function(transport)
  {
    // First, need to get loader to display the Role it just retrieved.
    this.replaceRespToGrid(transport) ;
    // Now "Role" is the only row in the details grid. The gbFullDetailsFormatter above will extract it and do whatever with it.
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(this.nodeHelper.node.attributes.detailsPath, this.nodeHelper.DETAILS_HIDDEN_ATTRS, this.nodeHelper.DETAILS_ATTR_ORDER, this.nodeHelper.DETAILS_ATTR_FORMATTERS) ;
    // Make the loader replace the current contents of details panel (should just be Role) with full contents.
    loader.loadFromAPI(null, true) ;
  } ;
  /* perform the default functionality for getting details but also include a request for the users role in the group */
  this.updateDetails = function(node)
  {

    /* Transform grp detailsPath into roles Path */
    var roleDetailsPath = this.getRolePath(node.attributes.detailsPath) ;
    /* Make request and load to details */
    // Here we save the loader since it will be needed in the this.customDetailsDisplay function
    this.loader = new DetailsLoader(roleDetailsPath, this.DETAILS_HIDDEN_ATTRS) ;
    // Save this nodeHelper & current info, so it's all available in the loader when he calls the custom callback
    this.node = node ;
    this.loader.nodeHelper = this ;
    this.loader.loadFromAPI(this.customDetailsDisplayCallback) ;
  } ;
}
DbNodeHelper.prototype = new NodeHelper() ;

DbsNodeHelper = function()
{
  /* Interface:
   * @param [Array<Object>] restData response from request on /grp/{grp}/dbs
   * @param [Object] dbsNode the Ext JS node object for the database
   * @return [Array<Object>] list of Ext JS node config objects for database nodes
   */
  this.translateResponseForNodes = function(restData, dbsNode) {
    var dbNodeAttrsList = new Array ;
    if(restData.length > 0)
    {
      for(var ii=0; ii<restData.length; ii++) {
        var dbName = restData[ii].text ;
        var dbUrl = this.getRefsUriFromParent(dbsNode.attributes.refsUri, dbName) ;
        var gbKeyParam = this.getGbKeyParam(restData[ii].gbKey) ;
        var dbNodeAttrs = this.defineNodeAttrs(dbUrl, "db", dbsNode) ;
        dbNodeAttrs.detailsPath = this.getDetailsPath(dbNodeAttrs.refsUri, true) ;
        dbNodeAttrs.children = this.defineDbChildren(dbsNode, dbUrl, gbKeyParam) ;
        dbNodeAttrsList.push(dbNodeAttrs) ;
      }
    }
    else
    {
      dbNodeAttrsList.push(this.EMPTY_LEAF);
    }
    return dbNodeAttrsList ;
  } ;


  /* Explicitly define child nodes (rather than allowing an async request to populate them 
   * @param [Object] dbNodeAttrs either the JSON config object that will be used to create the dbNode
   *   or after dbNode has been defined by Ext JS, dbNode.attributes -- must be an object with a
   *   "gbKey" key
   * @param [String] baseUrl the URL for the database for which child URLs will be based
   * @param [String] gbKeyParam a key=value string for gbKey used for icon styling; @see NodeHelper#getGbKeyParam
   * @return [Array] the Ext.tree.AsyncTreeNode configs to use as children for the dbNode
   */
  this.defineDbChildren = function(dbNodeAttrs, baseUrl, gbKeyParam) 
  {
    if(gbKeyParam == null) {
      gbKeyParam = '';
    }
    var qmIndex = baseUrl.indexOf("?") ;
    if(qmIndex >= 0) {
      baseUrl = baseUrl.slice(0, qmIndex) ;
    }
    var rsrcHost = this.getRefsHost(baseUrl) ;
    var children = [
      //{
      //  text: 'All Annotations in Database',
      //  leaf: true,
      //  rsrcType: 'annos',
      //  rsrcHost: rsrcHost,
      //  rsrcPath: baseUrl+'/annos',
      //  refsUri: baseUrl+'/annos?' + gbKeyParam,
      //  cls: this.getPublicStyle(dbNodeAttrs)
      //},
      {
        text: 'Tracks',
        iconCls: 'wbTracksTreeNode',
        rsrcType: 'trks',
        rsrcHost: rsrcHost,
        rsrcPath: baseUrl+'/classes?connect=no',
        refsUri: baseUrl+'/trks?' + gbKeyParam,
        cls: this.getPublicStyle(dbNodeAttrs)
      },
      {
        text: 'Lists & Selections',
        iconCls: 'wbListsTreeNode',
        rsrcType: 'lists',
        rsrcHost: rsrcHost,
        rsrcPath: baseUrl+'/entityLists/types',
        refsUri: baseUrl+'/entityLists/types?' + gbKeyParam,
        cls: this.getPublicStyle(dbNodeAttrs)
      },
      {
        text: 'SampleSets',
        iconCls: 'wbSampleSetsTreeNode',
        rsrcType: 'sampleSets',
        rsrcHost: rsrcHost,
        rsrcPath: baseUrl+'/sampleSets',
        refsUri: baseUrl+'/sampleSets?' + gbKeyParam,
        cls: this.getPublicStyle(dbNodeAttrs)
      },
      {
        text: 'Samples',
        iconCls: 'wbSamplesTreeNode',
        rsrcType: 'bioSamples',
        rsrcHost: rsrcHost,
        rsrcPath: baseUrl+'/bioSamples',
        refsUri: baseUrl+'/bioSamples?' + gbKeyParam,
        cls: this.getPublicStyle(dbNodeAttrs)
      },
      {
        text: 'Files',
        iconCls: 'wbFilesTreeNode',
        rsrcType: 'files',
        rsrcHost: rsrcHost,
        rsrcPath: baseUrl+'/files?detailed=false&connect=false&depth=immediate',
        refsUri: baseUrl+'/files?detailed=false&connect=false&' + gbKeyParam + '&depth=immediate',
        cls: this.getPublicStyle(dbNodeAttrs)
      }//,
      //{
      //  text: 'Queries',
      //  iconCls: 'wbQueriesTreeNode',
      //  rsrcType: 'queries',
      //  rsrcHost: rsrcHost,
      //  rsrcPath: baseUrl+'/queries?connect=true',
      //  refsUri: baseUrl+'/queries?' + gbKeyParam,
      //  cls: this.getPublicStyle(dbNodeAttrs)
      //}
    ]

    // make children public if db is public
    if(this.isNodePublic(dbNodeAttrs)) {
      for(var ii=0; ii<children.length; ii++) {
        this.setPublicStyle(children[ii]) ;
      }
    }

    return children ;
  }
}
DbsNodeHelper.prototype = new NodeHelper() ;

/** **************************************************
 * KB-RELATED
 * ************************************************** */
KbsNodeHelper = function() {

  /* KB-related resources return "property-oriented" JSON rather than simple AVPs for their details;
   * handle "property-oriented" JSON for display in the details panel
   */
  this.updateDetails = function(node) {
    // @todo once kb-related nodes have metadata worth displaying, update this
  } ; 

  /* Get a URL for the collections that belong to a KB */
  this.getCollectionsUri = function(kbUri) { 
    var qmIndex = kbUri.indexOf("?") ;
    kbUri = (qmIndex >= 0 ? kbUri.slice(0, qmIndex) : kbUri) ;
    return kbUri + "/colls" ;
  }

  /* Get a URL for the transforms that belong to a KB */
  this.getTransformsUri = function(kbUri) {
    var qmIndex = kbUri.indexOf("?") ;
    kbUri = (qmIndex >= 0 ? kbUri.slice(0, qmIndex) : kbUri) ;
    return kbUri + "/trRulesDocs" ;
  }

  /* Set "children" attribute for kbNode 
   * @param [Object] kbNodeAttrs attributes for a kb node
   */
  this.setKbChildren = function(kbNodeAttrs) {
    var collsUri = this.getCollectionsUri(kbNodeAttrs.refsUri) ;
    var transformsUri = this.getTransformsUri(kbNodeAttrs.refsUri) ;
    kbNodeAttrs.children = [
      {
        iconCls: rsrcTypeToIconClass['colls'],
        text: 'Collections',
        rsrcType: 'colls',
        refsUri: collsUri,
        rsrcPath: collsUri
      },
      {
        iconCls: rsrcTypeToIconClass['trRulesDocs'],
        text: "Transforms",
        rsrcType: "trRulesDocs",
        refsUri: transformsUri,
        rsrcPath: transformsUri
      }
    ]
  }

  /* Interface:
   * @param [Array<Object>] restData response from request on /kbs 
   * @param [Object] kbsNode the node for the Kbs that was expanded
   * @return [Array<Object>] list of kb node attribute objects to add to the tree
   */
  this.translateResponseForNodes = function(restData, kbsNode) {
    var kbNodeAttrsList = new Array ;
    if(restData.length > 0) {
      for(var ii=0; ii<restData.length; ii++) {
        var kbName = restData[ii].text.value ;
        var kbUrl = this.getRefsUriFromParent(kbsNode.attributes.refsUri, kbName) ;
        var kbNodeAttrs = this.defineNodeAttrs(kbUrl, "kb", kbsNode) ; 
        delete kbNodeAttrs.detailsPath ; // override request for details panel
        this.setKbChildren(kbNodeAttrs) ;
        kbNodeAttrsList.push(kbNodeAttrs) ; 
      }
    }
    else {
      kbNodeAttrsList.push(this.EMPTY_LEAF) ;
    }
    return kbNodeAttrsList ;
  }
} ;
KbsNodeHelper.prototype = new NodeHelper() ;

KbNodeHelper = function() {
}
KbNodeHelper.prototype = new KbsNodeHelper ;

CollsNodeHelper = function() {
  /* Interface:
   * @param [Array<Object>] restData response from request on /kb/{kb}/colls
   * @param [Object] collsNode the Ext JS node object for "Collections"
   * @return [Array<Object>] list of Ext JS node config objects to add as collection nodes
   */
  this.translateResponseForNodes = function(restData, collsNode) {
    var collNodeAttrsList = new Array ;
    if(restData.length > 0) {
      for(var ii=0; ii<restData.length; ii++) {
        var collName = restData[ii].text.value ;
        var collUrl = this.getRefsUriFromParent(collsNode.attributes.refsUri, collName) ;
        var collNodeAttrs = this.defineNodeAttrs(collUrl, "coll", collsNode) ;
        delete collNodeAttrs.detailsPath; // override request for details panel
        collNodeAttrs.leaf = true ;
        collNodeAttrsList.push(collNodeAttrs) ;
      }
    }
    else {
      collNodeAttrsList.push(this.EMPTY_LEAF) ;
    }
    return collNodeAttrsList ;
  } ;
} ;
CollsNodeHelper.prototype = new KbsNodeHelper() ; // inherit in particular updateDetails

TransformsNodeHelper = function() {
  /* Interface:
   * @param [Array<Object>] restData response from request on /kb/{kb}/trRulesDocs
   * @param [Object] transformsNode the Ext JS node object for "Transforms"
   * @return [Array<Object>] list of Ext JS node config objects to add as transform nodes
   */
  this.translateResponseForNodes = function(restData, transNode) {
    var tranNodeAttrsList = new Array ;
    if(restData.length > 0) {
      for(var ii=0; ii<restData.length; ii++) {
        var tranName = restData[ii].text.value ;
        var tranUrl = this.getRefsUriFromParent(transNode.attributes.refsUri, tranName) ;
        var tranNodeAttrs = this.defineNodeAttrs(tranUrl, "trRulesDoc", transNode ) ;
        delete tranNodeAttrs.detailsPath ; // override request for details panel
        tranNodeAttrs.leaf = true ;
        tranNodeAttrsList.push(tranNodeAttrs) ;
      }
    }
    else {
      tranNodeAttrsList.push(this.EMPTY_LEAF) ;
    }
    return tranNodeAttrsList ;
  } ;
} ;
TransformsNodeHelper.prototype = new KbsNodeHelper() ; // inherit in particular updateDetails

/** *******************************************************************
 * PROJECT-RELATED
 * ****************************************************************** */
PrjNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ["Refs"] ;
  this.DETAILS_ATTR_FORMATTERS =
  {
    /* */
    text: function(val)
    {
      return ['Name', val] ;
    }
  } ;

  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    loader.loadFromAPI() ;
    grpName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'grp') ;
    prjName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'prj') ;
    encPrjName = encodeURIComponent(prjName)
    loader.addDataToGrid([["View Link", "<a href='/java-bin/project.jsp?projectName="+encPrjName+"' target='_blank'>Link to Project</a>"],["Group", grpName]]);
  } ;

  // Get the subProjects uri associated with a project uri
  this.getSubProjectsUri = function(prjUri) {
    var qmIndex = prjUri.indexOf("?") ;
    prjUri = (qmIndex >= 0 ? prjUri.slice(0, qmIndex) : prjUri) ;
    return prjUri + "/subProjects?" ; 
  }

  /* Get the URI for a subproject associated with a given project
   * @param [String] prjUrl the project to base the subproject URI on
   * @param [String] subProject the name of the subproject (will be encoded)
   * @return [String] the sub project URI
   */
  this.getSubProjectUri = function(prjUri, subProject) {
    var qmIndex = prjUri.indexOf("?") ;
    prjUri = (qmIndex >= 0 ? prjUri.slice(0, qmIndex) : prjUri) ;
    return prjUri + encodeURIComponent("/" + subProject) ; 
  }

  this.translateResponseForNodes = function(restData, prjNode) {
    var subPrjNodeAttrsList = new Array ;
    if(restData.length > 0) {
      for (var ii=0; ii<restData.length; ii++) {
        var prjUrl = this.getSubProjectUri(prjNode.attributes.refsUri, restData[ii].text) ;
        var prjNodeAttrs = this.defineNodeAttrs(prjUrl, "prj", prjNode) ;
        prjNodeAttrs.rsrcPath = this.getSubProjectsUri(prjUrl) ; // that is, sub-sub projects &tc.
        prjNodeAttrs.text = this.getEntityName(prjNodeAttrs.name) // here the name of the resource is different than its text label
        subPrjNodeAttrsList.push(prjNodeAttrs) ;
      }
    }
    else {
      subPrjNodeAttrsList.push(this.EMPTY_LEAF) ;
    }
    return subPrjNodeAttrsList ;
  }
}
PrjNodeHelper.prototype = new NodeHelper() ;

PrjsNodeHelper = function()
{
  /**
   * A response from a prjs request will contain an array of prj resources.
   * Each prj will become a leaf node
   *
   */
  this.translateResponseForNodes = function(restData, prjsNode)
  {
    var prjNodeAttrsList = new Array ;
    if(restData.length > 0)
    {
      for(var ii=0; ii<restData.length; ii++) {
        var prjName = restData[ii].name ;
        var prjUrl = this.getRefsUri(restData[ii].refs) ;
        var prjNodeAttrs = this.defineNodeAttrs(prjUrl, "prj", prjsNode) ;
        prjNodeAttrs.detailsPath = this.getDetailsPath(prjNodeAttrs.refsUri, true) ;
        prjNodeAttrsList.push(prjNodeAttrs) ;
      }
    }
    else
    {
      prjNodeAttrsList.push(this.EMPTY_LEAF);
    }
    return prjNodeAttrsList ;
  } ;

  var prjNodeHelper = new PrjNodeHelper;
  this.getSubProjectsUri = prjNodeHelper.getSubProjectsUri ;

}
PrjsNodeHelper.prototype = new NodeHelper() ;

/** **************************************************
 * Redmine Projects
 * ************************************************** */
RedminePrjsNodeHelper = function() {
  this.translateResponseForNodes = function(restData, redminePrjsNode) {
    var redminePrjNodeAttrsList = new Array ;
    if(restData.length > 0) {
      for(var ii=0; ii<restData.length; ii++) { 
        var redminePrjName = restData[ii].text ;
        var redminePrjUrl = this.getRefsUriFromParent(redminePrjsNode.attributes.refsUri, redminePrjName) ;
        var redminePrjAttrs = this.defineNodeAttrs(redminePrjUrl, "redminePrj", redminePrjsNode)
        redminePrjAttrs.detailsPath = this.getDetailsPath(redminePrjAttrs.refsUri, true) ;
        redminePrjAttrs.leaf = true;
        redminePrjNodeAttrsList.push(redminePrjAttrs) ;
      }
    } else {
      redminePrjNodeAttrsList.push(this.EMPTY_LEAF) ;
    }
    return redminePrjNodeAttrsList ;
  } ;
}
RedminePrjsNodeHelper.prototype = new NodeHelper();

RedminePrjNodeHelper = function() {

  // Override default to provide link to Redmine project Wiki index by title in Details Panel
  // @param [] node
  this.updateDetails = function(node) { 
    console.log(node);
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS, this.DETAILS_LOADER_SETTINGS) ;

    // Add (prepend) to usual loadFromAPI success function so we can make use of the API response
    var successFunction = function(transport) {
      // Add clickable hyperlink to Redmine project Wiki index by title page
      // @todo this results in JSON parse twice
      var respObj = Ext.util.JSON.decode(transport.responseText)
      var redmineWikiUrl = respObj.data.url + "/projects/" + encodeURIComponent(respObj.data.projectId) + "/wiki/index" ;
      loader.addDataToGrid([
        ["View Job Output", "<a href=\"" + redmineWikiUrl + "\" target=\"_blank\">Link to Job Output</a>"]
      ]);

      loader.appendRespToGrid(transport);
    };
    loader.loadFromAPI(successFunction) ;

  }
}
RedminePrjNodeHelper.prototype = new NodeHelper();

/** *******************************************************************
 * HUB-RELATED
 * ****************************************************************** */
HubNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['gbKey'] ;
  this.DETAILS_ATTR_ORDER = ['shortLabel', 'longLabel'] ;
  this.DETAILS_ATTR_FORMATTERS = 
  {
    gbFullDetailsFormatter: function(respDataObj, detailsPath, loaderObj)
    {
      if(respDataObj)
      {
        var retVal = [];
        var grpName = ApiUriHelper.extractRsrcName(detailsPath, 'grp') ;
        retVal.push(['Group', grpName]) ;
        var hubName = respDataObj['name'] ;
        retVal.push(['hubName', hubName]) ;
        for(var ii=0; ii<loaderObj.attrDisplayOrder.length; ii++)
        {
          retVal.push([loaderObj.attrDisplayOrder[ii], respDataObj[loaderObj.attrDisplayOrder[ii]]]) ;
        }
        if(respDataObj['public'] == 1)
        {
          retVal.push(['Public', 'Yes']) ;
        }
        else
        {
          retVal.push(['Public', 'No']) ;
        }
        var email = respDataObj['email'] ;
        retVal.push(['Email', email]);
      }
      return retVal ;
    }
  } ; 
  this.updateDetails = function(node)
  {
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    loader.loadFromAPI() ;
  }
}
HubNodeHelper.prototype = new NodeHelper() ;


HubsNodeHelper = function()
{
  /* Get the genomes URI associated with a hub */
  this.getGenomesUri = function(hubRefsUri) { 
    var qmIndex = hubRefsUri.indexOf("?") ;
    hubRefsUri = (qmIndex >= 0 ? hubRefsUri.slice(0, qmIndex) : hubRefsUri) ;
    return hubRefsUri + "/genomes" ;
  }

  /* Add a genomes node as a child of the hub node */
  this.setHubChildren = function(hubNodeAttrs, gbKeyParam) {
    var genomesUri = this.getGenomesUri(hubNodeAttrs.refsUri) ;
    hubNodeAttrs.children = [
      {
        iconCls: 'wbGenomesTreeNode',
        text: 'Genomes',
        rsrcType: 'genomes',
        rsrcHost: hubNodeAttrs.rsrcHost,
        rsrcPath: genomesUri,
        refsUri: genomesUri
      }
    ] ;
  }

  /**
   * A response from a hubs request will contain an array of hub resources.
   * Each hub will have respective genome resources
   *
   */
  this.translateResponseForNodes = function(restData, hubsNode) {
    var hubNodeAttrsList = new Array ;
    if(restData.length > 0)
    {
      var grpNode = hubsNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      for(var ii=0; ii<restData.length; ii++) {
        var hubName = restData[ii].text ;
        var encHubName = encodeURIComponent(hubName) ;
        var refsUri = this.getRefsUriFromParent(hubsNode.attributes.refsUri, hubName) ;
        var hubNodeAttrs = this.defineNodeAttrs(refsUri, "hub", hubsNode) ;
        hubNodeAttrs.detailsPath = this.getDetailsPath(refsUri, true) ;
        this.setHubChildren(hubNodeAttrs) ;
        hubNodeAttrsList.push(hubNodeAttrs) ;
      }
    }
    else
    {
      hubNodeAttrsList.push(this.EMPTY_LEAF);
    }
    return hubNodeAttrsList
  } ;
}
HubsNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * QUERY-RELATED
 * ****************************************************************** */
QueryNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['Refs', 'UserId'] ;
}
QueryNodeHelper.prototype = new NodeHelper() ;

QueriesNodeHelper = function()
{
  /**
   * A response from a prjs request will contain an array of prj resources.
   * Each prj will become a leaf node
   *
   */
  this.translateResponseForNodes = function(restData, queriesNode) {
    if(restData.length > 0)
    {
      var dbNode = queriesNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++)
      {
        var queryName = restData[ii].text ;
        var encPrjName = encodeURIComponent(queryName) ;
        restData[ii].name = queryName ;
        restData[ii].rsrcType = 'query' ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].iconCls ='wbQueryTreeNode' ;
        restData[ii].refsUri = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam ;
        restData[ii].rsrcHost = this.getRefsHost(restData[ii].refsUri) ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
        restData[ii].leaf = true ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
QueriesNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * FILE-RELATED
 * ****************************************************************** */
FileNodeHelper = function()
{
  /* These attrs were implemented for project files and aren't used in the workbench yet */
  this.DETAILS_HIDDEN_ATTRS = ['Archived', 'AutoArchive', 'Hide', 'gbUploadInProgress' ] ;

  this.DETAILS_ATTR_FORMATTERS =
  {
    /**
     * For "date" respDataObj is a JSON date object
     */
    //date: function(respDataAttr)
    //{
    //  var dateObj = new Date(respDataAttr.s * 1000)  ;
    //  return ['Date', dateObj.toDateString()] ;
    //},
    createdDate: function(respDataAttr)
    {
      // Won't work anymore
      //var dateObj = new Date(respDataAttr.s * 1000)  ;
      //return ['CreatedDate', dateObj.toDateString()] ;
      var dateObj = new Date(respDataAttr) ;
      return ['CreatedDate', dateObj.format('Y/m/d H:i:s')]
    },
    lastModified: function(respDataAttr)
    {
      // Won't work anymore
      //var dateObj = new Date(respDataAttr.s * 1000)  ;
      //return ['LastModified', dateObj.toDateString()] ;
      var dateObj = new Date(respDataAttr) ;
      return ['LastModified', dateObj.format('Y/m/d H:i:s')]
    },
    /**
     * For label, respDataObj is a simple string
     */
    label: function(respDataAttr)
    {
      var label = respDataAttr ;
      return [ [ 'Label', label] ];
    },
    size: function(respDataArr)
    {
      var fileSize = respDataArr ;
      var i = -1;
      var byteUnits = [' kB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB'];
      do {
        fileSize = fileSize / 1024;
        i++;
      } while (fileSize > 1024);
      return ["File Size", Math.max(fileSize, 0.0).toFixed(1) + byteUnits[i]] ;
    },
    /**
     * For "attributes" respDataObj is a ~hash (Object) of attribute names as keys
     * to the value for that attributes.
     */
    attributes: function(respDataAttr)
    {
      /* Collect key-value pairs in 2-col array to hand off to the grid */
      var retVal = [] ;
      var customAttrs = Object.keys(respDataAttr) ;
      for(var ii=0 ; ii < customAttrs.length; ii++)
      {
        var customAttr = customAttrs[ii] ;
        retVal.push( [ customAttr, respDataAttr[customAttr] ] ) ;
      }
      /* Sort the 2-col table, so things appear in a sensible order */
      retVal = retVal.sort( function(aa,bb)
      {
        xx = aa[0].toLowerCase() ;
        yy = bb[0].toLowerCase() ;
        return (xx < yy ? -1 : (xx > yy ? 1 : 0)) ;
      }) ;
      return retVal ; // table of attr<->value not just one like usual
    }
  }

  //this.DETAILS_ATTR_ORDER = [ 'Description', 'FileName', 'Date'] ;
  this.DETAILS_ATTR_ORDER = [ 'Description', 'Name', 'CreatedDate', 'LastModified'] ;
  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    loader.loadFromAPI() ;
    grpName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'grp') ;
    dbName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'db') ;
    loader.addDataToGrid(
      [
        ['Download', '<a onclick="downloadFile(\''+node.attributes.refsUri+'\');return false;" href="#">Click to Download File</a>'],
        ["Group", grpName], ["Database", dbName]
      ]
    );
  } ;
} ;
FileNodeHelper.prototype = new NodeHelper() ;

FilesNodeHelper = function()
{
  /**
   * A response from a files request will contain an array of file resources.
   * Convert the array of files to a directory tree which will then be converted into an ExtJS Tree.
   *
   */
  this.translateResponseForNodes = function(restData, filesNode) {
    var dbNode = filesNode.parentNode ;
    var grpNode = dbNode.parentNode.parentNode ;
    if(restData.length > 0)
    {
      var dirTree = this.constructDirTree(restData, dbNode.attributes.refsUri) ;
      restData = this.convertToExtNodes(dirTree, grpNode, dbNode) ;
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;

  /**
   * Converts an array of files into a tree structure
   *
    [
     {fileName:'subdir1/subdir2/file1'},
     {fileName:'subdir1/file2'}
    ]
   *
   * becomes
   *
    {
      subdir1:
      {
        subdir2:
        {
          file1: 'http://...'
        },
        file2: 'http://...'
      }
    }
   *
   */
  this.constructDirTree = function(restData, dbUri)
  {
    var dirTree = {} ;
    var currNode = null;
    /* For each file */
    for(var ii=0; ii<restData.length; ii++)
    {
      var filePathArr = restData[ii].text.split('/') ;
      currNode = dirTree;
      for(var ff=0; ff<filePathArr.length; ff++)
      {
        /* last part of the path, should be the file */
        if(ff == filePathArr.length-1)
        {
          currNode[filePathArr[ff]] = dbUri.replace(/\??$/, "/file/" +  restData[ii].text) ;
        }
        else
        {
          /* dir, add it if it hasn't been added yet */
          if(currNode[filePathArr[ff]] == undefined)
          {
            currNode[filePathArr[ff]] = {} ;
          }
          currNode = currNode[filePathArr[ff]]
        }
      }
    }
    return dirTree;
  } ;


  /**
   * Recursively converts the object tree nodes into ExtJS tree node configuration objects
   *
    {
      subdir1:
      {
        subdir2:
        {
          file1: 'http://host/REST/...'
        },
        file2: 'http://host/REST/...'
      }
    }
   * becomes
   *
    [
     {
       text: "subdir1",
       leaf: false,
       children:
       [
         {
           text: "subdir2",
           children:
           [
             text: 'file1',
             leaf: true
           ]
         },
         {
           text: 'file2',
           leaf: true
         }
       ]
     }
    ]
   */
  this.convertToExtNodes = function(dirTreeNode, grpNode, dbNode, encDirPath)
  {
    var grpName = grpNode.attributes.name;
    var dbName = dbNode.attributes.name;
    var fileHostName = dbNode.attributes.rsrcHost ;
    var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
    if(encDirPath == undefined)
    {
      encDirPath = '';
    }
    /* Array that will contain the tree nodes (dirs or files) */
    var nodeArr = [] ;
    var gbKeyParamInURI = '' ;
    if(gbKeyParam != null && gbKeyParam != undefined && gbKeyParam != '')
    {
      gbKeyParamInURI = '&' + gbKeyParam ;
    }
    for (var objName in dirTreeNode)
    {
      /* Set the name of the dir or file */
      var nodeObj = {text: objName} ;
      var currEncDirPath = encDirPath + '/' + encodeURIComponent(objName) ;

      /* The leaf will be a string containing the ref URI for the file */
      if(typeof(dirTreeNode[objName]) == 'string')
      {
        /* We have a file node */
        nodeObj.rsrcType = 'file' ;
        nodeObj.cls = this.getPublicStyle(dbNode.attributes) ;
        nodeObj.iconCls = 'wbFileTreeNode' ;
        nodeObj.leaf = true ;
        /* Set the refs to the value of this object */
        nodeObj.rsrcHost = fileHostName ;
        nodeObj.refsUri = 'http://'+fileHostName+'/REST/v1/grp/'+encodeURIComponent(grpName)+'/db/'+encodeURIComponent(dbName)+'/file'+currEncDirPath+'?'+ gbKeyParam; // + 'detailed=false&depth=immediate' ;
        nodeObj.rsrcPath = 'http://'+fileHostName+'/REST/v1/grp/'+encodeURIComponent(grpName)+'/db/'+encodeURIComponent(dbName)+'/file'+currEncDirPath+'?'+'detailed=false&depth=immediate' +  gbKeyParamInURI  ;
        nodeObj.detailsPath = this.getDetailsPath(nodeObj.refsUri) ;
      }
      else
      {
        /* Called recursively to generate the next level */
        ///* We have a directory */
        nodeObj.cls = this.getPublicStyle(dbNode.attributes) ;
        nodeObj.iconCls = 'wbFilesTreeNode' ;
        nodeObj.leaf = false ;
        //nodeObj.children = children ;
        ///* Set refs to the files API URI for the dir */
        nodeObj.text = objName ;
        nodeObj.rsrcType = 'fileFolder' ;
        nodeObj.rsrcHost = fileHostName ;
        nodeObj.refsUri = 'http://'+fileHostName+'/REST/v1/grp/'+encodeURIComponent(grpName)+'/db/'+encodeURIComponent(dbName)+'/files'+currEncDirPath+'?'+ gbKeyParam; // + 'detailed=false&depth=immediate' ;
        nodeObj.rsrcPath = 'http://'+fileHostName+'/REST/v1/grp/'+encodeURIComponent(grpName)+'/db/'+encodeURIComponent(dbName)+'/files'+currEncDirPath+'?'+'detailed=false&depth=immediate' +  gbKeyParamInURI  ;
      }
      nodeArr.push(nodeObj) ;
    }
    return nodeArr;
  } ;
}
FilesNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * FOLDER-RELATED (Files)
 * ****************************************************************** */
FileFolderNodeHelper = function()
{
  /*
   * We will use this node helper to get all 'immediate' children for a file folder
  */
  this.translateResponseForNodes = function(restData, FileFolderNode)
  {
    if(restData.length > 0)
    {
      var gbKeyParam = this.getGbKeyParamFromNode(FileFolderNode.parentNode) ;
      var folderPatt = /\/$/ ; // regexp to differentiate file and folders (folders always end with a '/')
      var filePatt = /\/db\/([^\/\?]+)\/file\// ; // regexp to replace /file/ with /files/ (in case of folders). The db/{db} anchor should make the replace more robust.
      var match ;
      var gbKeyParamInURI = '' ;
      if(gbKeyParam != null && gbKeyParam != undefined && gbKeyParam != '')
      {
        gbKeyParamInURI = '&' + gbKeyParam ;
      }
      for(var ii=0; ii<restData.length; ii++)
      {
        if(folderPatt.test(restData[ii].text)) // For folders. Register the rsrc type as itself
        {
          restData[ii].rsrcType = 'fileFolder' ;
          restData[ii].iconCls ='wbFilesTreeNode' ;
          var match = filePatt.exec(this.getRefsUri(restData[ii].refs)) ;
          restData[ii].refsUri = this.getRefsUri(restData[ii].refs).replace('/db/'+match[1]+'/file/', '/db/'+match[1]+'/files/') + gbKeyParam ; // + 'detailed=false&depth=immediate' ;
          restData[ii].rsrcPath = this.getRefsUri(restData[ii].refs).replace('/db/'+match[1]+'/file/', '/db/'+match[1]+'/files/') + '?detailed=false&depth=immediate' + gbKeyParamInURI ;
        }
        else
        {
          restData[ii].rsrcType = 'file' ;
          //restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
          restData[ii].iconCls = 'wbFileTreeNode' ;
          restData[ii].leaf = true ;
          restData[ii].refsUri = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam  ;
          restData[ii].rsrcPath = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam  ;
          restData[ii].detailsPath = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam  ;
        }
        subdirs = restData[ii].text.split('/') ;
        subdirSize = subdirs.length ;
        if(subdirs[subdirSize - 1] == '') // subdirs always end with '/' so last value will always be a ''
        {
          restData[ii].name = subdirs[subdirSize - 2] ;
          restData[ii].text = subdirs[subdirSize - 2] ;
        }
        else
        {
          restData[ii].name = subdirs[subdirSize - 1] ;
          restData[ii].text = subdirs[subdirSize - 1] ;
        }

        restData[ii].cls = this.getPublicStyle(restData[ii]) ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
FileFolderNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * CLASS-RELATED (Tracks)
 * ****************************************************************** */
ClassNodeHelper = function()
{
  /**
   * A response from a class request will contain an array of trk resources.
   * Each class will become a leaf node
   *
   */
  this.translateResponseForNodes = function(restData, classNode)
  {
    if(restData.length > 0)
    {
      var trksNode = classNode.parentNode ;
      var dbNode = trksNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      /**
       * The response is the list of track names as text entities. Each entity has the URI to the
       * actual track in its "refs" hash. Loop over the tracks in this class:
       *
       */
      for(var ii=0; ii<restData.length; ii++)
      {
        restData[ii].name = restData[ii].text ;
        restData[ii].rsrcType = 'trk' ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].iconCls ='wbTrackTreeNode' ;
        restData[ii].refsUri = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true, "ooMaxDetails") ;
        restData[ii].leaf = true ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
ClassNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * TRACK-RELATED
 * ****************************************************************** */
TrkNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ["Attributes", "AnnoAttributes", "Refs", "Classes", "DbId"] ;
  this.DETAILS_ATTR_ORDER = [ 'Name', 'Description', 'Url', 'UrlLabel', 'BigBed', 'BigWig' ] ;

  this.DETAILS_ATTR_FORMATTERS =
  {
    /**
     * For "attributes" respDataObj is a JSON data object (Array of attribute objects)
     * - It contains an Array of complex attribute-objects.
     * - Each attribute-object is a ~hash with several fields:
     *   Required:
     *   . name (of attr)
     *   . value (for attr for this track)
     *   "Optional" (not set or null == default):
     *   . defaultDisplay
     *   . display
     */
    attributes: function(respDataAttr)
    {
      /* Collect key-value pairs in 2-col array to hand off to the grid */
      if(respDataAttr)
      {
        var retVal = [] ;
        var isScoreTrk = false ;
        var pattToSkip = /^gbVcf/ ;
        /* We've asked for the ooMinDetails, so respDataAttr should be an Array of name-value objects. */
        for(var ii=0; ii<respDataAttr.length; ii++)
        {
          var respDataAttrRec = respDataAttr[ii] ;
          var customName = respDataAttrRec['name'] ;
          if(customName.match(pattToSkip))
          {
            continue ;
          }
          if(customName == 'gbTrackRecordType')
          {
            isScoreTrk = true ;
          }
          var customValue = respDataAttrRec['value'] ;
          retVal.push( [ customName, customValue ] ) ;
        }
        if(isScoreTrk)
        {
          retVal.push(['High Density Score Track?', true]) ;
        }
        else
        {
          retVal.push(['High Density Score Track?', false]) ;
        }
        /* Sort the table of name-value pairs by name */
        retVal = retVal.sort( function(aa, bb)
        {
          xx = aa[0].toLowerCase() ;
          yy = bb[0].toLowerCase() ;
          return (xx < yy ? -1 : (xx > yy ? 1 : 0)) ;
        });
      }
      return retVal ; // table of attr<->value not just one like usual
    },
    urlLabel: function(respDataAttr, fullRespData)
    {
      var urlLabel = respDataAttr ;
      var url = fullRespData['url'] ;
      if (urlLabel && urlLabel != '' && url && url != '')
      {
        urlLabel = "<a href=\""+url+"\" target=\"_blank\">" + urlLabel + "</a>" ;
      }
      return ['UrlLabel', urlLabel] ;
    },
    numAnnos: function(respDataAttr, fullRespData)
    {
      var numAnnos = Ext.util.Format.number(respDataAttr, '0,0') ;
      var retVal ;
      var isHd = false ;
      var attrList = fullRespData['attributes'] ;
      for (var ii=0; ii < attrList.length; ii++)
      {
        if (attrList[ii]['name'] == 'gbTrackRecordType')
        {
          isHd = true ;
          break ;
        }
      }
      if (isHd)
      {
        retVal = ["NumAnnos", numAnnos+" bp with scores"] ;
      }
      else
      {
        retVal = ["NumAnnos", numAnnos+" annotations"] ;
      }
      return retVal ;
    }
  } ;

  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    grpName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'grp') ;
    dbName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'db') ;
    loader.addDataToGrid(
      [
        ["Group", grpName],
        ["Database", dbName]
      ]
    ) ;
    loader.loadFromAPI() ;
  } ;

} ;
TrkNodeHelper.prototype = new NodeHelper() ;

TrksNodeHelper = function()
{
  /**
   * A response from a trks request will contain an array of trk resources.
   * These can be organized into subdirs by class and sample using the path parameter.
   *
   * [+path+]   Array: default is ['class', 'name']
   */
  this.translateResponseForNodes = function(restData, trksNode)
  {
    if(restData.length > 0)
    {
      var dbNode = trksNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++) {
        var className = restData[ii].text ;
        var encClassName = encodeURIComponent(className) ;
        restData[ii].name = className ;
        restData[ii].text = 'Class: ' + className ;
        restData[ii].rsrcType = 'cls' ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].refsUri = 'http://'+trksNode.attributes.rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/class/'+encClassName+'?'+gbKeyParam ;   // No refs for individual class (not addressable)
        restData[ii].rsrcHost = '' ;  // No refs for individual class (not addressable)
        // Get "rsrcHost" from the parent trksNode we were given:
        restData[ii].rsrcPath = 'http://'+trksNode.attributes.rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/trks?class='+encClassName ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
TrksNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * LISTS-RELATED
 * ****************************************************************** */
ListsNodeHelper = function()
{

  this.LIST_RSRC_TYPES = [ "trks", "files", "samples", "analyses", "experiments", "studies", "runs", "mixed" ] ;
  this.LIST_TYPE_NAMES = [ "Tracks", "Files", "Samples", "Analyses", "Experiments", "Studies", "Runs", "Mixed Resources" ] ;

  /**
   * Lists itself have no request/response to get and deal with. It's a static
   * container for the type of lists.
   *
   * [+path+]   Array: default is ['class', 'name']
   */
  this.translateResponseForNodes = function(restData, listsNode)
  {
    if(restData.length > 0)
    {
      var dbNode = listsNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var rsrcHost = dbNode.attributes.rsrcHost ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var gbKeyParam = '&'+this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++)
      {
        var listType = restData[ii].text ;
        var titleType = Ext.util.Format.capitalize(listType) ;
        var listName = this.LIST_TYPE_NAMES[this.LIST_RSRC_TYPES.indexOf(listType)] ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].iconCls = 'wb'+titleType+'TreeNode' ;
        restData[ii].name = listName ;
        restData[ii].text = 'Lists of ' + listName ;
        restData[ii].rsrcType = listType + 'Lists' ;
        restData[ii].rsrcPath = 'http://'+rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/'+listType+'/entityLists?connect=no'+gbKeyParam ;
        restData[ii].refsUri = 'http://'+rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/'+listType+'/entityLists?connect=no'+gbKeyParam ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
ListsNodeHelper.prototype = new NodeHelper() ;

EntitiesListsNodeHelper = function()
{
  /**
   * A response from a trks request will contain an array of trk resources.
   * These can be organized into subdirs by class and sample using the path parameter.
   *
   * [+path+]   Array: default is ['class', 'name']
   */
  this.translateResponseForNodes = function(restData, entitiesListsNode)
  {
    if(restData.length > 0)
    {
      var listsNode = entitiesListsNode.parentNode ;
      var rsrcHost = listsNode.attributes.rsrcHost ;
      var dbNode = listsNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var entitiesListsRsrcType = entitiesListsNode.attributes.rsrcType ;
      var entitiesListsRsrcTypeSingular = entitiesListsRsrcType.gsub(/Lists/, "List") ;
      var entityRsrcType = entitiesListsRsrcType.gsub(/Lists/, "") ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++)
      {
        var listName = restData[ii].text ;
        var encListName = encodeURIComponent(listName) ;
        restData[ii].name = listName ;
        restData[ii].text = listName ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].rsrcType = entitiesListsRsrcTypeSingular ;
        restData[ii].refsUri = 'http://'+rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/'+entityRsrcType+'/entityList/'+encListName+'?'+gbKeyParam ;   // No refs for individual class (not addressable)
        restData[ii].rsrcHost = '' ;  // No refs for individual class (not addressable)
        // Get "rsrcHost" from the parent trksNode we were given:
        restData[ii].rsrcPath = 'http://'+rsrcHost+'/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/'+entityRsrcType+'/entityLists/'+encListName+'?' ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
        restData[ii].leaf = true ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}

EntityListNodeHelper = function()
{
  this.DETAILS_LOADER_SETTINGS =
  {
    entityType: 'Entity',
    maxNumEntitiesToList: 100
  } ;

  this.DETAILS_ATTR_FORMATTERS =
  {
    // The special "gbFullDetailsFormatter", which can be used
    // to process whole details payload itself?
    gbFullDetailsFormatter: function(respDataObj, detailsPath, loaderObj)
    {
      /* Collect key-value pairs in 2-col array to hand off to the grid */
      if(respDataObj)
      {
        var retVal = [] ;
        /* We have a list of entity urls. Format them as 2-column array for Details grid. */
        for(var ii=0; ii<respDataObj.length; ii++)
        {
          // Have we reached the max to display in the details grid and there are still more?
          if(ii >= loaderObj.settings.maxNumEntitiesToList)
          {
            leftOver = respDataObj.length - loaderObj.settings.maxNumEntitiesToList
            retVal.push( [ ". . . (" + leftOver + " more) . . .", ". . . (" + leftOver + " more) . . ."] ) ;
            break ;
          }
          else
          {
            var respDataRec = respDataObj[ii] ;
            var respDataRecValue = respDataRec['url'] ;
            // TODO: make detail name
            var attrName = loaderObj.settings.entityType + " " + (ii+1) ;
            // TODO: extract entity name
            var attrValue = loaderObj.getEntityName(respDataRecValue) ;
            retVal.push( [ attrName, unescape(attrValue) ] ) ;
          }
        }
      }
      return retVal ; // table of attr<->value not just one like usual
    }
  } ;
}



// Generic type-specific-list node helper
EntitiesListsNodeHelper.prototype = new NodeHelper() ;
EntityListNodeHelper.prototype = new NodeHelper() ;
// Now the classes for the specific lists, which inherity from EntitiesListsNodeHelper
// (each must be enabled in NodeHelperSelector.apiTypes and set up here.)
// - tracks
TrksListsNodeHelper = function () {}
TrksListsNodeHelper.prototype = new EntitiesListsNodeHelper() ;
TrksListNodeHelper = function () { this.DETAILS_LOADER_SETTINGS = { entityType: 'Track', maxNumEntitiesToList: 100 } ; } ;
TrksListNodeHelper.prototype = new EntityListNodeHelper() ;
// - samples
SamplesListsNodeHelper = function () {}
SamplesListsNodeHelper.prototype = new EntitiesListsNodeHelper() ;
SamplesListNodeHelper = function () { this.DETAILS_LOADER_SETTINGS = { entityType: 'Sample', maxNumEntitiesToList: 100 } ; } ;
SamplesListNodeHelper.prototype = new EntityListNodeHelper() ;
// - studies
StudiesListsNodeHelper = function () {}
StudiesListsNodeHelper.prototype = new EntitiesListsNodeHelper() ;
StudiesListNodeHelper = function () { this.DETAILS_LOADER_SETTINGS = { entityType: 'Study', maxNumEntitiesToList: 100 } ; } ;
StudiesListNodeHelper.prototype = new EntityListNodeHelper() ;
// - files
FilesListsNodeHelper = function () {}
FilesListsNodeHelper.prototype = new EntitiesListsNodeHelper() ;
FilesListNodeHelper = function () { this.DETAILS_LOADER_SETTINGS = { entityType: 'File', maxNumEntitiesToList: 100 } ; } ;
FilesListNodeHelper.prototype = new EntityListNodeHelper() ;

/** *******************************************************************
 * SAMPLE SET-RELATED
 * ****************************************************************** */
SampleSetNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['State', 'Refs', 'Attributes', 'SampleList'] ;
  this.DETAILS_ATTR_ORDER = [ 'Name' ] ;

  this.DETAILS_ATTR_FORMATTERS =
  {
    /**
     * respDataObj is a JSON data object (the value for the top-level field matching the key)
     */
    attributes: function(respDataAttr)
    {
      var customAttrs = Object.keys(respDataAttr) ;
      customAttrs = customAttrs.sort( function(aa,bb)
      {
        xx = aa.toLowerCase() ;
        yy = bb.toLowerCase() ;
        return (xx < yy ? -1 : (xx > yy ? 1 : 0)) ;
      });
      var retVal = [] ;
      for(var ii=0 ; ii < customAttrs.length; ii++)
      {
        var customAttr = customAttrs[ii] ;
        retVal.push( [ correctCase(customAttrs[ii]), correctCase(respDataAttr[customAttrs[ii]]) ] ) ;
      }
      return retVal ; // table of attr<->value not just one like usual
    },
    sampleList: function(respDataAttrValue)
    {
      var sampleArray = respDataAttrValue ;
      var sampleNames = [] ;
      if(sampleArray.length > 0)
      {
        for(var ii=0 ; ii < sampleArray.length; ii++)
        {
          var sampleName = sampleArray[ii].name ;
          sampleNames[ii] = sampleName ;
        }
      }
      else
      {
        sampleNames = [ '<< none >>' ] ;
      }
      sampleNames = sampleNames.sort( function(aa,bb)
      {
        var xx = aa.toLowerCase() ;
        var yy = bb.toLowerCase() ;
        return (xx < yy ? -1 : (xx > yy ? 1 : 0 )) ;
      });
      // Should return a table (Array of rows), but can return just a single row and
      // the calling code will "fix" it by turning into a proper 1-row table.
      return [ [ 'Samples', sampleNames.join(', ').escapeHTML() ] ] ;
    }
  } ;

  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    grpName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'grp') ;
    dbName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'db') ;
    loader.addDataToGrid(
      [
        ["Group", grpName],
        ["Database", dbName]
      ]
    ) ;
    loader.loadFromAPI() ;
  } ;
} ;
SampleSetNodeHelper.prototype = new NodeHelper() ;

SampleSetsNodeHelper = function()
{
  this.iconCls = 'wbSampleSetsTreeNode' ;

  /**
   * A response from a sampleSets request will contain an array of sampleSet resources.
   */
  this.translateResponseForNodes = function(restData, sampleSetsNode)
  {
    if(restData.length > 0)
    {
      var dbNode = sampleSetsNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++)
      {
        var sampleSetName = restData[ii].name ;
        var encSampleSetName = encodeURIComponent(sampleSetName) ;
        restData[ii].name = sampleSetName ;
        restData[ii].text = sampleSetName ;
        restData[ii].rsrcType = 'sampleSet' ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].iconCls ='wbSampleSetTreeNode' ;
        restData[ii].refsUri = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
        restData[ii].leaf = true ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
} ;
SampleSetsNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * SAMPLE-RELATED
 * ****************************************************************** */
SampleNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ["State", "Refs", 'FileLocation'] ;
  this.DETAILS_ATTR_ORDER = [ 'Name', 'Type' ] ;

  this.DETAILS_ATTR_FORMATTERS =
  {
    /**
     * respDataObj is a JSON data object
     */
    avpHash: function(respDataAttr)
    {
      var customAttrs = Object.keys(respDataAttr) ;
      customAttrs = customAttrs.sort( function(aa,bb)
      {
        xx = aa.toLowerCase() ;
        yy = bb.toLowerCase() ;
        return (xx < yy ? -1 : (xx > yy ? 1 : 0)) ;
      });
      var retVal = [] ;
      for(var ii=0 ; ii < customAttrs.length; ii++)
      {
        var customAttr = customAttrs[ii] ;
        retVal.push( [ customAttrs[ii], respDataAttr[customAttrs[ii]] ] ) ;
      }
      return retVal ; // table of attr<->value not just one like usual
    }
  } ;

  this.updateDetails = function(node)
  {
    /* Default behavior, get details from the node */
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    grpName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'grp') ;
    dbName = ApiUriHelper.extractRsrcName(node.attributes.refsUri, 'db') ;
    loader.addDataToGrid(
      [
        ["Group", grpName],
        ["Database", dbName]
      ]
    ) ;
    loader.loadFromAPI() ;
  } ;
} ;
SampleNodeHelper.prototype = new NodeHelper() ;

SamplesNodeHelper = function()
{
  this.iconCls = 'wbSamplesTreeNode' ;

  /**
   * A response from a samples request will contain an array of sample resources.
   */
  this.translateResponseForNodes = function(restData, sampleNode)
  {
    if(restData.length > 0)
    {
      var dbNode = sampleNode.parentNode ;
      var dbName = dbNode.attributes.name ;
      var encDbName = encodeURIComponent(dbName) ;
      var grpNode = dbNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var gbKeyParam = this.getGbKeyParamFromNode(dbNode) ;
      for(var ii=0; ii<restData.length; ii++)
      {
        var sampleName = restData[ii].text ;
        var encSampleName = encodeURIComponent(sampleName) ;
        restData[ii].name = sampleName ;
        restData[ii].rsrcType = 'bioSample' ;
        restData[ii].iconCls ='wbSampleTreeNode' ;
        restData[ii].cls = this.getPublicStyle(dbNode.attributes) ;
        restData[ii].refsUri = this.getRefsUri(restData[ii].refs) + "?" + gbKeyParam ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
        restData[ii].leaf = true ;
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
SamplesNodeHelper.prototype = new NodeHelper() ;


/** *******************************************************************
 * HUB GENOME - RELATED
 * ****************************************************************** */
GenomeNodeHelper = function()
{
  this.DETAILS_HIDDEN_ATTRS = ['orderKey'] ; 
  this.DETAILS_ATTR_ORDER = ['Genome', 'Organism', 'Description'] ;
  this.DETAILS_ATTR_FORMATTERS =
  {
    gbFullDetailsFormatter: function(respDataObj, detailsPath, loaderObj)
    {
      if(respDataObj)
      {
        var retVal = [];
        for(var ii=0; ii<loaderObj.attrDisplayOrder.length; ii++)
        {
          retVal.push([loaderObj.attrDisplayOrder[ii], respDataObj[loaderObj.attrDisplayOrder[ii].toLowerCase()]]) ;
        }
      }
      return retVal ;
    }
  } ;
  this.updateDetails = function(node)
  {
    var loader = new DetailsLoader(node.attributes.detailsPath, this.DETAILS_HIDDEN_ATTRS, this.DETAILS_ATTR_ORDER, this.DETAILS_ATTR_FORMATTERS) ;
    loader.loadFromAPI() ;
  }
}
GenomeNodeHelper.prototype = new NodeHelper() ;

GenomesNodeHelper = function()
{
  /**
  * Response from a genomes request will contain an array of genome resources.
  * Each genome will contain a "hubtrks", trks resource - with both trk and file entities.
  */

  this.translateResponseForNodes = function(restData, genomesNode) {
    if(restData.length > 0)
    {
      var grpNode = genomesNode.parentNode.parentNode.parentNode ;
      var grpName = grpNode.attributes.name ;
      var encGrpName = encodeURIComponent(grpName) ;
      var hubNode = genomesNode.parentNode ;
      var hubName = hubNode.attributes.name ;
      var encHubName = encodeURIComponent(hubName) ;
      for(var ii=0; ii<restData.length; ii++) {
        var genomeName = restData[ii].genome ;
        var encGenomeName = encodeURIComponent(genomeName) ;
        var gbKeyParam = this.getGbKeyParam(restData[ii].gbKey) ;
        restData[ii].text = genomeName;
        restData[ii].rsrcType = 'genome'
        restData[ii].cls = this.getPublicStyle(restData[ii]) ;
        restData[ii].iconCls = 'wbGenomeTreeNode' ;
        restData[ii].refsUri = 'http://'+grpNode.attributes.rsrcHost+'/REST/v1/grp/'+encGrpName+'/hub/'+encHubName+'/genome/'+encGenomeName+'?'+gbKeyParam ;
        restData[ii].rsrcHost = this.getRefsHost(restData[ii].refsUri) ;
        restData[ii].detailsPath = this.getDetailsPath(restData[ii].refsUri, true) ;
        var baseUrl = 'http://'+restData[ii].rsrcHost+'/REST/v1/grp/'+encGrpName+'/hub/'+encHubName+'/genome/'+encGenomeName;
        restData[ii].leaf = true; 
      }
    }
    else
    {
      restData.push(this.EMPTY_LEAF);
    }
    return restData;
  } ;
}
GenomesNodeHelper.prototype = new NodeHelper() ;

/** *******************************************************************
 * GENERIC SELECTOR stuff
 * ****************************************************************** */
NodeHelperSelector =
{
  /**
   * This object maps API node types to Helper Objects,
   */
  apiTypes:
  {
    generic: NodeHelper,
    host: HostNodeHelper,
    hosts: HostsNodeHelper,
    grp: GrpNodeHelper,
    grps: GrpsNodeHelper,
    kbs: KbsNodeHelper,
    colls: CollsNodeHelper,
    trRulesDocs: TransformsNodeHelper,
    db: DbNodeHelper,
    dbs: DbsNodeHelper,
    prj: PrjNodeHelper,
    prjs: PrjsNodeHelper,
    redminePrj: RedminePrjNodeHelper,
    redminePrjs: RedminePrjsNodeHelper,
    hub: HubNodeHelper,
    hubs: HubsNodeHelper,
    file: FileNodeHelper,
    files: FilesNodeHelper,
    fileFolder: FileFolderNodeHelper,
    cls: ClassNodeHelper,
    trk: TrkNodeHelper,
    trks: TrksNodeHelper,
    query: QueryNodeHelper,
    queries: QueriesNodeHelper,
    bioSample: SampleNodeHelper,
    bioSamples: SamplesNodeHelper,
    sampleSet: SampleSetNodeHelper,
    sampleSets: SampleSetsNodeHelper,
    genome: GenomeNodeHelper,
    genomes: GenomesNodeHelper,
    /* Entity-Lists: */
    lists: ListsNodeHelper,
    trksLists: TrksListsNodeHelper,
    trksList: TrksListNodeHelper,
    samplesLists: SamplesListsNodeHelper,
    samplesList: SamplesListNodeHelper,
    studiesLists: StudiesListsNodeHelper,
    studiesList: StudiesListNodeHelper,
    filesLists: FilesListsNodeHelper,
    filesList: FilesListNodeHelper/*,
    filesLists: FilesListsNodeHelper,
    analysesLists: AnalysesListsNodeHelper,
    experimentsLists: ExperimentsListsNodeHelper,
    studiesLists: StudiesListsNodeHelper,
    runsLists: RunsListsNodeHelper,
    mixedLists: mixedListsNodeHelper */
  },

  /**
   * Takes am ExtJS TreeNode and returns the object that has the helper functions
   * based on the rsrcType that is set for the node.
   *
   * Create an object map that holds any dynamic classes
   */
  getNodeHelper: function(node) {
    var loaderObj = null ;
    /* Report error if the node does not have a rsrcType */
    if(node.attributes.rsrcType)
    {
      rsrcType = node.attributes.rsrcType ;
      if(this.apiTypes[node.attributes.rsrcType] == undefined)
      {
        loaderObj = new NodeHelper() ;
      }
      else
      {
        loaderObj = new this.apiTypes[node.attributes.rsrcType]() ;
      }
    }
    else
    {
      alert('The node does not have a valid rsrcType.') ;
    }
    return loaderObj;
  },

  getNodeHelperForType: function(rsrcType) 
  {
    var loaderObj = null ;
    if(this.apiTypes[rsrcType] == undefined)
    {
      loaderObj = new NodeHelper() ;
    }
    else
    {
      loaderObj = new this.apiTypes[rsrcType]() ;
    }
    return loaderObj ;
  }
} ;

rsrcTypeToIconClass = {
  host: 'wbHostTreeNode',
  grps: 'wbGrpsTreeNode',
  grp: 'wbGrpTreeNode',
  dbs: 'wbDbsTreeNode',
  db: 'wbDbTreeNode',
  kbs: 'wbKbsTreeNode',
  kb: 'wbKbTreeNode',
  colls: 'wbCollsTreeNode',
  coll: 'wbCollTreeNode',
  trRulesDocs: 'wbTransTreeNode',
  trRulesDoc: 'wbTranTreeNode',
  prjs: 'wbPrjsTreeNode',
  prj: 'wbPrjTreeNode',
  redminePrjs: 'wbRedminePrjsTreeNode',
  redminePrj: 'wbRedminePrjTreeNode',
  hubs: 'wbHubsTreeNode',
  hub: 'wbHubTreeNode'
} ;

/**
 * Takes an API file resource and initializes a download using iframe.
 */
function downloadFile(fileUri)
{
  /* First translate The File resource URI to the data download URI */
  var requestPath = fileUri ;
  /* If there's a '?', append '/data' before it */
  if(requestPath.indexOf('?') >= 0)
  {
    requestPath = requestPath.substr(0, requestPath.indexOf('?')) ;
  }
  /* To get the file contents we need the 'data' resource */
  requestPath += '/data' ;
  /* Use a hidden iframe to initialize the download of the file. */
  Ext.DomHelper.append(document.body, {
    tag: 'iframe',
    frameBorder: 0,
    width: 0,
    height: 0,
    css: 'display:none;visibility:hidden;height:1px;',
    src: '/java-bin/apiCaller.jsp?fileDownload=true&rsrcPath='+encodeURIComponent(requestPath)
  });
  return false;
}
