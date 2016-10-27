(
  // create.js - Initialize ExtJS widgets for query creation UI (self-invoking method)
  function() 
  {
    // ExtJS not necessarily needed, but utilize it so it fits with the page
    // Query template combobox
    var templateCombo = new Ext.form.ComboBox({
      id: 'templateCombo',
      renderTo: 'tmpls',
      store: new Ext.data.JsonStore({
        autoLoad: true,
        url: '/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent('/REST/v1/grp/' + encodeURIComponent(wbFormContext.get('tmplGroup')) 
           + '/db/' + encodeURIComponent(wbFormContext.get('tmplDb')) + '/queryable') + '&method=GET',
        root: 'data',
        idProperty: 'resource',
        fields: ['resource', 'queryable', 'attrs', 'templateURI', 'displayName', 'responseFormat']
      }),
      valueField: 'resource',
      displayField: 'displayName',
      mode: 'local',
      resizable: true,
      triggerAction: 'all',
      emptyText: 'Select a template...',
      forceSelection: true,
      selectOnFocus: true,
      typeAhead: true
    }) ;
    templateCombo.store.on('load', function(store, records, opts) {
      BHI.setTemplates(records) ;
      
      if(typeof(wbFormContext) !== 'undefined' && wbFormContext && wbFormContext.get('tmpl'))
      {
        var tmplRecord = templateCombo.findRecord('resource', wbFormContext.get('tmpl')) ;
        var index = store.indexOf(tmplRecord) ;
        templateCombo.onSelect(tmplRecord, index) ;
      }
    }) ;

    templateCombo.on('select', function(combo, rec, index) {
      BHI.setTemplate(rec.get('resource')) ;
      BHI.getAttrs(rec.get('resource')) ; 
    }) ;
    
    // Clause attribute combobox
    var attrCombo = new Ext.form.ComboBox({
      id: 'clause1AttrCombo',
      renderTo: 'clause1Attr',
      store: new Ext.data.ArrayStore({
        fields: ['attr', 'display']
      }),
      valueField: 'attr',
      displayField: 'display',
      mode: 'local',
      resizable: true,
      width: 150,
      triggerAction: 'all',
      allowBlank: false,
      emptyText: 'Select an attribute...',
      forceSelection: false,
      selectOnFocus: true,
      typeAhead: true
    }) ;
    attrCombo.on('blur', function() { BHI.updateQuerySummary() ; }) ;

    // Clause operator combobox
    var opCombo = new Ext.form.ComboBox({
      id: 'clause1OpCombo',
      renderTo: 'clause1Op',
      store: BHI.getOps(),
      width: 150,
      mode: 'local',
      resizable: true,
      triggerAction: 'all',
      allowBlank: false,
      emptyText: 'Select an operator...',
      forceSelection: true,
      selectOnFocus: true,
      typeAhead: true
    }) ;
    opCombo.on({
      'blur': { fn: function() { BHI.updateQuerySummary() ; }},
      'select': { fn: function(cb, rec, index) { BHI.setOpEl(cb, rec, index) ; }}
    }) ;
    
    // Clause value text field
    var valField = new Ext.form.TextField({
      id: 'clause1ValField',
      renderTo: 'clause1Val',
      allowBlank: false,
      width: 115,
      style: { cssFloat: 'left', styleFloat: 'left' }
    }) ;
    valField.on('blur', function() { BHI.updateQuerySummary() ; }) ;

    var containsStart = new Ext.form.TextField({
      id: 'clause1ValStart',
      renderTo: 'clause1Start',
      width: 22,
      allowBlank: false
    }) ;

    var containsStop = new Ext.form.TextField({
      id: 'clause1ValStop',
      renderTo: 'clause1Stop',
      width: 22,
      allowBlank: false
    }) ;

    // Clause case checkbox
    var clauseCase = new Ext.form.Checkbox({
      id: 'clause1CaseCheck',
      renderTo: 'clause1Case',
      boxLabel: 'Case Sensitive'
    }) ;

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
          var createBtn = Ext.get('createButton') ;
          var response = Ext.util.JSON.decode(resp.responseText) ;

          if(!createBtn)
          {
            return ;
          }

          if(!success)
          {
            // Error talking to the server, either way we can't validate name
            createBtn.dom.disabled = true ;
          }
          else
          {
            createBtn.dom.disabled = !(response.valid) ;
          }
        }
      }
    }) ;
    qNameField.on('invalid', function(field, msg) {
      // This could get called twice, but thats ok
      var createBtn = Ext.get('createButton') ;

      if(!createBtn)
      {
        return ;
      }

      createBtn.dom.disabled = true ;
    }) ;

    if((typeof(wbFormContext) !== 'undefined') && wbFormContext && wbFormContext.get('group') && wbFormContext.get('db'))
    {
      // Set the group/db to check when naming a query
      qNameField.rvOptions.params.group = wbFormContext.get('group') ;
      qNameField.rvOptions.params.db = wbFormContext.get('db') ;
    }
    qNameField.focus() ;

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
  }
)() ;
