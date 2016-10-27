// #################################################
// NAMESPACE - Should be the same as menuId
// #################################################
var Sample = Sample || {};

// #################################################
// MENU-ITEM LISTENERS & HANDLERS
// #################################################
// Default:
Sample.buttonListenerObj = 
{
  'click': 
  {
    fn: function() 
    {
      alert('Clicked button: ' + this.id);
    }
  }
};

/* This "special" button has it's listener defined in the menu.json config file */
/* instead of using the default buttonListenerObj */
var specialButtonListenerObj =
{
  'click':
  {
    fn: function()
    {
      alert('Clicked Special button: ' + this.id);
    }
  }
};

function datePickerHandler(datepicker, date)
{ 
  alert('Date Selected, You chose: '+ date.format('M j, Y')); 
}

function colorPickerHandler(colorpicker, color)
{ 
  alert('Color Selected, You chose: ' + color); 
}

function checkHandler() {
  alert('Checked a menu item');
}

// #################################################
// INIT
// #################################################
Ext.onReady(function()
{
  // Requires availability of the globals and Workbench namespace.
  setTimeout( function() { Sample.initToolbars() }, 50 ) ;
}) ;

Sample.initToolbars = function()
{
  Ext.QuickTips.init() ;
  var toolbar = <%= Toolbar %> ;
}

// #################################################
// OVERRIDES & HELPERS
// #################################################
// Override built-in functions of ExtJS to get more functionality.
// 1. Allow tooltips for Menu Items!
Ext.override(
  Ext.menu.Item,
  {
    onRender: function(container, position)
    {
      if(!this.itemTpl)
      {
        this.itemTpl = Ext.menu.Item.prototype.itemTpl = new Ext.XTemplate(
          '<a id="{id}" class="{cls}" hidefocus="true" unselectable="on" href="{href}"',
          '<tpl if="hrefTarget">',
          ' target="{hrefTarget}"',
          '</tpl>',
          '>',
          '<img src="{icon}" class="x-menu-item-icon {iconCls}"/>',
          '<span class="x-menu-item-text">{text}</span>',
          '</a>'
        ) ;
      }
      var aa = this.getTemplateArgs() ;
      this.el = (position ? this.itemTpl.insertBefore(position, aa, true) : this.itemTpl.append(container, aa, true)) ;
      this.iconEl = this.el.child('img.x-menu-item-icon') ;
      this.textEl = this.el.child('.x-menu-item-text') ;
      if(this.tooltip)
      {
        this.tooltip = new Ext.ToolTip(
          Ext.apply(
          {
            target: this.el
          },
          (Ext.isObject(this.tooltip) ? this.tooltip : { html: this.tooltip } )
        )) ;
      }
      Ext.menu.Item.superclass.onRender.call(this, container, position) ;
    },
    getTemplateArgs: function()
    {
      var result = {
        id: this.id,
        cls: this.itemCls + (this.menu ?  ' x-menu-item-arrow' : '') + (this.cls ?  ' ' + this.cls : ''),
        href: this.href || '#',
        tooltip: this.tooltip,
        hrefTarget: this.hrefTarget,
        icon: this.icon || Ext.BLANK_IMAGE_URL,
        iconCls: this.iconCls || '',
        text: this.itemText || this.text || ' '
      } ;
      return result ;
    }
  }
) ;


