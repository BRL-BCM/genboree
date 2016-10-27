


Ext.BLANK_IMAGE_URL = "/javaScripts/extjs/resources/images/default/s.gif" ;

Ext.namespace('Ext.ux') ;
Ext.ux.Menubar =  function(config)
                  {
                    Ext.ux.Menubar.superclass.constructor.call(this, config) ;
                    this.cls += " x-menubar" ;
                    if(this.orientation == "vertical")
                    {
                      this.subMenuAlign = "tl-tr?" ;
                      this.cls += " x-vertical-menubar" ;
                    }
                    else
                    {
                      this.subMenuAlign = "tl-bl?" ;
                      this.cls += " x-horizontal-menubar" ;
                    }
                  } ;

Ext.extend( Ext.ux.Menubar, Ext.menu.Menu,
            {
              plain: true,
              cls: "",
              minWidth: 120,
              shadow: false,
              orientation: "vertical",
              activated: false,
              activatedClass: "x-menu-activated",

              // private
              render: function(container)
              {
                if(this.el)
                {
                  return ;
                }
                if(container)
                {
                  var el = this.el = Ext.get(container) ;
                  el.addClass("x-menu") ;
                }
                else
                {
                  var el = this.el =  new Ext.Layer(
                                      {
                                        cls: "x-menu",
                                        shadow: this.shadow,
                                        constrain: false,
                                        parentEl: this.parentEl || document.body,
                                        zindex: 15000
                                      }) ;
                }
                this.keyNav = new Ext.menu.MenuNav(this) ;
                if(this.plain)
                {
                  el.addClass("x-menu-plain") ;
                }
                if(this.cls)
                {
                  el.addClass(this.cls) ;
                }
                // generic focus element
                this.focusEl =  el.createChild(
                                {
                                  tag: "a",
                                  cls: "x-menu-focus",
                                  href: "#",
                                  onclick: "return false ;",
                                  tabIndex: "-1"
                                }) ;
                var ul =  el.createChild(
                          {
                            tag: "ul",
                            cls: "x-menu-list"
                          }) ;
                ul.on("click", this.onClick, this) ;
                ul.on("mouseover", this.onMouseOver, this) ;
                ul.on("mouseout", this.onMouseOut, this) ;
                this.items.each(  function(item)
                                  {
                                    var li = document.createElement("li") ;
                                    li.className = "x-menu-list-item" ;
                                    if(item.align == 'right')
                                    {
                                      li.style.cssFloat = "right" ;
                                    }
                                    ul.dom.appendChild(li) ;
                                    item.render(li, this) ;
                                  },
                                  this
                               ) ;
                this.ul = ul ;
                // this.autoWidth() ; // not for menu bars.
              },
              show: function(container)
              {
                if(!this.el)
                {
                  this.render(container) ;
                }
                this.fireEvent("beforeshow", this) ;
                this.fireEvent("show", this) ;
              },
              hide: function()
              {
                if(this.activeItem)
                {
                  this.activeItem.deactivate() ;
                  delete this.activeItem ;
                }
                this.deactivate() ;
              },
              onClick: function(e)
              {
                var t = this.findTargetItem(e) ;
                if(t && t.menu === undefined)
                {
                  t.onClick(e) ;
                  this.fireEvent("click", this, t, e) ;
                }
                else
                {
                  if(this.activated)
                  {
                    this.deactivate() ;
                    this.activeItem.hideMenu() ;
                  }
                  else if(t)
                  {
                    this.activate() ;
                    if(t.canActivate && !t.disabled)
                    {
                      this.setActiveItem(t, true) ;
                    }
                    this.fireEvent("click", this, e, t) ;
                  }
                  e.stopEvent() ;
                }
              },
              onMouseOver:  function(e)
              {
                var t = this.findTargetItem(e) ;
                if(t)
                {
                  if(t.canActivate && !t.disabled)
                  {
                    this.setActiveItem(t, this.activated) ;
                  }
                }
                this.fireEvent("mouseover", this, e, t) ;
              },
              onMouseOut: function(e)
              {
                var t ;
                if(!this.activated)
                {
                  t = this.findTargetItem(e) ;
                  if(t)
                  {
                    if(t == this.activeItem && t.shouldDeactivate(e))
                    {
                      this.activeItem.deactivate() ;
                      delete this.activeItem ;
                    }
                  }
                  this.fireEvent("mouseout", this, e, t) ;
                }
              },
              activate: function()
              {
                this.activated = true ;
                this.ul.addClass("x-menu-activated") ;
              },
              deactivate: function()
              {
                this.activated = false ;
                this.ul.removeClass("x-menu-activated") ;
              }
            }) ;

