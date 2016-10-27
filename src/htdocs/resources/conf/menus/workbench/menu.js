// #################################################
// NAMESPACE - Should be the same as menuId
// #################################################
var Workbench = Workbench || {};

// #################################################
// MENU-ITEM LISTENERS & HANDLERS
// #################################################
// Default
Workbench.buttonListenerObj =
{
  'click':
  {
    fn: function()
    {
      //showDialogWindow(this.id);
      windowDispatcher(this.id, this);
    }
  },
  'mouseover':
  {
    fn: function()
    {
      removeGenboreeClasses(this);
    }
  },
  'mouseout':
  {
    fn: function()
    {
      updateToolButtonBySatisfaction(this.id, this);
    }
  }
};

// #################################################
// INIT
// #################################################
Ext.onReady(function()
{
  // Requires availability of the globals and Workbench namespace.
  setTimeout( function() { Workbench.initToolbar() }, 50 ) ;
}) ;

Workbench.initToolbar = function()
{
  Ext.QuickTips.init() ;
  Ext.apply(Ext.QuickTips.getQuickTip(), {
    dismissDelay  : 10000,
    showDelay     : 1000
  });

  // Requires availability of the globals and Workbench namespace.
  if(Workbench.globalsLoaded)
  {
    // Setup the workbench toolbar
    Workbench.toolbar = <%= Toolbar %>
    Workbench.toolbarsLoaded = true ;
  }
  else // don't have dependencies, try again in a very short while
  {
    setTimeout( function() { initToolbars() }, 50) ;
  }
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
            target: this.el,
            dismissDelay: 10000,
            showDelay: 1000
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
