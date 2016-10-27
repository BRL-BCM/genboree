Ext.namespace('Genboree.Workbench') ;

Genboree.Workbench.UploadAnnotations = function() {
  var format = undefined ;
  var klass = undefined ;
  var type = undefined ;
  var subtype = undefined ;
  var okBtnId = 'okBtn' ;
  var agilentOpts = {
    'histogram': false,
    'segment': false,
    'minProbes': 2,
    'threshold': 2.0,
    'segType': 'segmentStddev'
  } ;

  var validCmps = {
    'klass': true,
    'type': true,
    'subtype': true  
  } ;
  
  // Hash our formats for easy fill of inputs
  var formats = { 
    'lff'     : { 'klass' : '', 'type' : '', 'subtype': ''},
    'blat'    : { 'klass' : 'Hits', 'type' : 'Blat', 'subtype' : 'Hit'},
    'blast'   : { 'klass' : 'Hits', 'type' : 'Blast', 'subtype' : 'Hit'},
    'wig'     : { 'klass' : '', 'type' : 'myHDTrack', 'subtype' : '1'},
    'agilent' : { 'klass' : 'Agilent', 'type' : 'Agilent', 'subtype' : 'Probe'},
    'pash'    : { 'klass' : 'Hits', 'type' : 'Pash', 'subtype' : 'Hit'}
  } ;

  // Instantiate our utils class
  var utils = new Genboree.Workbench.Utils.Upload() ;

  return {
    init: function ()
    {
      var that = this ;
      
      // Place our ext elements - Use the textfields for the validation purposes and comboboxes for convenience
      // We convert our select elements to comboboxes to match the style of the Existing Track Combobox, merely aesthetics not for necessity
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
            that.changeFormat(cb.getValue()) ;
          },
          'change': function(cb, newVal, oldVal) {
            that.changeFormat(newVal) ;
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

      var classField = new Ext.form.TextField({
        id: 'class',
        renderTo: 'classHolder',
        allowBlank: false,
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
      
      var probesSpinner = new Ext.ux.form.SpinnerField({
        id: 'probes',
        renderTo: 'probesHolder',
        allowBlank: false,
        disabled: true,
        minValue: 2,
        defaultValue: 2,
        incrementValue: 1,
        alternateIncrementValue: 5,
        allowDecimals: false,
        splitterClass: '',
        listeners:
        {
          'blur': function(field) {
            if(!field.isValid())
            {
              // Force an acceptable value, set to default if the user clears the field
              field.clearInvalid() ;
              field.setRawValue('2') ;
            }

            // This will potentially get called unnecessarily, but we can't do it on the 'change' event
            // because of the potential of having invalid values in there, here we are assured a good value
            that.setAgilentOpt('minProbes', field.getValue()) ;
          },
          'spin': function(event) {
            that.setAgilentOpt('minProbes', event.field.getValue()) ;
          }
        },
        style: { width: '50px' }
      }) ;
      probesSpinner.setRawValue('2') ;
      
      var logSpinner = new Ext.ux.form.SpinnerField({
        id: 'logThresh',
        renderTo: 'logThreshHolder',
        allowBlank: false,
        disabled: true,
        minValue: 0,
        defaultValue: 2.0,
        incrementValue: 0.1,
        decimalPrecision: 2,
        alternateIncrementValue: 0.5,
        splitterClass: '',
        listeners:
        {
          'blur': function(field) {
            if(!field.isValid())
            {
              // Force an acceptable value, set to default if the user clears the field
              field.clearInvalid() ;
              field.setRawValue('2.0') ;
            }
            
            // This will potentially get called unnecessarily, but we can't do it on the 'change' event
            // because of the potential of having invalid values in there, here we are assured a good value
            that.setAgilentOpt('threshold', field.getValue()) ;
          },
          'spin': function(event) {
            that.setAgilentOpt('threshold', event.field.getValue()) ;
          }
        },
        style: { width: '50px' }
      }) ;
      logSpinner.setRawValue('2.0') ;

      // On load, our default format is lff
      this.setFormat('lff') ;
    },
    // Getters and Setters
    setFormat: function(fmt)
    {
      format = fmt ;
    },
    getFormat: function()
    {
      return format ;
    },
    setClass: function(cls)
    {
      klass = cls ;
    },
    getClass: function()
    {
      return klass ;
    },
    setType: function(tp)
    {
      type = tp ;
    },
    getType: function()
    {
      return type ;
    },
    setSubtype: function(st)
    {
      subtype = st ;
    },
    getSubtype: function()
    {
      return subtype ;
    },
    setAgilentOpt: function(key, val)
    {
      agilentOpts[key] = val ;
    },
    getAgilentOpt: function(key)
    {
      return agilentOpts[key] ;
    },
    getAgilentOpts: function()
    {
      return agilentOpts ;
    },
    // Utiltiy methods
    changeFormat: function(dataType)
    {
      var trackInfo = Ext.get('trackInfo') ;
      var classCmp = Ext.getCmp('class') ;
      var typeCmp = Ext.getCmp('type') ;
      var subtypeCmp = Ext.getCmp('subtype') ;
      var agilentOpts = Ext.get('agilentOpts') ;

      // Do some sanity checks first
      if(!trackInfo || !classCmp || !typeCmp || !subtypeCmp || !agilentOpts)
      {
        return false ;
      }

      // Set our components to the values for the selected type
      classCmp.setRawValue(formats[dataType].klass) ;
      typeCmp.setRawValue(formats[dataType].type) ;
      subtypeCmp.setRawValue(formats[dataType].subtype) ;

      // Hide or show our elements based on the type - Ext components
      classCmp.setVisible((dataType !== 'lff' && dataType !== 'wig')).clearInvalid() ;
      typeCmp.setVisible((dataType !== 'lff')).clearInvalid() ;
      subtypeCmp.setVisible((dataType !== 'lff')).clearInvalid() ;

      // Ext Elements
      trackInfo.setVisibilityMode(Ext.Element.DISPLAY).setVisible((dataType !== 'lff')) ;
      agilentOpts.setVisibilityMode(Ext.Element.DISPLAY).setVisible((dataType === 'agilent')) ;

      this.setFormat(dataType) ;
      // Update our track name to the user - if we are creating a new track
      if(Ext.getCmp('saveLoc').getValue() === 'newTrack')
      {
        this.setClass(formats[dataType].klass) ;
        this.setType(formats[dataType].type) ;
        this.setSubtype(formats[dataType].subtype) ;
        utils.updateTrackSpan('trackNameSpan', 'type', 'subtype') ;
      }

      return true ;
    },
    toggleSegOpts: function(visible)
    {
      var probes = Ext.getCmp('probes') ;
      var log = Ext.getCmp('logThresh') ;
      var tDev = Ext.get('threshStdDev') ;
      var tAbs = Ext.get('threshAbsolute') ;

      if(!probes || !log || !tDev || !tAbs)
      {
        return false ;
      }

      probes.setDisabled(!visible) ;
      log.setDisabled(!visible) ;
      tDev.dom.disabled = !visible ;
      tAbs.dom.disabled = !visible ;
      this.setAgilentOpt('segment', visible) ;
      
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

      return true ;
    },
    setUploadContext: function() 
    {
      var extraOpts = {} ;
      var specOpts = $H(wbFormContext.get('specOpts')) ;
      extraOpts['class'] = this.getClass() ;
      extraOpts['type'] = this.getType() ;
      extraOpts['subtype'] = this.getSubtype() ;

      // Detect if we have any extra options that need sending
      if(this.getFormat() === 'agilent')
      {
        // Set if we should create the histogram
        if(this.getAgilentOpt('histogram'))
        {
          extraOpts['histogram'] = null ;
        }

        // If we are supposed to segment, set our opts for that (minProbes, thresh)
        if(this.getAgilentOpt('segment'))
        {
          extraOpts['minProbes'] = this.getAgilentOpt('minProbes') ;
          extraOpts[this.getAgilentOpt('segType')] = this.getAgilentOpt('threshold') ;
        }
      }
      else if(this.getFormat() === 'wig')
      {
        specOpts.set('trackName', this.getType() + ':' + this.getSubtype()) ;
      }

      // Update our specOpts hash to add our final options
      specOpts.set('extraOptions', extraOpts) ;
      wbFormContext.update({'specOpts': specOpts.toObject()}) ;

      // Set our variables in the context so they are passed to the server
      wbFormContext.set('inputFormat', this.getFormat()) ;
      // Throttle? Wiggle Record Type? (No support for these from upload.jsp/upload.rhtml)
    }
  } // END Closure
}   // END Genboree.Workbench.UploadAnnotations