/* PARTICULAR EXAMPLE USAGE */
Ext.onReady(function()
            {
              FullMB =  new Ext.ux.Menubar(
                        {
                          orientation: "vertical"
                        }) ;
              FullMB.add( new Ext.menu.Item(
                          {
                            text: 'Home',
                            href: "#AppTaxNoValidation",
                            e: null
                          }),
                          new Ext.menu.Item(
                          {
                            hideOnClick: false,
                            text: 'Static Data',
                            menu: new Ext.menu.Menu(
                            {
                              id: 'foo',
                              items:  [
                                        {
                                          href: "#Company",
                                          text: "Companies",
                                          e: null
                                        },
                                        {
                                          href: "#Component",
                                          text: "House Components",
                                          e: null
                                        },
                                        {
                                          href: "#PlayerType",
                                          text: "Player Types",
                                          e: null
                                        },
                                        {
                                          href: "#Access 1",
                                          text: "Access level 1",
                                          e: null, level: 1
                                        },
                                        {
                                          href: "#Access 2",
                                          text: "Access level 2",
                                          e: null, level: 2
                                        },
                                        {
                                          href: "#Access 3",
                                          text: "Access level 3",
                                          e: null, level: 3
                                        }
                                      ]
                            })
                          }),
                          new Ext.menu.Item(
                          {
                            text: 'Application Data(1)',
                            level: 1,
                            menu:
                            {
                              items:  [
                                        {
                                          href: "#AppTaxNoValidation",
                                          text: "Tax No Validations",
                                          e: null
                                        },
                                        {
                                          href: "#AppClass",
                                          text: "Application Classes",
                                          e: null
                                        },
                                        {
                                          href: "#AppComponent",
                                          text: "Application Components",
                                          e: null
                                        }
                                      ]
                            }
                          }),
                          //new Ext.Toolbar.Fill(),
                          new Ext.menu.Item(
                          {
                            text: 'Align Right',
                            align: 'right',
                            menu:
                            {
                              items:  [
                                        {
                                          href: "#AppClass",
                                          text: "Application Classes",
                                          e: null
                                        },
                                        {
                                          href: "#EconomicGroup",
                                          text: "Economic Groups",
                                          e: null
                                        },
                                        {
                                          href: "#Language",
                                          text: "Languages",
                                          e: null
                                        },
                                        {
                                          text: 'Submenus',
                                          menu: {
                                                  items:
                                                  [
                                                    {
                                                      href: "#AppClass",
                                                      text: "Application Classes",
                                                      e: null
                                                    },
                                                    {
                                                      href: "#AppComponent",
                                                      text: "Application Components",
                                                      e: null
                                                    }
                                                  ]
                                                }
                                        },
                                        {
                                          href: "#Market",
                                          text: "Markets",
                                          e: null
                                        },
                                        {
                                          href: "#Menu",
                                          text: "Main Menu Groupings",
                                          e: null
                                        },
                                        {
                                          href: "#Player",
                                          text: "Supply-Chain Players",
                                          e: null
                                        },
                                        {
                                          href: "#PlayerType",
                                          text: "Player Types",
                                          e: null
                                        }
                                      ]
                            }
                          }),
                          new Ext.menu.Item(
                          {
                            text: 'Test Menu(2)',
                            level: 2,
                            align: 'right',
                            menu:
                            {
                              items:
                              [
                                {
                                  href: "#AppClass",
                                  text: "Application Classes",
                                  e: null
                                },
                                {
                                  href: "#EconomicGroup",
                                  text: "Economic Groups",
                                  e: null
                                },
                                {
                                  href: "#Language",
                                  text: "Languages",
                                  e: null
                                },
                                {
                                  text: 'Submenus',
                                  menu:
                                  {
                                    items:
                                    [
                                      {
                                        href: "#AppClass",
                                        text: "Application Classes",
                                        e: null
                                      },
                                      {
                                        href: "#AppComponent",
                                        text: "Application Components",
                                        e: null
                                      }
                                    ]
                                  }
                                },
                                {
                                  href: "#Market",
                                  text: "Markets",
                                  e: null
                                },
                                {
                                  href: "#Menu",
                                  text: "Main Menu Groupings",
                                  e: null
                                },
                                {
                                  href: "#Player",
                                  text: "Supply-Chain Players",
                                  e: null
                                },
                                {
                                  href: "#PlayerType",
                                  text: "Player Types",
                                  e: null
                                }
                              ]
                            }
                          })
                        ) ;
              FullMB.show(Ext.get("app-menubar"), "bl-bl") ;
              SmallMenuBar =  new Ext.ux.Menubar(
                              {
                                orientation: "vertical"
                              }) ;
              SmallMenuBar.add( new Ext.menu.Item(
                                {
                                  text: 'Home',
                                  href: "#AppTaxNoValidation",
                                  e: null
                                }),
                                new Ext.menu.Item(
                                {
                                  hideOnClick : false,
                                  text: 'Static Data',
                                  menu: new Ext.menu.Menu(
                                        {
                                          id: 'foo',
                                          items:
                                          [
                                            {
                                              href: "#Company",
                                              text: "Companies",
                                              e: null
                                            },
                                            {
                                              href: "#Component",
                                              text: "House Components",
                                              e: null
                                            },
                                            {
                                              href: "#PlayerType",
                                              text: "Player Types",
                                              e: null
                                            }
                                          ]
                                        })
                                })
                              ) ;
              SmallMenuBar.show(Ext.get("container-menubar"), "tl-tl") ;
            }) ;

function HideItems(menu, level)
{
  //console.log(menu) ;
  var a = menu.items.items ;
  //console.log(a) ;
  for(var i=0 ; i<a.length ; i++)
  {
    if(a[i])
    {
      if(a[i].level === undefined || a[i].level <= level)
      {
        a[i].show() ;
        console.group(a[i].text, a[i].level, "show") ;
      }
      else
      {
        a[i].hide() ;
        console.group(a[i].text, a[i].level, "hide") ;
      }
      if(a[i].menu)
      {
        HideItems(a[i].menu, level) ;
      }
      console.groupEnd() ;
    }
  }
}
