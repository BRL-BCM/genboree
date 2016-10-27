


function validateForm( f )
{
  if( f.link_name.value == "" )
  {
    alert( "Link name must not be empty." );
    f.link_name.focus();
    return false;
  }
  if( f.link_pattern.value == "" )
  {
    alert( "Link pattern must not be empty." );
    f.link_pattern.focus();
    return false;
  }
  return true;
}




function addtag( tag )
{
  var patt = document.lnkmgr.link_pattern;
  patt.value = patt.value + '$' + tag;
  patt.focus();
}

function clearAll()
{
  var opts = document.lnkmgr.linkId.options;
  var i=0;
  for( i=0; i<opts.length; i++ ) opts[i].selected = false;
}
function reloadIfSingle()
{
  var opts = document.lnkmgr.ftypeId.options;
  var cnt = 0;
  var i=0;
  for( i=0; i<opts.length; i++ ) if( opts[i].selected ) cnt++;
  if( cnt == 1 ) document.lnkmgr.submit();
}








