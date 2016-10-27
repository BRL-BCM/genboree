Ext.namespace('Ext.ux', 'Ext.ux.data');

/**
 * Override JsonReader to do the translations betwwen the API format and the store format
 */
Ext.ux.data.GbTrkAttrJsonReader = function(meta, recType) {
    // call parent constructor
    Ext.ux.data.GbTrkAttrJsonReader.superclass.constructor.call(this, meta, recType);
};
Ext.extend(Ext.ux.data.GbTrkAttrJsonReader, Ext.data.JsonReader, {

    /**
     * Overridden to add translate line
     */
    read : function(response){
        var json = response.responseText;
        var o = Ext.decode(json);
        if(!o) {
            throw {message: 'JsonReader.read: Json object not found'};
        }
        o = this.translateResponse(o) ;
        return this.readRecords(o);
    },
  
     /**
      * Overridden to add translate line
      */
    readResponse : function(action, response) {
        var o = (response.responseText !== undefined) ? Ext.decode(response.responseText) : response;
        if(!o) {
            throw new Ext.data.JsonReader.Error('response');
        }

        o = this.translateResponse(o) ;
        var root = this.getRoot(o);
        if (action === Ext.data.Api.actions.create) {
            var def = Ext.isDefined(root);
            if (def && Ext.isEmpty(root)) {
                throw new Ext.data.JsonReader.Error('root-empty', this.meta.root);
            }
            else if (!def) {
                throw new Ext.data.JsonReader.Error('root-undefined-response', this.meta.root);
            }
        }

        // instantiate response object
        var res = new Ext.data.Response({
            action: action,
            success: this.getSuccess(o),
            data: (root) ? this.extractData(root, false) : [],
            message: this.getMessage(o),
            raw: o
        });

        // blow up if no successProperty
        if (Ext.isEmpty(res.success)) {
            throw new Ext.data.JsonReader.Error('successProperty-response', this.meta.successProperty);
        }
        return res;
    },
    
    translateResponse : function(jsonObj) {
      var attrArr = jsonObj.data ;
      var newAttrArr = [];
      for(var ii=0; ii<attrArr.length; ii++)
      {
        /* Hide attributes that have a nil value or are prefixed with 'gb' */
        /* Double encode the id because it will be used in the rsrcPath URL parameter to API caller */
        /* Append 'value' because this is the resource we are working on */
        if(!attrArr[ii].name.match(/^gb/))
        {
          var newAttr = {} ;  
          newAttr.id = encodeURIComponent(encodeURIComponent(attrArr[ii].name) + '/value') ;
          newAttr.attrName = attrArr[ii].name ;
          newAttr.attrValue = attrArr[ii].value ;
          newAttrArr.push(newAttr) ;
        }
      }
      jsonObj.data = newAttrArr;
      return jsonObj
    },
    
    /**
     * Not overridden yet, TODO, fix update attrName/id bug
     */
    realize: function(rs, data){
        if (Ext.isArray(rs)) {
            for (var i = rs.length - 1; i >= 0; i--) {
                // recurse
                if (Ext.isArray(data)) {
                    this.realize(rs.splice(i,1).shift(), data.splice(i,1).shift());
                }
                else {
                    // weird...rs is an array but data isn't??  recurse but just send in the whole invalid data object.
                    // the else clause below will detect !this.isData and throw exception.
                    this.realize(rs.splice(i,1).shift(), data);
                }
            }
        }
        else {
            // If rs is NOT an array but data IS, see if data contains just 1 record.  If so extract it and carry on.
            if (Ext.isArray(data) && data.length == 1) {
                data = data.shift();
            }
            if (!this.isData(data)) {
                // TODO: Let exception-handler choose to commit or not rather than blindly rs.commit() here.
                //rs.commit();
                throw new Ext.data.DataReader.Error('realize', rs);
            }
            rs.phantom = false; // <-- That's what it's all about
            rs._phid = rs.id;  // <-- copy phantom-id -> _phid, so we can remap in Store#onCreateRecords
            rs.id = this.getId(data);
            rs.data = data;

            rs.commit();
        }
    }
    
    
}) ;


