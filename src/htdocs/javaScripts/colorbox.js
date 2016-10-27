var colorArray = new Object();
var nColors = 0;
var nColorColumns = 6;
var nColorRows = 1;
var cBoxHeight = 70;

var __curImgRef;
var __curForm;
var __curElemId;

function showColorPop( imgRef, formName, elemId )
{
  var txt = '<table border=0 cellspacing=0 cellpadding=0 align=center bgcolor="#000000">\n';
  var i, j, n;
  n = 0;

  __curImgRef = document.images[imgRef];
  __curForm = eval( 'document.'+formName );
  __curElemId = elemId;

  var curColor = "###";
  var i;
  var elems = __curForm.elements;
  var celem = elems[ __curElemId ];
  if( typeof celem != 'undefined' )
  {
    curColor = celem.value.substring(1);
  }

  for( j=0; j<nColorRows; j++ )
  {
    txt = txt + '<tr>\n';
    for( i=0; i<nColorColumns; i++ )
    {
      if( n < nColors )
      {
        var c = colorArray[n];
        var imgName = "frame18x18";
        if( c == curColor ) imgName = "selected18x18";
        txt = txt + '<td align="justify" bgcolor="#' + c +
        '"><a href="javascript:setColor(' + "'" + c + "'" +
        ')"><img border=0 src="/images/'+imgName+'.gif"></a></td>\n';
      }
      else
      {
        txt = txt + '<td>&nbsp;</td>\n';
      }
      n++;
    }
    txt = txt + '</tr>\n';
  }
  txt = txt + '</table>';

  return overlib( txt, STICKY, CLOSECLICK,
	FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F', 
	CAPTIONFONTCLASS, 'capFontClass', CAPTION, 
    	'Select&nbsp;a&nbsp;color', CLOSEFONTCLASS, 'closeFontClass', 
	CLOSETEXT, '&nbsp;&nbsp;<FONT COLOR="white">X</FONT>&nbsp;', WIDTH, '222' );
}

function setColor( c )
{
  var i;
  var elems = __curForm.elements;

  var celem = elems[ __curElemId ];
  if( typeof celem != 'undefined' )
  {
    celem.value = "#" + c;
  }
  __curImgRef.src = "/java-bin/color.jsp?c="+c;
  nd(); nd();
}
