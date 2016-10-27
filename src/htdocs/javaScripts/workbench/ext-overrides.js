Ext.Element.prototype.mask = function(msg, msgCls)
{
		    var me = this,
dom = me.dom,
dh = Ext.DomHelper,
el,
mask,
XMASKEDRELATIVE = 'x-masked-relative',
XMASKED = 'x-masked',
EXTELMASKMSG = "ext-el-mask-msg",
data = Ext.Element.data;

          if(dom)
          {
            if(!/^body/i.test(dom.tagName) && me.getStyle('position') == 'static'){
                me.addClass(XMASKEDRELATIVE);
            }
            if((el = data(dom, 'maskMsg'))){
                el.remove();
            }
            if((el = data(dom, 'mask'))){
                el.remove();
            }
  
              mask = dh.append(dom, {cls : "ext-el-mask"}, true);
            data(dom, 'mask', mask);
  
            me.addClass(XMASKED);
            mask.setDisplayed(true);
            if(typeof msg == 'string'){
                  var mm = dh.append(dom, {cls : EXTELMASKMSG, cn:{tag:'div'}}, true);
                  data(dom, 'maskMsg', mm);
                mm.dom.className = msgCls ? EXTELMASKMSG + " " + msgCls : EXTELMASKMSG;
                mm.dom.firstChild.innerHTML = msg;
                mm.setDisplayed(true);
                mm.center(me);
            }
            if(Ext.isIE && !(Ext.isIE7 && Ext.isStrict) && me.getStyle('height') == 'auto'){ // ie will not expand full height automatically
                mask.setSize(undefined, me.getHeight());
            }
          }
	        return mask;
	    }