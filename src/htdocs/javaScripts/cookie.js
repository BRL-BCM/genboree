
function Cookie(document, name)
{
  this.$document = document;
  this.$name = name;
  this.$expiration = new Date((new Date()).getTime() + 3600000000);
  this.$path = null;
  this.$domain = null;

  if( document != null )
  {
    var xpath = document.URL;
    var idx = xpath.indexOf( "//" );
    var xproto = "";
    if( idx > 0 )
    {
      xproto = xpath.substring(0,idx+2);
      xpath = xpath.substring( idx+2 );
    }
    var xdom = xpath;
    idx = xpath.indexOf( "/" );
    if( idx > 0 )
    {
      xdom = xpath.substring( 0, idx );
      if( xdom.substring(0,4) == "www." ) xdom = xdom.substring(4);
    }

    if( xproto == "http://" ) this.$domain = xdom;
  }

  this.$secure = false;
}
function _Cookie_store()
{
  var cookieval = "";
  for(var prop in this)
  {
    if ((prop.charAt(0) == '$') || ((typeof this[prop]) == 'function')) continue;
    if (cookieval != "") cookieval += '&';
    cookieval += prop + ':' + escape(this[prop]);
  }
  var cookie = this.$name + '=' + cookieval;
  if (this.$expiration) cookie += '; expires=' + this.$expiration.toGMTString();
  if (this.$path) cookie += '; path=' + this.$path;
  if (this.$domain) cookie += '; domain=' + this.$domain;
  if (this.$secure) cookie += '; secure';
  this.$document.cookie = cookie;
}
function _Cookie_load()
{
  var allcookies = this.$document.cookie;
  if (allcookies == "") return false;
  var start = allcookies.indexOf(this.$name + '=');
  if (start == -1) return false;
  start += this.$name.length + 1;
  var end = allcookies.indexOf(';', start);
  if (end == -1) end = allcookies.length;
  var cookieval = allcookies.substring(start, end);
  var a = cookieval.split('&');
  for(var i=0; i < a.length; i++) a[i] = a[i].split(':');
  for(var i = 0; i < a.length; i++)
  {
    this[a[i][0]] = unescape(a[i][1]);
  }
  return true;
}
new Cookie();
Cookie.prototype.store = _Cookie_store;
Cookie.prototype.load = _Cookie_load;

