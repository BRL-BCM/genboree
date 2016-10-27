Ext.namespace('Genboree.Workbench.Utils') ;

Genboree.Workbench.Utils.Upload = function() {
  return {
    trackNameValidator: function(value, sibField)
    {
      var retVal = true ;

      if(value.indexOf(':') !== -1)
      {
        retVal = 'The track name cannot contain \':\'' ;
      }
      else
      {
        // Check our total track length
        sibField = Ext.getCmp(sibField) ;
        if(sibField && sibField.getValue())
        {
          if(value.length + sibField.getValue().length > 18)
          {
            // Returning a string from retVal will make the field that called the validator be marked invalid,
            // but we need to also mark our sibling field as invalid since this error applies to both fields
            retVal = 'The resulting track name must be less than 19 characters' ;
            sibField.markInvalid(retVal) ;
          }
          else if(sibField.getValue().indexOf(':') !== -1)
          {
            sibField.markInvalid('The track name cannot contain \':\'') ;
          }
          else
          {
            sibField.clearInvalid() ;
          }
        }
      }
      
      return retVal ;
    },
    setButtonStatus: function(btnId, reqOpts)
    {
      var subDisabled = false ;

      for(opt in reqOpts)
      {
        if(reqOpts.hasOwnProperty(opt))
        {
          if(!reqOpts[opt])
          {
            subDisabled = true ;
            break ;
          }
        }
      }
              
      Ext.fly(btnId).dom.disabled = subDisabled ;
    },
    updateTrackSpan: function(tsId, ttId, tstId)
    {
      var trackName = '' ;
      var trackSpan = Ext.get(tsId) ;
      var trackType = Ext.getCmp(ttId) ;
      var trackSubtype = Ext.getCmp(tstId) ;

      if(!trackSpan || !trackType || !trackSubtype)
      {
        return false ;
      }

      // Update our span with the new name
      trackSpan.update(trackType.getValue() + ':' + trackSubtype.getValue()) ;

      return true ;
    }
  }
}
