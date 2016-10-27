(
  // manage.js - Initialize ExtJS widgets for query management UI (self-invoking method)
  function() 
  {
    // ExtJS not necessarily needed everywhere here, but utilize it so it fits with the page
    // Query text field (with remote validation)
    var qNameField = new Ext.form.TextField({
      id: 'queryName',
      renderTo: 'qName',
      allowBlank: false,
      blankText: 'You must specify a query name',
      validateOnBlur: true,
      plugins: [Ext.ux.plugins.RemoteValidator],
      rvOptions: {
        url: '/java-bin/queryRequestHandler.jsp',
        loadingInd: 'nameLoadingInd',
        params: {
          mode: 'qNameCheck',
          group: '',
          db: ''
        },
        callback: function(opts, success, resp) {
          var updateBtn = Ext.get('updateButton') ;
          var response = Ext.util.JSON.decode(resp.responseText) ;

          if(!updateBtn)
          {
            return ;
          }

          if(!success)
          {
            // Error talking to the server, either way we can't validate name
            updateBtn.dom.disabled = true ;
          }
          else
          {
            updateBtn.dom.disabled = !(response.valid) ;
          }
        }
      }
    }) ;

    if((typeof(wbFormContext) !== 'undefined') && wbFormContext && wbFormContext.get('group') && wbFormContext.get('db'))
    {
      // Set the group/db to check when naming a query
      qNameField.rvOptions.params.group = wbFormContext.get('group') ;
      qNameField.rvOptions.params.db = wbFormContext.get('db') ;
    }
    qNameField.focus() ;
 
    qNameField.on('invalid', function(field, msg) {
      if(field.getValue() && field.getValue() === BHI.getOrigQueryName())
      {
        field.clearInvalid() ;
      }
    }) ;
   
    // Query template combobox
    var templateCombo = new Ext.form.ComboBox({
      id: 'templateCombo',
      renderTo: 'tmpls',
      store: new Ext.data.JsonStore({
        url: '/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(wbFormContext.get('group')) 
           + '/db/' + encodeURIComponent(wbFormContext.get('db')) + '/queryable') + '&method=GET',
        root: 'data',
        id: 'resource',
        fields: ['resource', 'queryable', 'attrs', 'templateURI', 'displayName']
      }),
      valueField: 'resource',
      displayField: 'displayName',
      mode: 'remote',
      resizable: true,
      triggerAction: 'all',
      emptyText: 'Select a template...',
      forceSelection: true,
      selectOnFocus: true,
      typeAhead: true
    }) ;
    templateCombo.store.on('load', function(store, records, opts) {
      BHI.setTemplates(records) ;
    }) ;

    templateCombo.on('select', function(combo, rec, index) {
      BHI.setTemplate(rec.get('resource')) ;
      BHI.getAttrs(rec.get('resource')) ;
    }) ;
    
    // Query description area
    var qDescArea = new Ext.form.TextArea({
      id: 'queryDesc',
      renderTo: 'qDesc',
      grow: true,
      value: '',
      width: 410,
      height: 35
    }) ;
    
    // Query shared checkbox
    var sharedCheck = new Ext.form.Checkbox({
      id: 'queryShared',
      renderTo: 'qShared'
    }) ;

    // Transform elements to Ext widgets depending on the mode
    if((typeof(wbFormContext) !== 'undefined') && wbFormContext && wbFormContext.get('queryUri'))
    {
      BHI.loadQuery(wbFormContext.get('queryUri')) ;
    }
  }
)() ;
