// This is really to enable toggling of code snippets in HTML-ified "rcov" documentation
// from original redmine_embedded source.
// - But is generally useful.
function toggleCode(id)
{
  var retVal = true ;
  var elem = null ;
  if(document.getElementById)
    elem = document.getElementById(id) ;
  else if(document.all)
    elem = eval("document.all." + id) ;

  if(elem != null)
  {
    elemStyle = elem.style ;
    if(elemStyle.display != "block")
    {
      elemStyle.display = "block" ;
    }
    else
    {
      elemStyle.display = "none" ;
    }
    retVal = true ;
  }
  else
    retVal = false ;

  return retVal ;
}