/**
 * Override HttpProxy to translate the request payload from the Ext store json format to the API json format
 */

Ext.ux.data.GbTrkAttrHttpProxy = function(meta, recType) {
    // call parent constructor
    Ext.ux.data.GbTrkAttrHttpProxy.superclass.constructor.call(this, meta, recType);
};
Ext.extend(Ext.ux.data.GbTrkAttrHttpProxy, Ext.data.HttpProxy, {
    /* Overridden to add translate code */
    request : function(action, rs, params, reader, callback, scope, options) {
        if (!this.api[action] && !this.load) {
            throw new Ext.data.DataProxy.Error('action-undefined', action);
        }
        if(action === 'create' || action === 'update')
        {
          /* Need to check whether the attribute already exists */
          paramObj = Ext.decode(params.data) ;
          var encNewId = encodeURIComponent(encodeURIComponent(paramObj.attrName)) ;
          var attrExists = (rs.store.getById(encNewId)) ? true : false ;
          var overwriteConfirmed = false ;
          /* Warn if it's a new attr and there's a dup.  Or if it's an update of the attrname to an existing attr */
          if(attrExists && (action == 'create' || (action == 'update' && rs.id != encNewId)))
          {
            var mmm = Ext.Msg.confirm("Attribute Name Conflict", "An attribute named '"+paramObj.attrName+"' already exists.  Would you like to overwrite this attribute?", function(btn) {
              if(btn == 'yes')
              {
                /* remove the other record with this id */
                rs.store.remove(rs.store.getById(encNewId)) ;
                params = this.translateForUpdate(params) ;
                this.finishRequest(action, rs, params, reader, callback, scope, options) ;
              }
            }, this) ;
          }
          else
          {
            params = this.translateForUpdate(params) ;
            this.finishRequest(action, rs, params, reader, callback, scope, options) ;
          }
        }
        else
        {
          this.finishRequest(action, rs, params, reader, callback, scope, options) ;
        }
    },

    finishRequest : function(action, rs, params, reader, callback, scope, options) {
        params = params || {};
        if ((action === Ext.data.Api.actions.read) ? this.fireEvent("beforeload", this, params) : this.fireEvent("beforewrite", this, action, rs, params) !== false) {
            this.doRequest.apply(this, arguments);
        }
        else {
            callback.call(scope || this, null, options, false);
        }
    },


    /**
     * reqBody will be an object {data:"{attrName: foo, attrValue: bar}"}
     */
    translateForUpdate : function(reqBody)
    {
      var attrHash = Ext.decode(reqBody.data) ;
      var attrApiObj = {data:{}} ;
      attrApiObj.data.name = attrHash.attrName ;
      attrApiObj.data.value = attrHash.attrValue ;
      attrApiObj.data.display = null ;
      attrApiObj.data.defaultDisplay = null ;
      return {payload:Object.toJSON(attrApiObj)} ;
    },

}) ;

/**
 * App.user.Grid
 * A typical EditorGridPanel extension.
 */
myGrid = Ext.extend(Ext.grid.EditorGridPanel, {
    renderTo: 'wbAttrGridDiv',
    iconCls: 'silk-grid',
    frame: true,
    height: 250,
    width: 470,
    style: 'margin-top: 10px',

    initComponent : function() {

        // typical viewConfig
        this.viewConfig = {
            forceFit: true
        };

        // relay the Store's CRUD events into this grid so these events can be conveniently listened-to in our application-code.
        this.relayEvents(this.store, ['destroy', 'save', 'update']);

        // build toolbars and buttons.
        this.tbar = this.buildTopToolbar();
 //       this.buttons = this.buildUI();

        // super
        myGrid.superclass.initComponent.call(this);
    },

    /**
     * buildTopToolbar
     */
    buildTopToolbar : function() {
        return [{
            text: 'Add',
            iconCls: 'wbAdd',
            handler: this.onAdd,
            scope: this
        }, '-', {
            text: 'Delete',
            iconCls: 'wbDelete',
            handler: this.onDelete,
            scope: this
        }, '-'];
    },


    /**
     * buildUI
     */
    buildUI : function() {
        return [{
            text: 'Save',
            iconCls: 'wbSave',
            handler: this.onSave,
            scope: this
        }];
    },

    /**
     * onSave
     */
    onSave : function(btn, ev) {
        this.store.save();
    },

    /**
     * onAdd
     */
    onAdd : function(btn, ev) {
        var u = new this.store.recordType({
            attrName : '',
            attrValue: ''
        });
        this.stopEditing();
        this.store.insert(0, u);
        this.startEditing(0, 0);
    },

    /**
     * onDelete
     */
    onDelete : function(btn, ev) {
        var index = this.getSelectionModel().getSelectedCell();
        if (!index) {
            return false;
        }
        var rec = this.store.getAt(index[0]);
        this.store.remove(rec);
    }
});

