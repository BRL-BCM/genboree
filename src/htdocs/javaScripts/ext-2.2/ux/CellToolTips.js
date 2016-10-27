// Create the namespace
Ext.ns('Ext.ux.plugins.grid');

/**
 * Ext.ux.plugins.grid.CellToolTips plugin for Ext.grid.GridPanel
 *
 * A GridPanel plugin that enables the creation of record based,
 * per-column tooltips that can also be dynamically loaded via Ajax
 * calls.
 *
 * Requires Animal's triggerElement override when using ExtJS 2.x
 * (from <a href="http://extjs.com/forum/showthread.php?p=265259#post265259">http://extjs.com/forum/showthread.php?p=265259#post265259</a>)
 * In ExtJS 3.0 this feature is arealy in the standard.
 *
 * @author  BitPoet
 * @date    July 03, 2009
 * @version 1.1
 *
 * @class Ext.ux.plugins.grid.CellToolTips
 * @extends Ext.util.Observable
 */

/**
 * Constructor for the Plugin
 *
 * @param {ConfigObject} config
 * @constructor
 */
Ext.ux.plugins.grid.CellToolTips = function(config) {
    var cfgTips;
    if( Ext.isArray(config) ) {
        cfgTips = config;
        config = {};
    } else {
    	cfgTips = config.ajaxTips;
    }
    Ext.ux.plugins.grid.CellToolTips.superclass.constructor.call(this, config);
    if( config.tipConfig ) {
    	this.tipConfig = config.tipConfig;
    }
    this.ajaxTips = cfgTips;
} // End of constructor

// plugin code
Ext.extend( Ext.ux.plugins.grid.CellToolTips, Ext.util.Observable, {
    version: 1.1,
    /**
     * Temp storage from the config object
     *
     * @private
     */
    ajaxTips: false,

    /**
     * Tooltip Templates indexed by column id
     *
     * @private
     */
    tipTpls: false,

    /**
     * Tooltip data filter function for setting base parameters
     *
     * @private
     */
    tipFns: false,

    /**
     * URLs for ajax backend
     *
     * @private
     */
    tipUrls: '',

    /**
     * Tooltip configuration items
     *
     * @private
     */
    tipConfig: {},

    /**
     * Loading action
     *
     * @private
     */
    request: false,

    /**
     * Plugin initialization routine
     *
     * @param {Ext.grid.GridPanel} grid
     */
    init: function(grid) {
        if( ! this.ajaxTips ) {
            return;
        }
        this.tipTpls = {};
        this.tipFns  = {};
        this.tipUrls = {};
        // Generate tooltip templates
        Ext.each( this.ajaxTips, function(tip) {
        	this.tipTpls[tip.field] = new Ext.XTemplate( tip.tpl );
        	if( tip.url ) {
        		this.tipUrls[tip.field] = tip.url;
        		if( tip.fn )
        			this.tipFns[tip.field] = tip.fn;
        	}
        }, this);
        // delete now superfluous config entry for ajaxTips
        delete( this.ajaxTips );
        grid.on( 'render', this.onGridRender.createDelegate(this) );
    } // End of function init

    /**
     * Set/Add a template for a column
     *
     * @param {String} fld
     * @param {String | Ext.XTemplate} tpl
     */
    ,setFieldTpl: function(fld, tpl) {
        this.tipTpls[fld] = Ext.isObject(tpl) ? tpl : new Ext.XTemplate(tpl);
    } // End of function setFieldTpl

    /**
     * Set up the tooltip when the grid is rendered
     *
     * @private
     * @param {Ext.grid.GridPanel} grid
     */
    ,onGridRender: function(grid)
    {
        if( ! this.tipTpls ) {
            return;
        }
        // Create one new tooltip for the whole grid
        Ext.apply(this.tipConfig, {
            target:      grid.getView().mainBody,
            delegate:    '.x-grid3-cell-inner',
            trackMouse:  false,
            renderTo:    document.body,
            finished:	   false,
            autoHide:    false,
            header:      true,
            closable:    true,
            dismissDelay: 0,
            draggable: true,
            title: "<div>&nbsp;</div>",
            mouseOffset: [-1,-1]
        });
        this.tip = new Ext.ToolTip( this.tipConfig );
        this.tip.ctt = this;
        // Hook onto the beforeshow event to update the tooltip content
        this.tip.on('beforeshow', this.beforeTipShow.createDelegate(this.tip, [this, grid], true));
        this.tip.on('hide', this.hideTip);
    } // End of function onGridRender

    /**
     * Replace the tooltip body by applying current row data to the template
     *
     * @private
     * @param {Ext.ToolTip} tip
     * @param {Ext.ux.plugins.grid.CellToolTips} ctt
     * @param {Ext.grid.GridPanel} grid
     */
    ,beforeTipShow: function(tip, ctt, grid) {
	// Get column id and check if a tip is defined for it
	var colIdx = grid.getView().findCellIndex( tip.triggerElement );
	var tipId = grid.getColumnModel().getDataIndex( colIdx );
       	if( ! ctt.tipTpls[tipId] )
       	    return false;
    	if( ! tip.finished ) {
	       	var isAjaxTip = (typeof ctt.tipUrls[tipId] == 'string');
        	// Fetch the row's record from the store and apply the template
        	var cellRec = grid.getStore().getAt( grid.getView().findRowIndex( tip.triggerElement ) );
        	// create a copy of the record and use its data, otherwise we might
        	// accidentially modify the original record's values
        	var data = cellRec.copy().data;
        	if( isAjaxTip ) {
        		ctt.loadDetails((ctt.tipFns[tipId]) ? ctt.tipFns[tipId](data) : data, tip, grid, ctt, tipId);
        		return false;
        	} else {
			tip.body.dom.innerHTML = ctt.tipTpls[tipId].apply( cellRec.data );
		}
        } else {
        	tip.body.dom.innerHTML = tip.ctt.tipTpls[tipId].apply( tip.tipdata );
        }
    } // End of function beforeTipShow

    /**
     * Fired when the tooltip is hidden, resets the finished handler.
     *
     * @private
     * @param {Ext.ToolTip} tip
     */
    ,hideTip: function(tip) {
    	tip.finished = false;
    }

    /**
     * Loads the data to apply to the tip template via Ajax
     *
     * @private
     * @param {object} data Parameters for the Ajax request
     * @param {Ext.ToolTip} tip The tooltip object
     * @param {Ext.grid.GridPanel} grid The grid
     * @param {Ext.ux.plugins.grid.CellToolTips} ctt The CellToolTips object
     * @param {String} tipid Id of the tooltip (= field name)
     */
    ,loadDetails: function(data, tip, grid, ctt, tipid) {
    	Ext.Ajax.request({
    		url:	ctt.tipUrls[tipid],
    		params:	data,
    		method: 'POST',
    		success:	function(resp, opt) {
    			tip.finished = true;
    			tip.tipdata  = Ext.decode(resp.responseText);
    			tip.show();
    		}
    	});
    }

}); // End of extend
