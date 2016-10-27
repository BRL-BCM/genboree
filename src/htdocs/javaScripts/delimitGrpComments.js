// javascript for add Commnets

var commentsWrapped = false ;
var comments =new Array();


function dispatchWrapComments(elementName, delims)
{
    if(commentsWrapped) // then user already wrapped the comments, restore via reload
    {
        if (comments != null && comments.length >0) {
        for(var ii = 0; ii < comments.length; ii++)
        {
        document.getElementById("comments_" + ii).value = comments[ii];
        }
        }
        document.getElementById('commentFormatBtn').value = "Wrap Comments";
        commentsWrapped = false ;
    }
    else // wrap the comments and setup "restore"
    {
            roughFormatText(elementName, delims) ;
            document.getElementById('commentFormatBtn').value = "Restore Comments" ;
            commentsWrapped = true ;
    }
}

// comments are processed on the Annotation Group Details page).
function roughFormatText(elementName, delims)
{
// Create the Regular Expression
if(delims == "") return;
var delimsREstr = delims.replace(/(.)/g, "(?:\\$1\\s?)") ;
//  alert("delimsREstr: --" + delimsREstr + "--") ;
delimsREstr = "(" + delimsREstr.replace(/\)\(/g, ")|(") + ")" ;
// alert("delimsREstr: --" + delimsREstr + "--") ;
var re = new RegExp(delimsREstr, "g") ;

// Apply the Regular Expression to each element named elementName.
var elems = document.getElementsByName(elementName) ;
if (elems != null && elems.length>0) {
var n = elems.length;

comments = new Array(n);
}
// alert('elems size: ' + elems.length) ;
for(var ii = 0; ii < elems.length; ii++)
{
var elem = elems[ii].value ;


comments[ii]=elems[ii].value ;

elem = elem.replace(re, "$1\n");

elems[ii].value = elem;


}
}



// comments are processed on the Annotation Group Details page).
function roughFormatText1(elementName, delims)
{
// Create the Regular Expression
if(delims == "") return;
var delimsREstr = delims.replace(/(.)/g, "(?:\\$1\\s?)") ;
//  alert("delimsREstr: --" + delimsREstr + "--") ;
delimsREstr = "(" + delimsREstr.replace(/\)\(/g, ")|(") + ")" ;
// alert("delimsREstr: --" + delimsREstr + "--") ;
var re = new RegExp(delimsREstr, "g") ;

// Apply the Regular Expression to each element named elementName.
var elems = document.getElementsByName(elementName) ;

// alert('elems size: ' + elems.length) ;
for(var ii = 0; ii < elems.length; ii++)
{
var elem = elems[ii].value ;

elem = elem.replace(re, "$1\n");

elems[ii].value = elem;


}
}



