// tabbedFileViewer.js - create the Ext.ux.LiveGrid for the tabbed file viewer
Ext.namespace('Genboree.Workbench') ;

Genboree.Workbench.TabbedFileViewer = function(grp, db, file, fields, cols, quickSort) {
  var intervalId = -1 ;
  var waitMsgBox = undefined ;
  var grp = grp ;
  var db = db ;
  var file = file ;
  var fields = fields ;
  var cols = cols ;
  var quickSort = quickSort ;
  var utils = new Genboree.Workbench.Utils.Upload() ;
  var uploadClass = '' ;
  var uploadType = '' ;
  var uploadSubtype = '' ;
  var uploadFormat = 'lff' ;

  var validCmps = {
    'klass': false,
    'type': false,
    'subtype': false
  } ;

  // Constants
  var okBtnId = 'okBtn' ;
  var BUFFER_SIZE = 500 ;
  var NEAR_LIMIT = 100 ;
  var HEIGHT = 400 ;
  var WIDTH = 600 ;
  var FIELDS = ['class', 'type', 'subtype'] ;

  return {
    init: function()
    {
      var that =  this ;

      // First, we up the Ext.Ajax timeout because creating an index could take longer
      // than 30 seconds. This is likely not the best way to solve that problem
      Ext.Ajax.timeout = 180000 ;

      var gridView = new Ext.ux.grid.livegrid.GridView(
      {
        nearLimit: NEAR_LIMIT,
        loadMask: 
        {
          msg: 'Buffering Data...'
        }
      }) ;

      var grid = new Ext.ux.grid.livegrid.GridPanel(
      {
        id: 'tabbedGrid',
        height: HEIGHT,
        width: WIDTH,
        stripeRows: true,
        title: 'Data',
        stateful: false,
        loadMask: 
        {
          msg: 'Loading Data...'
        },
        bbar: new Ext.ux.grid.livegrid.Toolbar(
        {
          view: gridView,
          displayInfo: true
        }),
        store: new Ext.ux.grid.livegrid.Store(
        {
          // TODO: If data file is too large, the AJAX load here will fail! Set the timeout higher
          autoLoad: false,
          bufferSize: BUFFER_SIZE,
          url: '/genboree/tabbedFileViewer/requestHandler.rhtml',
          baseParams:
          {
            grp: grp,
            db: db,
            file: file,
            srcFile: file,
            mode: 'data',
            quickSort: quickSort,
            userLogin: wbFormContext.get('userLogin'),
            total: -1
          },
          reader: new Ext.data.ArrayReader(
          {
            root: 'data',
            totalCount: 'total',
            fields: fields
          })
        }),
        cm: new Ext.grid.ColumnModel(
        {
          columns: cols,
          defaults:
          {
            align: 'left',
            sortable: true,
            width: 100
          }
        }),
        listeners:
        {
          afterrender: function(grid)
          {
            // Fix a Ext problem with the loadMask not showing on first load
            // Instead of autoload, manually show the mask then initiate the load
            grid.loadMask.show() ;
            grid.getStore().load() ;
          }
        },
        view: gridView,
        selModel: new Ext.ux.grid.livegrid.RowSelectionModel()
      }) ;

      gridView.on('buffer', function(bfGv, store, rowIndex, visRows, totalCount, options) 
      {
        // Check to see if we need to set the total property of the reader (so that it can be cached)
        // If we didn't cache it, then the server-side would need to read the whole data file to get a size (very costly)
        if(store.lastOptions.params.total === -1)
        {
          // NOTE: setBaseParam would be better here but there appears to be a bug in Ext
          store.lastOptions.params.total = totalCount
        }
        
        // Make sure our file is accurrate, if we sorted the new file != srcFile
        store.lastOptions.params.file = store.reader.arrayData.file ;
      }) ;

      if(!quickSort)
      {
        // We need to override the sort method so it does not try to do a remote AJAX load of huge datasets
        Ext.override(Ext.ux.grid.livegrid.Store, 
        {
          sort: function(fieldName, dir)
          {

            // Next inform the server we need to initiate a long sort
            // NOTE: Override code taken from original sort method of Ext.data.Store
            var field = this.fields.get(fieldName) ;
            if (!field) 
            {
              return false ;
            }

            var name = field.name ;
            var sortInfo = this.sortInfo || null ;
            var sortToggle = this.sortToggle ? this.sortToggle[name] : null ;

            if (!dir) 
            {
              if (sortInfo && sortInfo.field == name) 
              { 
                // toggle sort dir
                dir = (this.sortToggle[name] || 'ASC').toggle('ASC', 'DESC');
              } 
              else
              {
                dir = field.sortDir;
              }
            }

            Ext.Ajax.request(
            {
              url: '/genboree/tabbedFileViewer/requestHandler.rhtml',
              params: 
              { 
                mode: 'sort',
                quickSort: false,
                grp: grp,
                db: db,
                file: file,
                srcFile: file,
                userLogin: wbFormContext.get('userLogin'),
                userEmail: wbFormContext.get('userEmail'),
                sort: name,
                dir: dir
              },
              success: function(response)
              {
                var data = Ext.util.JSON.decode(response.responseText) ;
                
                // Setup our poll check for sort job completion - anonymous function so we can pass sortJob in IE
                intervalId = setInterval(function() { checkSortStatus(data.sortJob) ; }, 60000) ;

                // Set our grids store to the appropriate file so that if the UI is left open, reload will be correct
                Ext.ComponentMgr.get('tabbedGrid').getStore().setBaseParam('file', data.file) ;
                
                // Our sort is going, let the user know their options
                var info = '<div style="background-color: white ; padding: 5px ; border: 1px solid #6593CF ;">' +
                  '  <div style="border-bottom: 1px solid #6593CF ; font-weight: bold ; margin: -5px -5px 3px -5px ; padding: 5px ; background-color: #E9F0F8 ;">' +
                  '    The data is currently being sorted. You will receive an email when the sorting has completed.' +
                  '  </div>' +
                  '  You can either:' +
                  '  <ol style="list-style: decimal ; margin: 5px 0 0 20px ;">' +
                  '    <li style="margin-bottom: 5px ;">' +
                  '      Leave this window open and wait for the sorting to complete, at which time the table will' +
                  '      be updated with the sorted records' +
                  '    </li>' +
                  '    <li>' +
                  '      Or you can press the <i>\'Close Tabbed File Viewer\'</i> button below to close the Tabbed File Viewer and return ' +
                  '      to the workbench. The sorting will continue and you can view the sorted results at a later time' +
                  '    </li>' +
                  '  </ol>' +
                  '</div>' ;
                waitMsgBox = Ext.Msg.show(
                {
                  buttons: 
                  { 
                    ok: 'Close Tabbed File Viewer' 
                  },
                  closable: true,
                  fn: function()
                  {
                    Ext.ComponentMgr.get('wbToolSettingsWin').close() ;
                    if(intervalId !== -1)
                    {
                      clearInterval(intervalId) ;
                    }
                  },
                  msg: info,
                  wait: true,
                  waitConfig: 
                  {
                    animate: true,
                    interval: 250,
                    increment: 30,
                    text: 'Sorting Records...'
                  }
                }) ;
              },
              failure: function(response)
              {
                var err = '<div class="wbDialog" style="height: auto ; width: auto ; padding: 0 ;">' +
                  '  <div class="wbDialogFeedback wbDialogFail" style="margin: 0 ; ">' +
                  '    An error occurred while attempting to sort your data. Please contact ' +
                  '    <a href="mailto:' + wbFormContext.get('gbAdminEmail') + '">' + 
                       wbFormContext.get('gbAdminEmail') + '</a> and alert them of the following error: ' +
                  '    <div>' +
                  '      <b>Error</b>: (' + response.status + ') ' + response.statusText +
                  '    </div>' +
                  '  </div>' +
                  '</div>' ;
                Ext.Msg.alert('Sort Error', err, function() { Ext.ComponentMgr.get('wbToolSettingsWin').close() ; }) ;
              }
            }) ;
          }
        }) ;
      }

      var typeCombo = new Ext.form.ComboBox({
        id: 'dataSelect',
        allowBlank: false,
        typeAhead: true,
        triggerAction: 'all',
        transform: 'dataSelectHolder',
        forceSelection: true,
        width: 160,
        listeners:
        {
          'select': function(cb, rec, ind) {
            that.setFormat(cb.getValue()) ;
          },
          'change': function(cb, newVal, oldVal) {
            that.setFormat(newVal) ;
          }
        }
      }) ;

      var saveCombo = new Ext.form.ComboBox({
        id: 'saveLoc',
        allowBlank: false,
        typeAhead: true,
        triggerAction: 'all',
        transform: 'saveLocHolder',
        forceSelection: true,
        width: 160,
        disabled: (wbFormContext.get('tracks').length <= 0),
        listeners:
        {
          'select': function(cb, rec, ind) {
            that.toggleTrackOpts(cb.getValue()) ;
          },
          'change': function(cb, newVal, oldVal) {
            that.toggleTrackOpts(newVal) ;
          }
        }
      }) ;

      var trackCombo = new Ext.form.ComboBox({
        id: 'track',
        renderTo: 'tracksHolder',
        allowBlank: false,
        typeAhead: true,
        triggerAction: 'all',
        forceSelection: true,
        width: 160,
        mode: 'local',
        listeners:
        { 
          'select': function(cb, rec, ind) {
            that.selectExistingTrack(rec) ;
          },
          'change': function(cb, newVal, oldVal) {
            var rec = cb.findRecord('name', newVal) ;
            if(rec)
            { 
              that.selectExistingTrack(rec) ;
            }
          }
        },
        store: new Ext.data.ArrayStore({
          id: 0,
          fields:
          [ 
            'id',
            'name',
            'class'
          ],
          data: wbFormContext.get('tracks')
        }),
        valueField: 'name',
        displayField: 'name'
      }) ;
      if(wbFormContext.get('tracks').length > 0)
      {
        trackCombo.setValue(wbFormContext.get('tracks')[0][1]) ;
      }

      // Create our class, type and subtype textfields, use Ext for its simple validation
      var classField = new Ext.form.TextField({
        id: 'class',
        renderTo: 'classHolder',
        allowBlank: false,
        blankText: 'You must specify an annotation class',
        listeners:
        {
          'valid': function() {
            validCmps.klass = true ;

            // Now check all our other components to determine if submit button is ok
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'invalid': function() {
            validCmps.klass = false ;
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'blur': function(field) {
            that.setClass(field.getValue()) ;
          }
        },
        width: 160,
        style: { cssFloat: 'left', styleFloat: 'left' }
      }) ;

      var typeField = new Ext.form.TextField({
        id: 'type',
        renderTo: 'typeHolder',
        allowBlank: false,
        enableKeyEvents: true,
        blankText: 'You must specify an annotation type',
        validator: function(value) {
          return utils.trackNameValidator(value, 'subtype') ;
        },
        listeners:
        {
          'keyup': function() {
            utils.updateTrackSpan('trackNameSpan', 'type', 'subtype') ;
          },
          'invalid': function() {
            validCmps.type = false ;
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'valid': function() {
            validCmps.type = true ;
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'blur': function(field) {
            that.setType(field.getValue()) ;
          }
        },
        width: 160,
        style: { cssFloat: 'left', styleFloat: 'left' }
      }) ;
      
      var subtypeField = new Ext.form.TextField({
        id: 'subtype',
        renderTo: 'subtypeHolder',
        allowBlank: false,
        enableKeyEvents: true,
        blankText: 'You must specify an annotation subtype',
        validator: function(value) {
          return utils.trackNameValidator(value, 'type') ;
        },
        listeners:
        {
          'keyup': function() {
            utils.updateTrackSpan('trackNameSpan', 'type', 'subtype') ;
          },
          'invalid': function() {
            validCmps.subtype = false ;
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'valid': function() {
            validCmps.subtype = true ;
            utils.setButtonStatus(okBtnId, validCmps) ;
          },
          'blur': function(field) {
            that.setSubtype(field.getValue()) ;
          }
        },
        width: 160,
        style: { cssFloat: 'left', styleFloat: 'left' }
      }) ;

      // Render our grid to the DOM element
      grid.render('grid') ;
    },
    checkSortStatus: function(sortJob)
    {
      // Now fire off the remote long sort
      Ext.Ajax.request(
      {
        url: '/genboree/tabbedFileViewer/requestHandler.rhtml',
        params: 
        { 
          mode: 'status',
          userLogin: wbFormContext.get('userLogin'),
          sortJob: sortJob
        },
        success: function(response)
        {
          var data = Ext.util.JSON.decode(response.responseText) ;

          if(!data.running && intervalId !== -1)
          {
            clearInterval(intervalId) ;

            // If the tabbedGrid component is still around, the user left it open, so reload
            if(waitMsgBox)
            {
              waitMsgBox.hide() ;
              waitMsgBox = undefined ;
            }

            var tabbedGrid = undefined ;
            if((tabbedGrid = Ext.ComponentMgr.get('tabbedGrid')))
            {
              tabbedGrid.getStore().load() ;
            }
          }
        }
      }) ;
    },
    toggleUploadSpec: function(show)
    {
      var el = Ext.get('uploadInfo') ;
      var btn = Ext.get('okBtn') ;
      var type = Ext.getCmp('type') ;
      var subtype = Ext.getCmp('subtype') ;

      if(!el || !btn || !type || !subtype)
      {
        return false ;
      }

      if(show)
      {
        el.slideIn('t', { useDisplay: true, callback: function() {
          // Attempt to give our necessary type field
          var type = undefined ;
          if((type = Ext.get('trackType')))
          {
            type.focus() ;
          }
        }}) ;

        // Lastly, check to see if our OK button should be enabled
        if(type.getValue() !== '' && subtype.getValue() !== '')
        {
          btn.dom.disabled = false ;
        }
        else
        {
          btn.dom.disabled = true ;
        }
      }
      else
      {
        el.slideOut('t', { useDisplay: true }) ;
        
        // We are not uploading, so OK is always enabled
        btn.dom.disabled = false ;
      }

      return true ;
    },
    toggleTrackOpts: function(opt)
    {
      var newTrackOpts = Ext.get('newTrackOpts') ;
      var existingTrackOpts = Ext.get('existingTrackOpts') ;

      if(!newTrackOpts || !existingTrackOpts)
      { 
        return false ;
      }

      newTrackOpts.setVisibilityMode(Ext.Element.DISPLAY).setVisible(opt === 'newTrack') ;
      existingTrackOpts.setVisibilityMode(Ext.Element.DISPLAY).setVisible(opt === 'existingTrack') ;

      if(opt === 'newTrack')
      {
        this.setClass(Ext.getCmp('class').getValue()) ;
        this.setType(Ext.getCmp('type').getValue()) ;
        this.setSubtype(Ext.getCmp('subtype').getValue()) ;
        utils.updateTrackSpan('trackNameSpan', 'type', 'subtype') ;
        utils.setButtonStatus(okBtnId, validCmps) ;
      }
      else
      {
        var cb = undefined ;
        var rec = undefined ;

        if((cb = Ext.getCmp('track')) && (rec = cb.findRecord('name', cb.getValue())))
        {
          this.selectExistingTrack(rec) ;
        }
      }

      return true ;
    },
    setType: function(type)
    {
      uploadType = type ;
    },
    getType: function()
    {
      return uploadType ;
    },
    setSubtype: function(subtype)
    {
      uploadSubtype = subtype ;
    },
    getSubtype: function()
    {
      return uploadSubtype ;
    },
    setClass: function(klass)
    {
      uploadClass = klass ;
    },
    getClass: function()
    {
      return uploadClass ;
    },
    setFormat: function(format)
    {
      uploadFormat = format
    },
    getFormat: function()
    {
      return uploadFormat ;
    },
    selectExistingTrack: function(rec)
    { 
      if(typeof(rec) !== 'object' || typeof(rec.get) === 'undefined')
      { 
        return false ;
      }

      var track = [] ;
      var name = rec.get('name') ;
      var tClass = rec.get('class') ;

      if(tClass && name && (name.split(':').length === 2))
      { 
        track = name.split(':') ;
        this.setClass(tClass) ;
        this.setType(track[0]) ;
        this.setSubtype(track[1]) ;
      }

      // Our OK button needs to be enabled if we are selecting an existing track
      Ext.fly(okBtnId).dom.disabled = false ;

      return true ;
    },
    processOkBtn: function() 
    {
      var uploadCheck = Ext.get('uploadEnable') ;
      if(uploadCheck && uploadCheck.dom.checked)
      {
        // First, set our variables in the context obj
        this.setUploadContext() ;
        
        // Now submit
        var form = Ext.get('wbDialogForm').dom ;
        submitToolJob(form) ;
      }
      else
      {
        closeToolWindows() ;
      }
    },
    setUploadContext: function()
    {
      var extraOpts = {} ;
      var specOpts = $H(wbFormContext.get('specOpts')) ;
      extraOpts['class'] = this.getClass() ;
      extraOpts['type'] = this.getType() ;
      extraOpts['subtype'] = this.getSubtype() ;

      // Get rid of our tracks, we dont need to send those back to the server on upload
      wbFormContext.unset('tracks') ;

      // Update our specOpts hash to add our final options
      specOpts.set('extraOptions', extraOpts) ;
      wbFormContext.update({'specOpts': specOpts.toObject()}) ;

      // Set our variables in the context so they are passed to the server
      wbFormContext.set('inputFormat', this.getFormat()) ;

      // If we are an LFF formatted file, send some info so we can set the proper type, subtype for new annots
      if(this.getFormat() === 'lff')
      {
        var lffInfo = {} ;
        var rec = Ext.ComponentMgr.get('tabbedGrid').store.getAt(0) ;
        lffInfo['oldClass'] = rec.json[0] ;
        lffInfo['oldType'] = rec.json[2] ;
        lffInfo['oldSubtype'] = rec.json[3] ;

        wbFormContext.set('lffInfo', lffInfo) ;
      }

      // Indicate or mode to the server (and rules helper)
      wbFormContext.set('mode', 'upload') ;
    }
  }
}