// Create HttpProxy instance.
var proxy = new Ext.ux.data.GbTrkAttrHttpProxy({
    api: {
        /* read will GET a detailed attribute list from the attributes resource */
        read : 'apiCaller.jsp?rsrcPath='+encodeURIComponent('/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/trk/'+encTrkName+'/attributes?detailed=true'),
        /* create will PUT a detailed attribute entity to the attribute resource */
        create : {url: 'apiCaller.jsp?apiMethod=PUT&rsrcPath='+encodeURIComponent('/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/trk/'+encTrkName+'/attribute'), method: 'POST' },
        /* update will PUT a text entity to the attribute/<attrName>/value resource */
        update: {url: 'apiCaller.jsp?apiMethod=PUT&rsrcPath='+encodeURIComponent('/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/trk/'+encTrkName+'/attribute'), method: 'POST' },
        /* delete will DELETE to the attribute/<attrName>/value resource */
        destroy: {url: 'apiCaller.jsp?apiMethod=DELETE&rsrcPath='+encodeURIComponent('/REST/v1/grp/'+encGrpName+'/db/'+encDbName+'/trk/'+encTrkName+'/attribute'), method: 'POST' }
    }
    
});

// Typical JsonReader.  Notice additional meta-data params for defining the core attributes of your json-response
var reader = new Ext.ux.data.GbTrkAttrJsonReader({
    idProperty: 'id',
    root: 'data',
    successProperty: function(resp) { return (resp.status.statusCode == 'OK' || resp.status.statusCode == 'Created') ? true : false ; },
    messageProperty: 'status.msg'  // <-- New "messageProperty" meta-data
}, [
    {name: 'attrName', allowBlank: false},
    {name: 'attrValue', allowBlank: false}
]



);

// The new DataWriter component.
var writer = new Ext.data.JsonWriter({
    writeAllFields: true
});

// Typical Store collecting the Proxy, Reader and Writer together.
var store = new Ext.data.Store({
    id: 'user',
    restful: true,
    proxy: proxy,
    reader: reader,
    writer: writer,  // <-- plug a DataWriter into the store just as you would a Reader
    autoSave: true // <-- false would delay executing create, update, destroy requests until specifically told to do so with some [save] buton.

});

// load the store immediately
store.load();

////
// all exception events
//
Ext.data.DataProxy.addListener('exception', function(proxy, type, action, options, res) {
  Ext.Msg.show({
    title: 'Error',
    msg: "There was a problem saving the attributes.  Your changes have not been saved.<br><br>" +
         res.status + " - " + res.statusText + "<br><br>" + res.responseText,
    icon: Ext.MessageBox.ERROR,
    buttons: Ext.Msg.OK
  });
});

// A new generic text field
var textField =  new Ext.form.TextField();

var userColumns =  [
    {header: "Name", width: 50, sortable: true, dataIndex: 'attrName', editor: textField},
    {header: "Value", width: 50, sortable: true, dataIndex: 'attrValue', editor: textField}
];

Ext.onReady(function() {
    Ext.QuickTips.init();
    var userGrid = new myGrid({
        renderTo: 'wbAttrGridDiv',
        store: store,
        columns: userColumns
    });
});