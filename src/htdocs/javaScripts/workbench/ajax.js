Ext.onReady(function()
{
  // Requires availability of the globals and Workbench namespace.
  setTimeout( function() { initAjax() }, 50 ) ;
}) ;

function initAjax()
{
  // Requires availability of the globals and Workbench namespace.
  if(Workbench.globalsLoaded)
  {
    //--------------------------------------------
    // Loader for tree
    Workbench.wbMainTreeLoader = new Ext.ux.tree.GbApiTreeLoader(
    {
      id: "wbMainTreeLoader",
      dataUrl: '/java-bin/apiCaller.jsp',
      baseParams:
      {
        apiMethod: "GET"
      },
      preLoadChildren: false
    }) ;

    if(context)
    {
      Workbench.wbMainTreeLoader.baseParams.context = context ;
    }                                 

    Workbench.wbMainTreeLoader.on("loadexception", function(loader, node, transport)
    {
      // Check if we got a JSON response
      var response = {} ;
      try
      {
        response = Ext.util.JSON.decode(transport.responseText) ;
      }
      catch(e)
      {
        // do nothing
      }

      if(transport.type == "GenboreeError") {
        // then loader has come through a "GenboreeError" controlled thrown error
        // so that "message" and "windowTitle" are available from transport
        var messageWrapper = {
          responseText: transport.message
        } ;
        displayFailureDialog(messageWrapper, transport.windowTitle) ;
      }
      else {
        // otherwise display generic error from API request failure; perhaps timeout, etc.
        displayFailureDialog(transport, 'Problem loading data') ;
      }
      return false ;
    }) ;
 
    /**
     * When a node of the tree is clicked, this is called before the request
     * is made to retrieve the children of the node.
     */    
    Workbench.wbMainTreeLoader.on("beforeload", function(loader, node)
    {
      /**
       * Need the API URI that has the children of the node.
       * This should be stored in the node: node.attributes.rsrcPath
       * Pass an HTTP parameter called "rsrcPath" to the server
       */
      if(node.attributes.rsrcPath != undefined)
      {
        loader.baseParams.rsrcPath = node.attributes.rsrcPath;
      }
    });

    // Ajax & loaders loaded, let others know.
    Workbench.ajaxLoaded = true ;
  }
  else // don't have dependencies, try again in a very short while
  {
    setTimeout( function() { initAjax() }, 50) ;
  }
}


Ext.ns('Ext.ux.tree');


/**
 * @class Ext.ux.tree.GbApiTreeLoader
 * @extends Ext.tree.TreeLoader
 * <p>A TreeLoader that can convert a Genboree API response into a hierarchy of {@link Ext.tree.TreeNode}s.
 *
 * Depending on the node's rsrcType, the appropriate translateResponseForNodes will be called.
 *
 * @constructor
 * Creates a new GbApiTreeloader.
 * @param {Object} config A config object containing config properties.
 */
Ext.ux.tree.GbApiTreeLoader = Ext.extend(Ext.tree.TreeLoader, {

  /**
   * Override
   */
  processResponse : function(response, node, callback, scope){
    var json = response.responseText;
    try {
      var respDataObj = Ext.decode(json).data ;
      /* Get the appropriate node helper object based on the node's rsrcType */
      var loaderObj = NodeHelperSelector.getNodeHelper(node) ;
      /* call the translate function. */
      var extNodesObj = loaderObj.translateResponseForNodes(respDataObj, node) ;
      node.beginUpdate();
      /* Adds functionality that nodes are reloaded when double clicked */
      node.on('dblclick', function()
      {
        if(!this.leaf)
        {
          Workbench.mainTreeFilter.clear();
          this.reload();
        }
      });
      for(var ii = 0, len = extNodesObj.length; ii < len; ii++){
        var nn = this.createNode(extNodesObj[ii]);
        if(nn){
          node.appendChild(nn);
          /* Adds functionality that nodes are reloaded when double clicked for children nodes */
          nn.on('dblclick', function()
          {
            if(!this.leaf)
            {
              Workbench.mainTreeFilter.clear();
              this.reload();
            }
          });
        }
      }
      node.endUpdate();
      this.runCallback(callback, scope || node, [node]);
    }catch(err){
      // Allow errors to be thrown from NodeHelpers provided that they throw an object that 
      //   has the following attributes:
      //   type [String] must be == "GenboreeError"
      //   message [String] the error message to display
      //   windowTitle [String] (optional) title to use for the window
      // Provide error message through the usual TreeLoader loadexception event
      if(err.type != undefined && err.type == "GenboreeError" && err.message != undefined) {
        var windowTitle = "Problem loading data" ;
        if(err.windowTitle != undefined) {
          windowTitle = err.windowTitle ; 
        }
        response.type = err.type ;
        response.message = err.message ;
        response.windowTitle = windowTitle ;
      }
      this.handleFailure(response);
    }
  }
});

//backwards compat
Ext.ux.GbApiTreeLoader = Ext.ux.tree.GbApiTreeLoader;

/**
 * Fixes a bug with Webkit browsers when form attributes are restored.
 *
 */
Ext.override(Ext.data.Connection, {
  
    doFormUpload : function(o, ps, url){
        var id = Ext.id(),
            doc = document,
            frame = doc.createElement('iframe'),
            form = Ext.getDom(o.form),
            hiddens = [],
            hd,
            encoding = 'multipart/form-data',
            buf = {
                target: form.target,
                method: form.method,
                encoding: form.encoding,
                enctype: form.enctype,
                action: form.action
            };

        
        Ext.fly(frame).set({
            id: id,
            name: id,
            cls: 'x-hidden',
            src: Ext.SSL_SECURE_URL
        }); 

        doc.body.appendChild(frame);

        
        if(Ext.isIE){
           document.frames[id].name = id;
        }


        Ext.fly(form).set({
            target: id,
            method: 'POST',
            enctype: encoding,
            encoding: encoding,
            action: url || buf.action
        });

        
        Ext.iterate(Ext.urlDecode(ps, false), function(k, v){
            hd = doc.createElement('input');
            Ext.fly(hd).set({
                type: 'hidden',
                value: v,
                name: k
            });
            form.appendChild(hd);
            hiddens.push(hd);
        });

        function cb(){
            var me = this,
                
                r = {responseText : '',
                     responseXML : null,
                     argument : o.argument},
                doc,
                firstChild;

            try{
                doc = frame.contentWindow.document || frame.contentDocument || WINDOW.frames[id].document;
                if(doc){
                    if(doc.body){
                        if(/textarea/i.test((firstChild = doc.body.firstChild || {}).tagName)){ 
                            r.responseText = firstChild.value;
                        }else{
                            r.responseText = doc.body.innerHTML;
                        }
                    }
                    
                    r.responseXML = doc.XMLDocument || doc;
                }
            }
            catch(e) {}

            Ext.EventManager.removeListener(frame, 'load', cb, me);

            me.fireEvent('requestcomplete', me, r, o);
            Ext.fly(form).set(buf);

            function runCallback(fn, scope, args){
                if(Ext.isFunction(fn)){
                    fn.apply(scope, args);
                }
            }

            runCallback(o.success, o.scope, [r, o]);
            runCallback(o.callback, o.scope, [o, true, r]);


            if(!me.debugUploads){
                setTimeout(function(){Ext.removeNode(frame);}, 100);
            }
        }

        Ext.EventManager.on(frame, 'load', cb, this);
        form.submit();

        Ext.each(hiddens, function(h) {
            Ext.removeNode(h);
        });
    }
});



