// Requires prototype.js
// Register init on page load (from util.js):
addEvent(window, "load", init_minGenboreeConfig);

// Check for minimum browser configuration
// This will be called for every page which has commonFunctions.js, once it loads.
function init_minGenboreeConfig()
{
  // Require that we have a session from server
  requireSession() ;
  // Require that we are in a browser of some kind.
  requireBrowserApp() ;
}

// This is used for the init function above, but ALSO can be called anywhere after
// commonFunctions.js appears in order to not wait until the page finished loaded.
// This approach is useful on pages like gbrowser.js where the page takes a few seconds to load.
function requireSession()
{
  // Ensure jsession cookie present and not a static hand-off (MSIE library -> MSIE browser hand off fix)
  var jsessid = getCookie("JSESSIONID") ;
  if(jsessid == null)
  {
    window.location.reload() ;
  }
}

function requireBrowserApp()
{
  // Check if browser-set cookie is available
  var inBrowser = getCookie("GB_INBROWSER") ;
  if(!inBrowser) // not in a browser it seems
  {
    // Set cookie
    setCookie("GB_INBROWSER", "true") ;
    // Reload page
    window.location.reload() ;
  }
  return ;
}

// a function equivlent to java String.replaceAll() function
// javascript achieve this with /findString/g, but it does not allow variables

 function replaceAll(str, findStr, replaceStr) {
    var index = str.indexOf (findStr);
    var indexi = parseInt (index);
    var part1 = "";
    var part2 = "";
    while (indexi>0) {
        part1 = str.substring(0, indexi + findStr.length);
        part1 = part1.replace(findStr, replaceStr);
        part2 = str.substring(indexi + findStr.length);
        str = part1 + part2;
        index = str.indexOf (findStr, indexi+findStr.length+1);
        indexi = parseInt (index);
    }

   if (str.indexOf (findStr)>0)
      str = str.replace(findStr, replaceStr);

    return str;
 }

// a function equivalent to java string trim()
function trimString(sInString) {
   sInString = sInString.replace( /^\s+/g, "" );// strip leading
   return sInString.replace( /\s+$/g, "" );// strip trailing
}

function fullUrlEscape(str)
{
  return fullEscape(str) ;
}

// a function equivalent to java string trim()
function trim(sInString) {
   sInString = sInString.replace( /^\s+/g, "" );// strip leading
   return sInString.replace( /\s+$/g, "" );// strip trailing
}

// a function that strips white space and comma in integer input
function stripString  (s) {
    var exp = / /g;
    var exp1 = /,/g;
    s = trimString(s);
    s = s.replace(exp1, '');
    s = s.replace( exp, '' );
    return s;
}


function isNum(s)
{
  var success = false ;
  s = trimString(s) ;
  var reg = /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/ ;
  if(reg.test(s))
  {
    success = true ;
  }
  return success ;
}


function countSelectedAnnotations (fieldId) {
   var count = 0;
   var list = document.getElementsByTagName("input");
   var count = 0;
   for (var ii=0; ii<list.length; ii++){
       if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf(fieldId) == 0) {
            if (list[ii].checked)
                count ++;
        }
    }
    return count;
}

function confirmSelectedChanges(n, total, state, message) {
    var count = countSelectedAnnotations( "checkBox_");
    n = n + count;
    if (state)
        n = total;

    if (n==0){
        $("okState").value="0";
        alert ("No annotation was selected.");
        return false;
    }

    var be = " annotation";
    if (n>1)
        be = " annotations";
    var displayMessage =  "'You are about to " + message + " for the " + n + " selected " + be + ". \nAre you sure?'";
    if (confirm (displayMessage) ){
        $("okState").value="1";
        $("doSelected").value="doSelected";
        $('editorForm').submit();
    }
    else {
        $("okState").value="0";
    }
}



function putCommas( src )
{
    var myString = "" + src;
	var l = myString.length - 3;
	while( l > 0 )
	{
		myString = myString.substring(0,l) + "," + myString.substring(l);
		l -= 3;
	}
	return myString;
}

function remCommas( src, defaultValue )
{
	var myString = "" + src;
	var idx = myString.indexOf( ',' );
	var def = defaultValue;
	while( idx >= 0 )
	{
		myString = myString.substring(0,idx) + myString.substring(idx+1);
		idx = myString.indexOf( ',' );
	}
	idx = myString.indexOf( '.' );
	if( idx >= 0 ) myString = myString.substring( 0, idx );
	if(myString != "" && !isNaN(parseInt(myString)) ) def = parseInt(myString);

	return def;
}

  function transformLimits(chromosomeSize)
  {
    // % Range to view depends on the size of the chromosome;
    // smaller % for very large ones and much larger % for smaller ones.
    // Minimum % is 1%. Maximum $ is 50%.
    // The range model is this:
    //    range = 4260*size^(-0.584)
    // This results in:
    //    250,000,000 => 5%  (view range 12,500,000)
    //     50,000,000 => 15% (view range 7,500,000)
    //      5,000,000 => 50% (view range  2,250,000)
    chromosomeSize = chromosomeSize ? chromosomeSize : 1000 ;
    var arr = new Array(2) ;
  	var midPoint = Math.round(chromosomeSize / 2) ;
    var rangeSizeFraction = 4260*Math.pow(chromosomeSize, -0.584 ) ;
    if(rangeSizeFraction < 0.01)
    {
      rangeSizeFraction = 0.01 ;
    }
    else if(rangeSizeFraction > 0.5)
    {
      rangeSizeFraction = 0.5 ;
    }

    // Determine range in bases (rounded up)
    var rangeRadius = Math.round((chromosomeSize * rangeSizeFraction)/2) ;
    // Determine coords
    var vFrom = midPoint - rangeRadius ;
    if(vFrom < 1)
    {
      vFrom = 1 ;
    }
    var vTo = midPoint + rangeRadius ;
    if(vTo > chromosomeSize)
    {
      vTo = 1 ;
    }
    arr[0] =  vFrom ;
    arr[1] = vTo ;
    return arr;
  }


function confirmAction1(action, gname) {
var displayMessage = "You are about to " + action + " annotation \"" + gname + "\" from database. Are you sure?"
     if (confirm (displayMessage) ){
        $("okState").value="1";
        $("doSelected").value="doSelected";
        $('editorForm').submit();
    }
    else {
        $("okState").value="0";
    }
}


function  submitForm2Target(formId, target) {
   var myform =document.getElementById(formId);
   if (myform)  {
      myform.action = target;
      myform.submit();
   }
}



function confirmAction(message) {
     if (confirm (message) ){
        $("okState").value="1";
        $("doSelected").value="doSelected";
        $('editorForm').submit();
    }
    else {
        $("okState").value="0";
    }
}
