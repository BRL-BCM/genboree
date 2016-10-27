// BooleanQueryUI.js - Common boolean query functions
BooleanQueryUI = function() {
  /** Some vars **/
  var rootClauseList = 'clauseList' ;
  var querySummaryDiv = 'queryCode' ;
  var nextClauseIndex = 2 ;
  var nextNestIndex = 1 ;
  var nestOffset = 7 ;
  var ieNestWidthCorr = 35 ;
  var userId = -1 ;
  var userLogin = '' ;
  var userEmail = '' ;
  var userAccess = '' ;
  var queryUserId = -1 ;
  var queryMode = '' ;
  var origQueryName = '' ;
  var group = '' ;
  var db = '' ;
  var template = '' ;
  var queryDetails = {} ;
  var groups = [] ;
  var dbs = [] ;
  var tracks = [] ;
  var queries = [] ;
  var templates = { resources: [] } ;
  var ops = [
    ['>', '>'],
    ['<', '<'],
    ['==', '='],
    ['>=', '>='],
    ['<=', '<='],
    ['=~', '=~'],
    ['contains', 'is between'],
    ['startsWith', 'starts with'],
    ['endsWith', 'ends with'],
    ['has', 'has']
  ] ;

  var rsrcs = [
    ['trks', 'Tracks'],
    ['annos', 'Annotations'],
    ['annotInTrack', 'Annotations in a Track'],
    ['experiments', 'Experiments'],
    ['publications', 'Publications'],
    ['runs', 'Runs'],
    ['analyses', 'Analyses'],
    ['studies', 'Studies'],
    ['bioSamples', 'Biosamples']
  ] ;

  return {
    /** Methods **/
    insertClause: function(parentId) {
      // Setup our params, we are adding a new clause, so no values to prime...
      var opts = {
        show: false,
        append: false,
        animate: true,
        bool: (Ext.fly(parentId + 'And').hasClass('selected')) ? 'and' : 'or'
      } ;

      this.createClauseEl(parentId, opts) ;
      this.updateQuerySummary() ;
    },
    appendClause: function(parentId) {
      // Setup our params, we are adding a new clause, so no values to prime...
      var firstClause = Ext.get(parentId).first('li.clauseContainer') ;
      var opts = {
        show: false,
        append: true,
        animate: true
      } ;

      if(firstClause)
      {
        opts.bool = (Ext.fly(firstClause.id + 'And').hasClass('selected')) ? 'and' : 'or' ;
      }

      this.createClauseEl(parentId, opts) ;
      this.updateQuerySummary() ;
    },
    createClauseEl: function(parentId, clauseParams, clauseValues) {
      // First create our HTML fragment
      var id = 'clause' + nextClauseIndex ;
      var elems = [] ;

      // Establish some config options:
      clauseParams = clauseParams || {} ;
      clauseValues = clauseValues || {} ;

      if(!Ext.fly(parentId))
      {
        return false ;
      }

      // Need visibility: hidden because display: none causes a size issue, also because of visibility must use Ext.fadeIn instead of scriptaculous
      elems.push('<li id="' + id + '" class="clauseContainer" ' + ((clauseParams.show) ? '' : 'style="visibility: hidden ;"') + '>') ;
      elems.push('  <div class="clauseTools">') ;
      elems.push('    <div id="' + id + 'Opts">') ;
      elems.push('      <a href="#" onclick="BHI.nestClause(\'' + id + '\') ; return false ;" class="nestButton" title="Nest Clause">N</a>') ;
      elems.push('      <a href="#" onclick="BHI.unnestClause(\'' + id + '\') ; return false ;" class="unnestButton" title="Unnest Clause">U</a>') ;
      elems.push('      <a href="#" onclick="BHI.insertClause(\'' + id + '\') ; return false ;" class="addClauseButton" title="Add Clause">A</a>') ;
      elems.push('      <a href="#" onclick="BHI.deleteClause(\'' + id + '\') ; return false ;" class="deleteClauseButton" title="Delete Clause">D</a>') ;
      elems.push('    </div>') ;
      elems.push('    <div id="' + id + 'Case" class="checkbox"></div>') ;
      elems.push('  </div>') ;
      elems.push('  <div id="' + id + 'Specs" class="clauseSpecs">') ;
      elems.push('    <div id="' + id + 'Attr"></div>') ;
      elems.push('    <a id="' + id + 'Not" href="#" onclick="Ext.get(this).toggleClass(\'selected\') ; BHI.updateQuerySummary() ; return false ;" class="not' + ((clauseParams.not) ? ' selected' : '') + '">NOT</a>') ;
      elems.push('    <div id="' + id + 'Op"></div>') ;
      elems.push('    <div id="' + id + 'Val" ' + ((clauseValues.contains) ? 'style="display: none ;"' : '') + '></div>') ;
      elems.push('    <div id="' + id + 'Contains" class="contains" ' + ((clauseValues.contains) ? '' : 'style="display: none ;"') + '>') ;
      elems.push('      <a id="' + id + 'Left" href="#" class="lBrace" onclick="BHI.toggleBrace(Ext.get(this)); BHI.updateQuerySummary() ; return false;" >[</a>') ;
      elems.push('      <div id="' + id + 'Start" style="margin-right:5px"></div>') ;
      elems.push('      <span id="' + id + 'Comma" style="line-height:24px; margin-right:3px;">,</span>') ;
      elems.push('      <div id="' + id + 'Stop"></div>') ;
      elems.push('      <a id="' + id + 'Right" href="#" class="rBrace" onclick="BHI.toggleBrace(Ext.get(this)); BHI.updateQuerySummary() ; return false;">]</a>') ;
      elems.push('    </div>') ;
      elems.push('  </div>') ;
      elems.push('  <div id="' + id + 'Bool" class="boolOps">') ;
      if(clauseParams.bool)
      {
        var and = (clauseParams.bool.toLowerCase() === 'and') ;
        elems.push('    <div id="' + id + 'BoolDyn" style="display: none ;">') ;
        elems.push('      <a href="#" id="' + id + 'And" class="and ' + ((and) ? 'selected' : '') + '" onclick="BHI.setBoolOp(\'' + id + '\') ; return false ;">AND</a>') ;
        elems.push('      <a href="#" id="' + id + 'Or" class="or ' + ((!and) ? 'selected' : '') + '" onclick="BHI.setBoolOp(\'' + id + '\') ; return false ;">OR</a>') ;
        elems.push('    </div>') ;
        if(and)
        {
          elems.push('    <img id="' + id + 'BoolStat" src="/images/query/and_disabled.png" alt="AND" style="display: none ;">') ;
        }
        else
        {
          elems.push('    <img id="' + id + 'BoolStat" src="/images/query/or_disabled.png" alt="OR" style="display: none ;">') ;
        }
      }
      else
      {
        elems.push('    <div id="' + id + 'BoolDyn" style="display: none ;">') ;
        elems.push('      <a href="#" id="' + id + 'And" class="and selected" onclick="BHI.setBoolOp(\'' + id + '\') ; return false ;">AND</a>') ;
        elems.push('      <a href="#" id="' + id + 'Or" class="or" onclick="BHI.setBoolOp(\'' + id + '\') ; return false ;">OR</a>') ;
        elems.push('    </div>') ;
        elems.push('    <img id="' + id + 'BoolStat" src="/images/query/and_disabled.png" alt="AND" style="display: none ;">') ;
      }
      elems.push('  </div>') ;
      elems.push('</li>') ;

      // Next, add the HTML to our parent
      var clauseEl = null ;
      if(clauseParams.append)
      {
        clauseEl = Ext.DomHelper.append(parentId, elems.join(''), true) ;
      }
      else
      {
        clauseEl = Ext.DomHelper.insertAfter(parentId, elems.join(''), true) ;
      }

      // Lastly, create our Ext Widgets and show them if necessary
      this.createClauseExtWidgets(id, clauseValues) ;
      this.setBoolVisForList('clauseList') ;

      if(clauseParams.animate)
      {
        clauseEl.fadeIn({ duration: 0.5, useDisplay: true }) ;
      }

      // Make sure we indicate a clause was added
      nextClauseIndex++ ;

      return true ;
    },
    createClauseExtWidgets: function(clauseId, values) {
      var prevSib = undefined ;

      if(!Ext.fly(clauseId))
      {
        return false ;
      }

      // First, we need to translate our ExtJS elements to ExtJS components
      var attrCombo = new Ext.form.ComboBox({
        id: clauseId + 'AttrCombo',
        renderTo: clauseId + 'Attr',
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
      attrCombo.on('blur', this.updateQuerySummary, this) ;
      if(this.getTemplate())
      {
        this.getAttrs(this.getTemplate(), attrCombo) ;
      }

      var opCombo = new Ext.form.ComboBox({
        id: clauseId + 'OpCombo',
        renderTo: clauseId + 'Op',
        store: ops,
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
        'blur': { fn: this.updateQuerySummary, scope: this },
        'select': { fn: function(cb, rec, index) { this.setOpEl(cb, rec, index) ; }, scope: this }
      }) ;

      var valField = new Ext.form.TextField({
        id: clauseId + 'ValField',
        renderTo: clauseId + 'Val',
        allowBlank: false,
        width: 115,
        style: { cssFloat: 'left', styleFloat: 'left' }
      }) ;
      valField.on('blur', this.updateQuerySummary, this) ;

      var containsStart = new Ext.form.TextField({
        id: clauseId + 'ValStart',
        renderTo: clauseId + 'Start',
        width: 22,
        allowBlank: false
      }) ;
      containsStart.on('blur', this.updateQuerySummary, this) ;

      var containsStop = new Ext.form.TextField({
        id: clauseId + 'ValStop',
        renderTo: clauseId + 'Stop',
        width: 22,
        allowBlank: false
      }) ;
      containsStop.on('blur', this.updateQuerySummary, this) ;

      var caseCheck = new Ext.form.Checkbox({
        id: clauseId + 'CaseCheck',
        renderTo: clauseId + 'Case',
        boxLabel: 'Case Sensitive'
      }) ;

      if(values)
      {
        // Clause Attribute
        attrCombo.setValue(values.attribute) ;

        // Clause Operator
        var op = values.op || '' ;
        if((op.indexOf('[') !== -1) || (op.indexOf('(') !== -1))
        {
          opCombo.setValue('contains') ;
        }
        else
        {
          opCombo.setValue(op) ;
        }

        // Clause Values based on the operator
        if((op.indexOf('[') === -1) && (op.indexOf('(') === -1))
        {
          valField.setValue(values.value) ;
        }
        else
        {
          // Our contains block is initialized to [], so if we detect a '(' or ')' modify
          if(op.indexOf('(') !== -1)
          {
            Ext.fly(clauseId + 'Left').removeClass('lBrace').addClass('lParenth').update('(') ;
          }

          if(op.indexOf(')') !== -1)
          {
            Ext.fly(clauseId + 'Right').removeClass('rBrace').addClass('rParenth').update(')') ;
          }

          // Parse our values
          var clauseValues = values.value.split('..') ;
          if(clauseValues.length >= 2)
          {
            var start = (isNaN(clauseValues[0])) ? clauseValues[0].substring(1, clauseValues[0].length - 1) : clauseValues[0] ;
            var stop = (isNaN(clauseValues[1])) ? clauseValues[1].substring(1, clauseValues[1].length - 1) : clauseValues[1] ;
            Ext.getCmp(clauseId + 'ValStart').setValue(start) ;
            Ext.getCmp(clauseId + 'ValStop').setValue(stop) ;
          }
        }

        // Clause case
        if(values.kase)
        {
          caseCheck.setValue(true) ;
        }
      }

      return true ;
    },
    deleteClause: function(clause) {
      if(!(clause = Ext.get(clause)))
      {
        return false ;
      }

      // Fade out and remove, then hide previous AND/OR if necessary
      if(!clause.next() && !clause.prev() && clause.parent('li'))
      {
        // If we are the only clause in our list (nest), remove the list (nest)
        clause = clause.parent('li') ;
      }

      clause.fadeOut({
        remove: true,
        duration: 0.5,
        scope: this,
        callback: function() {
          this.setBoolVisForList('clauseList') ;

          // We changed the query, show the user in the text based query
          this.updateQuerySummary() ;
        }
      }) ;


      return true ;
    },
    nestClause: function(clause) {
      /**
       * Nesting a clause requires:
       * 1) Creating a new container for the nested clauses (ul)
       * 2) Visually indicating the nest (color and indent)
       * 3) Adding a new "+ Append Clause" button (needed in case of inner-nesting)
       * 4) Check if nest is already nested, alter background color if so
       **/
      var nestId = 'nest' + nextNestIndex ;
      if(!(clause = Ext.get(clause)))
      {
        return false ;
      }

      // If we are creating a nest, by def. we have no other clauses in the nest so no boolean relationship should be visible
      if(Ext.fly(clause.id + 'BoolDyn').isVisible())
      {
        Ext.fly(clause.id + 'BoolDyn').setVisibilityMode(Ext.Element.DISPLAY).hide() ;
      }
      else if(Ext.fly(clause.id + 'BoolStat').isVisible())
      {
        Ext.fly(clause.id + 'BoolStat').setVisibilityMode(Ext.Element.DISPLAY).hide() ;
      }

      // Wrap our clause LI in our ul and nest div, adding our append button
      var nest = clause.wrap({tag: 'ul', id: nestId}).wrap({tag: 'div', cls: 'nestContainer'}).wrap({tag: 'li', cls: 'nest'}) ;
      Ext.DomHelper.append(nest.first(), '<a href="#" class="appendClauseButton" onclick="BHI.appendClause(\'' + nestId + '\') ; return false ;">+ Append Clause</a>') ;

      // Create our AND/OR block for the nest as a whole (how it relates to clauses/nests after it)
      var boolRel = [] ;
      var andSelected = Ext.fly(clause.id + 'And').hasClass('selected') ;
      boolRel.push('<div id="' + nestId + 'Bool" class="boolOps nestBoolOps">') ;
      boolRel.push('  <div id="' + nestId + 'BoolDyn" style="display: none ;">') ;
      boolRel.push('    <a href="#" id="' + nestId + 'And" class="and ' + (andSelected ? 'selected' : '') + '" onclick="BHI.setBoolOp(\'' + nestId + '\') ; return false ;">AND</a>') ;
      boolRel.push('    <a href="#" id="' + nestId + 'Or" class="or ' + (andSelected ? '' : 'selected') + '" onclick="BHI.setBoolOp(\'' + nestId + '\') ; return false ;">OR</a>') ;
      boolRel.push('  </div>') ;
      boolRel.push('  <img id="' + nestId + 'BoolStat" src="/images/query/' + (andSelected ? 'and' : 'or') + '_disabled.png" alt="AND" style="display: none ;">') ;
      boolRel.push('</div>') ;
      Ext.DomHelper.append(nest, boolRel.join('')) ;

      // Indent
      if(Ext.isIE6 || Ext.isIE7)
      {
        // A dirty hack for IE (7 and below, 8 is fine) width calculations, the width is being calculated 
        // larger than it should be (dont think its a box model issue, but could be...)
        nest.shift({ x: (nest.getX() + nestOffset), width: (nest.getWidth() - ieNestWidthCorr), duration: 0.5 }) ;
      }
      else
      {
        nest.shift({ x: (nest.getX() + nestOffset), width: (nest.getWidth() - nestOffset), duration: 0.5 }) ;
      }

      // Check if we already exist in a nest, if so, alter our background color
      if(nest.up('li.nest'))
      {
        nest.first('.nestContainer').setStyle({ 'background-color': '#FFF' }) ;
      }

      if(nest.next())
      {
        // Our nest has something after it, so we need to show our boolean relationship to it
        this.setBoolVisForList('clauseList') ;
      }

      // Increment our nest index
      nextNestIndex++ ;

      // We changed the query, show the user in the text based query
      this.updateQuerySummary() ;

      return true ;
    },
    unnestClause: function(clause) {
      var parentNest = undefined ;
      if(!(clause = Ext.get(clause)) || !(parentNest = clause.parent('li')))
      {
        return false ;
      }

      /**
       * To Unnest:
       * 1. Move clause from its list (ul)
       * 2. Append clause to end of the nest (li)
       * 3. Shift clause back a nest level
       * 4. Insert clause after its old parent nest (li)
       *    a. If no clauses left in nest, remove nest (li)
       **/
      //clause.appendTo(parentNest.parent('li')) ;
      var removeNest = !clause.next() && !clause.prev() ;
  //    clause.shift({ y: parentNest.getY() + parentNest.getHeight(), duration: 0.5, concurrent: false }).shift({ x: clause.getX() - this.nestOffset, duration: 0.5, callback: function() { clause.insertAfter(parentNest) ; } }) ;
      // TODO: See if this can be made smoother
      clause.insertAfter(parentNest).alignTo(parentNest).shift({
        x: clause.getX() - nestOffset,
        duration: 0.5,
        afterStyle: { position: 'static' },
        continuous: false,
        scope: this,
        callback: function() {
          if(removeNest)
          {
            parentNest.fadeOut({
              remove: true,
              duration: 0.5,
              scope: this,
              callback: function() {
                if(clause.next())
                {
                  this.setBoolVisForList('clauseList') ;
                }
                
                // We changed the query, show the user in the text based query
                this.updateQuerySummary() ;
              }
            }) ;
          }
          else if(clause.next())
          {
            // Our clause has a clause after it, so show our boolean relationship to it
            this.setBoolVisForList('clauseList') ;
          
            // We changed the query, show the user in the text based query
            this.updateQuerySummary() ;
          }
        }
      }) ;

      return true ;
    },
    setBoolVisForList: function(listId) {
      if(!listId)
      {
        return false ;
      }

      var elements = Ext.DomQuery.select('#' + listId + ' > li') ;
      if(elements.length === 0)
      {
        return true ;
      }

      for(var count = 0 ; count < elements.length - 1 ; count++)
      {
        var element = Ext.get(elements[count]) ;
        var elToShow = (count === 0) ? element.id + 'BoolDyn' : element.id + 'BoolStat' ;
        var elToHide = (count !== 0) ? element.id + 'BoolDyn' : element.id + 'BoolStat' ;

        if(element.hasClass('nest'))
        {
          var nestId = element.select('ul').first().dom.id ;

          // Adjust our element to the nest boolean options, then have the nest set its childerns vis
          elToShow = (count === 0) ? nestId + 'BoolDyn' : nestId + 'BoolStat' ;
          elToHide = (count !== 0) ? nestId + 'BoolDyn' : nestId + 'BoolStat' ;
          this.setBoolVisForList(nestId) ;
        }

        Ext.fly(elToShow).setVisibilityMode(Ext.Element.DISPLAY).show() ;
        Ext.fly(elToHide).setVisibilityMode(Ext.Element.DISPLAY).hide() ;
      }

      // Make sure our last elements boolean is always hidden
      var lastElId = elements[count].id ;
      if(Ext.fly(elements[count]).hasClass('nest'))
      {
        // Our last element is a nest, so we need to make sure the nests clauses have the bool rel set
        lastElId = Ext.fly(elements[count]).select('ul').first().dom.id ;
        this.setBoolVisForList(lastElId) ;
      }
      Ext.fly(lastElId + 'BoolDyn').setVisibilityMode(Ext.Element.DISPLAY).hide() ;
      Ext.fly(lastElId + 'BoolStat').setVisibilityMode(Ext.Element.DISPLAY).hide() ;

      return true ;
    },
    setBoolOp: function(elId) {
      var and = Ext.fly(elId + 'Or').hasClass('selected') ;

      // Set our own bool operators
      if(and)
      {
        Ext.fly(elId + 'And').addClass('selected') ;
        Ext.fly(elId + 'Or').removeClass('selected') ;
        Ext.fly(elId + 'BoolStat').dom.src = '/images/query/and_disabled.png' ;

        // elId must be the master bool control for the nest, so set our siblings to our bool op
        $(elId).siblings().each(function(sib) {
          var clauseId = (sib.hasClassName('nest')) ? sib.down('ul').id : sib.id ;
          Ext.fly(clauseId + 'BoolStat').dom.src = '/images/query/and_disabled.png' ;
          Ext.fly(clauseId + 'And').addClass('selected') ;
          Ext.fly(clauseId + 'Or').removeClass('selected') ;
        }) ;
      }
      else
      {
        Ext.fly(elId + 'And').removeClass('selected') ;
        Ext.fly(elId + 'Or').addClass('selected') ;
        Ext.fly(elId + 'BoolStat').dom.src = '/images/query/or_disabled.png' ;

        // elId must be the master bool control for the nest, so set our siblings to our bool op
        $(elId).siblings().each(function(sib) {
          var clauseId = (sib.hasClassName('nest')) ? sib.down('ul').id : sib.id ;
          Ext.fly(clauseId + 'BoolStat').dom.src = '/images/query/or_disabled.png' ;
          Ext.fly(clauseId + 'And').removeClass('selected') ;
          Ext.fly(clauseId + 'Or').addClass('selected') ;
        }) ;
      }

      this.updateQuerySummary() ;

      return true ;
    },
    checkUserAccess: function(combo, record, index, params) {
      var that = this ;
      if(!params && !params.accessDiv)
      {
        return false ;
      }

      var escapedRestUri = '/REST/v1/grp/' + encodeURIComponent(combo.getValue()) + '/usr/' + encodeURIComponent(this.getUserLogin()) + '/role' ;
      new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent(escapedRestUri) + '&apiMethod=GET', {
        method: 'post',
        onSuccess: function(transport) {
          var grpAccess = Ext.get(params.accessDiv) ;
          var restData = transport.responseText.evalJSON() ;

          if(restData.data.role && (restData.data.role.toLowerCase() !== 'subscriber'))
          {
            grpAccess.hide() ;
            if(params.buttons && params.buttons instanceof Array)
            {
              params.buttons.each(function(button) {
                Ext.get(button).dom.disabled = false ;
              }) ;
            }
          }
          else if(grpAccess)
          {
            grpAccess.show() ;
            if(params.buttons && params.buttons instanceof Array)
            {
              params.buttons.each(function(button) {
                Ext.get(button).dom.disabled = true ;
              }) ;
            }
          }

          that.setUserAccess(restData.data.role.toLowerCase()) ;
        }
      }) ;
    },
    setUserAccess: function(access) {
      userAccess = access ;
    },
    getUserAccess: function() {
      return userAccess ;
    },
    getUserDbs: function(combo, record, index, params) {
      var that = this ;
      var dbs = [] ;
      var grp = record.get('text') ;
      var dbCombo = undefined ;
      var loading = undefined ;
      if(!params || !(dbCombo = Ext.getCmp(params.dbCombo)))
      {
        return ;
      }

      // Disbale our DB combo until we are done loading
      dbCombo.disable() ;
      loading = Ext.get(params.loading) ;
      if(loading)
      {
        loading.show() ;
      }

      var escapedRestUri = '/REST/v1/grp/' + encodeURIComponent(grp) + '/dbs' ;
      new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent(escapedRestUri) + '&method=GET', {
        method: 'post',
        onSuccess: function(transport) {
          var restData = transport.responseText.evalJSON() ;
          var record = Ext.data.Record.create([
            { name: 'text' }
          ]) ;

          dbCombo.store.removeAll() ;
          restData.data.each(function(db) {
            dbs.push(db.text) ;
            dbCombo.store.add(new record({ text: db.text })) ;
          }) ;

          // Select first item from new data store
          dbCombo.setValue(dbCombo.store.getAt(0).get('text')) ;

          // If we are given a track combo, then proceed to populate the tracks for this group/db
          if(params.trackCombo)
          {
            params.groupCombo = combo.id ;
            params.loading = 'trackLoading' ;
            that.getUserTracks(combo, record, index, params) ;
          }

          if(params.nameField)
          {
            var nameCmp = Ext.getCmp(params.nameField) ;
            nameCmp.rvOptions.params.group = grp ;
            nameCmp.rvOptions.params.db = dbCombo.getValue() ;
            //nameCmp.fireEvent('blur') ;
          }
        },
        onComplete: function() {
          if(loading)
          {
            loading.hide() ;
          }

          dbCombo.enable() ;
        }
      }) ;

      // Keep our dbs cache up to date
      this.setDbs(dbs) ;
    },
    getUserTracks: function(combo, record, index, params) {
      var tracks = [] ;
      var dbCombo = undefined ;
      var groupCombo = undefined ;
      var trackCombo = undefined ;
      var loading = undefined ;
      if(!params ||
         !(dbCombo = Ext.getCmp(params.dbCombo)) ||
         !(groupCombo = Ext.getCmp(params.groupCombo)) ||
         !(trackCombo = Ext.getCmp(params.trackCombo)) ||
         !dbCombo.getValue() || !groupCombo.getValue())
      {
        return ;
      }

      loading = Ext.get(params.loading) ;
      if(loading && trackCombo.isVisible())
      {
        loading.show() ;
      }

      var escapedRestUri = '/REST/v1/grp/' + encodeURIComponent(groupCombo.getValue()) + '/db/' + encodeURIComponent(dbCombo.getValue()) + '/trks' ;
      new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent(escapedRestUri) + '&method=GET', {
        method: 'post',
        onSuccess: function(transport) {
          var restData = transport.responseText.evalJSON() ;
          var record = Ext.data.Record.create([
            { name: 'text' }
          ]) ;

          trackCombo.store.removeAll() ;
          restData.data.each(function(track) {
            tracks.push(track.text) ;
            trackCombo.store.add(new record({ text: track.text })) ;
          }) ;

          // Select first item from new data store
          trackCombo.setValue(trackCombo.store.getAt(0).get('text')) ;
        },
        onComplete: function() {
          if(loading && trackCombo.isVisible())
          {
            loading.hide() ;
          }
        }
      }) ;

      // Keep our tracks up to date
      this.setTracks(tracks) ;
    },
    getGroups: function() {
      return groups ;
    },
    setGroups: function(newGroups) {
      groups = newGroups ;
    },
    getGroup: function() {
      return group ;
    },
    setGroup: function(newGroup) {
      group = newGroup ;
    },
    getDbs: function() {
      return dbs ;
    },
    setDbs: function(newDbs) {
      dbs = newDbs ;
    },
    getDb: function() {
      return db ;
    },
    setDb: function(newDb) {
      db = newDb ;
    },
    getTracks: function() {
      return tracks ;
    },
    setTracks: function(newTracks) {
      tracks = newTracks ;
    },
    getQueries: function() {
      return queries ;
    },
    setQueries: function(newQueries) {
      queries = newQueries ;
    },
    getQueryDetails: function() {
      return queryDetails ;
    },
    setQueryDetails: function(details) {
      if(typeof details === "object")
      {
        queryDetails = details ;
      }
    },
    getOps: function() {
      return ops ;
    },
    setOps: function(newOps) {
      ops = newOps ;
    },
    getAttrs: function(resource, cb) {
      // Search our templates to find the one selected
      // NOTE: resource is an Ext.Record!
      templates.each(function(rsrc) {
        if(rsrc.get('resource').toLowerCase() === resource.toLowerCase())
        {
          // Found the resource, now populate the store with attributes
          if(cb)
          {
            // A combobox was passed to us, only load attrs for that
            cb.store.removeAll() ;
            rsrc.get('attrs').each(function(attrHash, index) {
              for(var key in attrHash)
              {
                if(attrHash.hasOwnProperty(key))
                {
                  var rec = new cb.store.recordType({'attr' : key, 'display' : attrHash[key]}, index)
                  cb.store.add(rec) ;
                }
              }
            }) ;
          }
          else
          {
            // No combo specified, reload all our attr combos
            Ext.ComponentMgr.all.each(function(combo) {
              if(/AttrCombo/.test(combo.getId()))
              {
                combo.store.removeAll() ;
                rsrc.get('attrs').each(function(attrHash, index) {
                  for(var key in attrHash)
                  {
                    if(attrHash.hasOwnProperty(key))
                    {
                      var rec = new combo.store.recordType({'attr': key, 'display': attrHash[key]}, index) ;
                      combo.store.add(rec) ;
                    }
                  }
                }) ;
              }
            }) ;
          }

          throw $break ;
        }
      }) ;
    },
    getTemplates: function() {
      return templates ;
    },
    setTemplates: function(newTmpls) {
      templates = newTmpls ;
    },
    getTemplate: function() {
      return template ;
    },
    setTemplate: function(selectedTmpl) {
      template = selectedTmpl ;
    },
    getRsrcs: function() {
      return rsrcs ;
    },
    setRsrcs: function(newRsrcs) {
      rsrcs = newRsrcs ;
    },
    getQueryMode: function() {
      return queryMode ;
    },
    setQueryMode: function(newMode) {
      queryMode = newMode ;
    },
    getOrigQueryName: function() {
      return origQueryName ;
    },
    getQueryUserId: function() {
      return queryUserId ;
    },
    setQueryUserId: function(uId) {
      queryUserId = uId ;
    },
    getUserId: function() {
      return userId ;
    },
    setUserId: function(uId) {
      userId = uId ;
    },
    getUserLogin: function() {
      return userLogin ;
    },
    setUserLogin: function(login) {
      userLogin = login ;
    },
    getUserEmail: function() {
      return userEmail ;
    },
    setUserEmail: function(email) {
      userEmail = email ;
    },
    getQuerySummaryDiv: function() {
      return querySummaryDiv ;
    },
    setQuerySummaryDiv: function(id) {
      querySummaryDiv = id ;
    },
    setOpEl: function(cb, rec, index) {
      var operator = rec.get('value') ;
      var clause = cb.getId().split('OpCombo')[0] ;
      var textField = Ext.get(clause + 'Val').setVisibilityMode(Ext.Element.DISPLAY) ;
      var containsDiv = Ext.get(clause + 'Contains').setVisibilityMode(Ext.Element.DISPLAY) ;

      if(operator == "contains")
      {
        textField.hide() ;
        containsDiv.show() ;
      }
      else
      {
        textField.show() ;
        containsDiv.hide() ;
      }
    },
    toggleBrace: function(e) {
      if(!(e = Ext.get(e)))
      {
        return false ;
      }

      if(e.hasClass('lBrace'))
      {
        e.removeClass('lBrace') ;
        e.addClass('lParenth') ;
        e.update('(') ;
      }
      else if(e.hasClass('rBrace'))
      {
        e.removeClass('rBrace') ;
        e.addClass('rParenth') ;
        e.update(')') ;
      }
      else if(e.hasClass('lParenth'))
      {
        e.removeClass('lParenth') ;
        e.addClass('lBrace') ;
        e.update('[') ;
      }
      else if(e.hasClass('rParenth'))
      {
        e.removeClass('rParenth') ;
        e.addClass('rBrace') ;
        e.update(']') ;
      }
    },
    createQueryObj: function(rootNode) {
      var query = [] ;

      if(rootNode === undefined)
      {
        rootNode = rootClauseList ;
      }

      // Only loop through our direct li children
      var cn = Ext.get(rootNode).select('> li') ;
      for(var i = 0 ; i < cn.getCount() ; i++)
      {
        var statement = {} ;
        var el = cn.item(i) ;
        if(el.hasClass('clauseContainer'))
        {
          // Just a plain old clause, create it
          var clause = {} ;
          clause['attribute'] = Ext.getCmp(el.dom.id + 'AttrCombo').getValue() ;
          if(!clause['attribute'])
          {
            // If attribute not set, then user typed in their attribute, get using #getRawValue
            clause['attribute'] = Ext.getCmp(el.dom.id + 'AttrCombo').getRawValue() ;
          }

          clause['op'] = Ext.getCmp(el.dom.id + 'OpCombo').getValue() ;
          if(clause['op'] === 'contains')
          {
            // Translate our op to the set notation
            clause['op'] = Ext.get(el.dom.id + 'Left').dom.innerHTML + Ext.get(el.dom.id + 'Right').dom.innerHTML ;
            var start = Ext.getCmp(el.dom.id + 'ValStart').getValue() ;
            var stop = Ext.getCmp(el.dom.id + 'ValStop').getValue() ;
            if(isNaN(start))
            {
              start = "'" + start + "'" ;
            }

            if(isNaN(stop))
            {
              stop = "'" + stop + "'" ;
            }

            clause['value'] = start + '..' + stop ;
          }
          else
          {
            clause['value'] = Ext.getCmp(el.dom.id + 'ValField').getValue() ;
            if(!isNaN(clause['value']))
            {
              clause['value'] = Number(clause['value']) ;
            }
          }

          if(Ext.getCmp(el.dom.id + 'CaseCheck').getValue())
          {
            clause['case'] = 'sensitive' ;
          }
          statement['body'] = [clause] ;
          statement['not'] = Ext.get(el.dom.id + 'Not').hasClass('selected') ;
          if(i < cn.getCount() - 1)
          {
            statement['bool'] = ((Ext.get(el.dom.id + 'And').hasClass('selected')) ? 'AND' : 'OR') ;
          }
        }
        else if(el.hasClass('nest'))
        {
          // Recurse with our new clause list (doing some DOM gymnastics to deal with Ext elements and other
          var nestList = el.select('ul').first() ;
          statement['body'] = this.createQueryObj(nestList) ;
          if(i < cn.getCount() - 1)
          {
            statement['bool'] = ((Ext.get(nestList.dom.id + 'And').hasClass('selected')) ? 'AND' : 'OR') ;
          }
        }
        else
        {
          continue ;
        }
        query.push(statement) ;
      }

      return query ;
    },
    createQueryString: function(rootNode) {
      var query = [] ;
      if(!rootNode)
      {
        rootNode = rootClauseList ;
      }

      // Only loop through our direct li children
      var cn = Ext.get(rootNode).select('> li') ;
      var clauseCount = cn.getCount() ;

      if(clauseCount === 0)
      {
        query.push('&lt;No clauses specified&gt;') ;
      }

      for(var i = 0 ; i < clauseCount ; i++)
      {
        var el = cn.item(i) ;
        if(el.hasClass('clauseContainer'))
        {
          // Just a plain old clause, create it
          if(Ext.get(el.dom.id + 'Not').hasClass('selected'))
          {
            query.push('NOT (') ;
          }

          // Start of this clause
          query.push('(') ;
          query.push(Ext.getCmp(el.dom.id + 'AttrCombo').getRawValue()) ;

          // Handle contains operator differently
          if(Ext.getCmp(el.dom.id + 'OpCombo').getValue() === 'contains')
          {
            query.push('is between') ;
            query.push(Ext.get(el.dom.id + 'Left').dom.innerHTML) ;

            // Start of the range, displaying strings as quoted
            if(isNaN(Ext.getCmp(el.dom.id + 'ValStart').getValue()))
            {
              query.push('"' + Ext.getCmp(el.dom.id + 'ValStart').getValue() + '"') ;
            }
            else
            {
              query.push(Ext.getCmp(el.dom.id + 'ValStart').getValue()) ;
            }

            query.push(',') ;

            // End of the range, displaying strings as quoted
            if(isNaN(Ext.getCmp(el.dom.id + 'ValStop').getValue()))
            {
              query.push('"' + Ext.getCmp(el.dom.id + 'ValStop').getValue() + '"') ;
            }
            else
            {
              query.push(Ext.getCmp(el.dom.id + 'ValStop').getValue()) ;
            }

            query.push(Ext.get(el.dom.id + 'Right').dom.innerHTML) ;
          }
          else
          {
            query.push(Ext.getCmp(el.dom.id + 'OpCombo').getValue()) ;

            // Value, with strings quoted
            if(isNaN(Ext.getCmp(el.dom.id + 'ValField').getValue()))
            {
              query.push('"' + Ext.getCmp(el.dom.id + 'ValField').getValue() + '"') ;
            }
            else
            {
              query.push(Ext.getCmp(el.dom.id + 'ValField').getValue()) ;
            }
          }
          query.push(')') ;

          if(Ext.get(el.dom.id + 'Not').hasClass('selected'))
          {
            query.push(')') ;
          }
        }
        else if(el.hasClass('nest'))
        {
          // Recurse with our new clause list (doing some DOM gymnastics to deal with Ext elements and other
          query.push('(' + this.createQueryString(el.select('ul').first()) + ')') ;
        }
        else
        {
          continue ;
        }

        // TODO: Change all other next & prev to include the clause or nest selectors? safer?
        if(el.next('li.clauseContainer') || el.next('li.nest'))
        {
          // Our controlling AND/OR will always be in sync, even if its not controlling currently
          if(el.hasClass('clauseContainer'))
          {
            query.push(((Ext.get(el.dom.id + 'And').hasClass('selected')) ? 'AND' : 'OR')) ;
          }
          else if(el.hasClass('nest'))
          {
            query.push(((Ext.get(el.select('ul').first().dom.id + 'And').hasClass('selected')) ? 'AND' : 'OR')) ;
          }
        }
      }

      return query.join(' ') ;
    },
    updateQuerySummary: function() {
      if(Ext.fly(querySummaryDiv))
      {
        Ext.fly(querySummaryDiv).update(this.createQueryString()) ;
      }
    },
    loadQuery: function(queryUri) {
      var that = this ;
      if(!queryUri)
      {
        return false ;
      }

      // Get the query from the API
      new Ajax.Request('/java-bin/apiCaller.jsp?rsrcPath=' + encodeURIComponent(queryUri) + '&method=GET', {
        method: 'post',
        onSuccess: function(transport) {
          var html = [] ;
          var clauses = [] ;
          var nameCmp = Ext.getCmp('queryName') ;
          var data = transport.responseText.evalJSON().data ;
          var query = data.query.evalJSON() ;
          var record = Ext.data.Record.create([
            { name: 'text' }
          ]) ;

          // Populate our query properties
          // Query name & description
          Ext.getCmp('queryDesc').setValue(data.description) ;
          nameCmp.setValue(data.name) ;
          nameCmp.clearInvalid() ;
          origQueryName = data.name ;

          // Query shared
          (data.shared) ? Ext.getCmp('queryShared').setValue(true) : Ext.getCmp('queryShared').setValue(false) ;

          // Some state info
          that.setQueryMode('edit') ;
          that.setQueryUserId(data.userId) ;

          // Hide our clause list while we transition
          Ext.fly('clauseList').fadeOut({ duration: 0.5 , callback: function() {
              Ext.fly('clauseList').update('') ;
              query.each(function(el) {
                that.parseQueryObjToHtml(el, 'clauseList') ;
              }) ;

              // Update our text summary of query
              that.updateQuerySummary() ;

              // Indent our nest blocks
              Ext.select('li.nest').each(function(nest) {
                nest.setStyle({
                  'position': 'relative',
                  'top': 0,
                  'left' : nestOffset + 'px',
                  'width': ((Ext.isIE6 || Ext.isIE7) ? (nest.getWidth() - ieNestWidthCorr) : (nest.getWidth() - nestOffset)) + 'px'
                }) ;

                /** TODO: Inner nests should be alternately colored white/gray
                if(nest.up('li.nest'))
                {
                  nest.first('.nestContainer').setStyle({ 'background-color': '#FFF' }) ;
                }
                **/
              }) ;

              // Done so show our clauses
              Ext.fly('clauseList').fadeIn({ duration: 0.5 }) ;
            }
          }) ;
        },
        onFailure: function(transport) {
          var fbDiv = Ext.get('feedback') ;
          var msg = Ext.util.JSON.decode(transport.responseText).status.msg ;

          if(fbDiv && typeof(dialogWindow) !== 'undefined' && dialogWindow)
          {
            var err = 'There was an error retrieving the requested query: ' + queryUri + '<br>' ;
            err += 'Please let the Genboree administrator about the following error: <br>' ;
            err += msg ;
            fbDiv.update('<div class="failure">' + err + '</div>').scrollIntoView(dialogWindow.body) ;
          }
          else
          {
            var err = 'There was an error retrieving the requested query: ' + queryUri + '\n' ;
            err += 'Please let the Genboree administrator about the following error: \n' ;
            err += msg ;
            alert(err) ;
          }
        }
      }) ;
    },
    parseQueryObjToHtml: function(queryObj, parentId, params) {
      if(queryObj.attribute)
      {
        var clauseValues = {
          attribute: queryObj.attribute,
          op: queryObj.op,
          value: queryObj.value,
          kase: queryObj['case']
        } ;

        if((queryObj.op.indexOf('[') !== -1) || (queryObj.op.indexOf('(') !== -1))
        {
          clauseValues.contains = true ;
        }
        params.show = true ;
        params.append = true ;
        this.createClauseEl(parentId, params, clauseValues) ;
      }
      else if(queryObj.body)
      {
        this.parseQueryObjToHtml(queryObj.body, parentId, { not: queryObj.not, bool: queryObj.bool }) ;
      }
      else if(queryObj instanceof Array)
      {
        // Array of statements/clauses
        if(queryObj[0].body)
        {
          // If an element (check the first for simplicity) has a body, indicates a nest
          // Create our nest HTML
          var nest = [] ;
          var nestId = 'nest' + nextNestIndex ;
          nextNestIndex++ ;

          nest.push('<li class="nest">') ;
          nest.push('  <div class="nestContainer">') ;
          nest.push('    <ul id="' + nestId + '">') ;
          nest.push('    </ul>') ;
          nest.push('    <a href="#" class="appendClauseButton" onclick="BHI.appendClause(\'' + nestId + '\') ; return false ;">+ Append Clause</a>') ;
          nest.push('  </div>') ;
          nest.push('  <div id="' + nestId + 'Bool" class="boolOps">') ;
          var and = (params.bool && params.bool.toLowerCase() === 'and') ;
          nest.push('    <div id="' + nestId + 'BoolDyn" style="display: none ;">') ;
          nest.push('      <a href="#" id="' + nestId + 'And" class="and ' + ((and) ? 'selected' : '') + '" onclick="BHI.setBoolOp(\'' + nestId + '\') ; return false ;">AND</a>') ;
          nest.push('      <a href="#" id="' + nestId + 'Or" class="or ' + ((!and) ? 'selected' : '') + '" onclick="BHI.setBoolOp(\'' + nestId + '\') ; return false ;">OR</a>') ;
          nest.push('    </div>') ;
          if(and)
          {
            nest.push('    <img id="' + nestId + 'BoolStat" src="/images/query/and_disabled.png" alt="AND" style="display: none ;">') ;
          }
          else
          {
            nest.push('    <img id="' + nestId + 'BoolStat" src="/images/query/or_disabled.png" alt="OR" style="display: none ;">') ;
          }
          nest.push('  </div>') ;
          nest.push('</li>') ;
          Ext.DomHelper.append(parentId, nest.join('')) ;
        }

        // Now go onward with clauses or inner nests...
        var elId = (queryObj[0].body) ? nestId : parentId ;
        queryObj.each(function(stmt) {
          // Call each of our children, clausing or nesting as necessary
          this.parseQueryObjToHtml(stmt, elId, params) ;
        }, this) ;
      }
    }
  } ;
} ;

/* Instantiate a global BHI object */
if(typeof(BHI) !== 'undefined')
{
  // Remove any instances that are hanging around in the javascript environment
  delete(BHI) ;
}
var BHI = new BooleanQueryUI() ;
