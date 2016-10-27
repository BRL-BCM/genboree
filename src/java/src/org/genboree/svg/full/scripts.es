var root = document.documentElement;
var anim = root.getElementById('anim');
//var menuElement = document.getElementById( 'popMenu' );
//replace the default menu if it is adobe viewer
//if(contextMenu != null && menuElement != null){
//    var newMenuRoot = parseXML( printNode( menuElement ), contextMenu );
//    contextMenu.replaceChild( newMenuRoot, contextMenu.firstChild );
//}

function openLink (link) {
    var winObj = parent.open(link, 'GENBOREE');
    winObj.focus();
}

//some other global variables
var coverElements = new Array(24);
var clOrgX;
var clOrgY;
var clOrgVB;
var clState=0;

//0: global; 1: chromosome
var currentZoom = 0;

function startAnimation () {
    if (evt.altKey)  //skip the the event if the alt key is pressed
        return;
    var leftClick = evt.button == 0;
    var rightClick = evt.button == 2;

    var linkNode = findParentNodeWithId(evt.target, "genboreeLink");
    if(linkNode != null){ //if clicks on the linked area, do not animate
        return;
    }
    var rootNode = findParentNodeWithId(evt.target, "root");
    var csNode = findParentNodeWithId(evt.target, "csNode");
    var anim = document.documentElement.getElementById("anim");
    var x;
    var y;
    var width;
    var height;
    //forbid the default zoomings by using ctrl and shift keys
    if( leftClick && ((currentZoom == 0 && evt.ctrlKey && evt.shiftKey) || (currentZoom == 1 && evt.ctrlKey && !evt.shiftKey))) {
        evt.preventDefault();
        return;
    }

    if( leftClick && currentZoom == 0 && csNode != null){
        //If left mouse click and at the global level: zoom in to the chromosome level
        x = csNode.getAttribute("x");
        y = csNode.getAttribute("y");
        width = csNode.getAttribute("width");
        height = csNode.getAttribute("height");
        var oldVB = rootNode.getAttribute("viewBox");
        var newVB = createViewBoxString(x, y, width, height);
        //alert(x+", "+y+", "+width+", "+height);

        anim.setAttribute("values", oldVB + ";" + newVB);
//        anim.setAttribute("keySplines", "1 0 0.25 0.25");
        zoomInLegend(x, y, width, height);
        anim.beginElement();
        //the following line is critical to allow the viewer to print the same image as it displays
        //on the screen when the user is zoomed in
        rootNode.setAttribute("viewBox", newVB);
        currentZoom = 1;
        evt.preventDefault();
    } else if ( leftClick && currentZoom == 1 && csNode != null){
        x = csNode.getAttribute("x");
        y = csNode.getAttribute("y");
        width = csNode.getAttribute("width");
        height = csNode.getAttribute("height");
        var oldVB = createViewBoxString(x, y, width, height);

        x = rootNode.getAttribute("x");
        y = rootNode.getAttribute("y");
        width = rootNode.getAttribute("width");
        height = rootNode.getAttribute("height");
        var newVB = createViewBoxString(x, y, width, height);

        anim.setAttribute("values", oldVB + ";" + newVB);
//        anim.setAttribute("keySplines", "0.75 0 1 0.25");
        zoomOutLegend();
        anim.beginElement();
        rootNode.setAttribute("viewBox", newVB);
        currentZoom = 0;
        evt.preventDefault();
    } else if (!rightClick){
        evt.preventDefault();
    }
}

function initializeCoverElements(){
    var children= root.childNodes();
    var idx = 0;
    for(var i=0; i<children.length; i++){
        var child = children.item(i);
        if(child.id == null || child.id.substring(0,6) != "csNode")
            continue;
        //the child is a csNode
        var cover = child.lastChild();
        while(cover.id == null || cover.id.substring(0,5) != "cover"){
            cover = cover.previousSibling;
        }
        coverElements[idx] = cover;
        idx++;
    }
}

function endAnimation(){
    if(currentZoom == 0)
        showCover();
    else
        hideCover();
}

function hideCover(){
    if(coverElements[0] == null)
        initializeCoverElements();
    for(var i=0; i<coverElements.length; i++){
        if(coverElements[i] == null)
            break;
        coverElements[i].setAttribute("class", "coverHidden");
    }
}

function showCover(){
    if(coverElements[0] == null)
        initializeCoverElements();
    for(var i=0; i<coverElements.length; i++){
        if(coverElements[i] == null)
            break;
        coverElements[i].setAttribute("class", "coverVisible");
    }
}

function findParentNodeWithId(node, id){
    while(true){
      if(node == null || isRootNode(node))
        break;
      if (node.id == null) {
        node = node.parentNode;
        continue;
      }
      if (isNodeIdMatch(node, id)) {
        break;
      }
      node = node.parentNode;
//      alert("node: "+node+", id = " + node.id + ", is null = "+ (node == null));
    }
    if(isNodeIdMatch(node, id))
	return node;
    else
	return null;
}

function isNodeIdMatch(node, id){
    return node != null && node.id.length >= id.length && node.id.substring(0,id.length) == id;
}

function isCsNode(node){
    return isNodeIdMatch(node, "csNode");
}

function isRootNode(node){
    return isNodeIdMatch(node, "root");
}

function createViewBoxString(x, y, width, height){
    return s = x + " " + y + " " + width + " " + height;
}


function toggleColorLegend(){
    if(evt.button != 0) //only interested in the left mouse click
        return;
    if(clState == 0){
        showColorLegend();
    } else {
        hideColorLegend();
    }
    clState = 1 - clState;
    evt.preventDefault();
}

function showColorLegend(){
    var clLegendbox = document.documentElement.getElementById('clLegendboxArea');
    clLegendbox.setAttribute("style", 'display:"";');
}

function hideColorLegend(){
    var clLegendbox = document.documentElement.getElementById('clLegendboxArea');
    clLegendbox.setAttribute("style", 'display:none;');
}

function highlightCLButton(){
    var clTitle = document.documentElement.getElementById('clTitleArea');
    clTitle.setAttribute("style", "fill:url(#buttonHighlight); fill-opacity:1.0;");
}

function unhighlightCLButton(){
    if(clState == 1)
        return;  //if color legend is shown, the button remains highlighted
    var clTitle = document.documentElement.getElementById('clTitleArea');
    clTitle.setAttribute("style", "fill:url(#button); fill-opacity:0.6;");
}

function zoomInLegend(x, y, width, height){
    var clSvg = root.getElementById("colorLegend");
    //save the originals
    clOrgX = clSvg.getAttribute("x");
    clOrgY = clSvg.getAttribute("y");
    clOrgVB = clSvg.getAttribute("viewBox");

    var scaleX = width / root.getAttribute("width");
    var scaleY = height / root.getAttribute("height");
    //alert(scaleX+","+scaleY);
    var newX = x*1.0 + (width * 1.0 - 135 * scaleX);
    var newY = y*1.0 + (height * 1.0 - 125 * scaleY);
    //alert(newX + ", " +newY);
    clSvg.setAttribute("x", newX);
    clSvg.setAttribute("y", newY);
    clSvg.setAttribute("viewBox", createViewBoxString(0,0,135/scaleX,125/scaleY));
}

function zoomOutLegend(){
    var clSvg = root.getElementById("colorLegend");
    clSvg.setAttribute("x", clOrgX);
    clSvg.setAttribute("y", clOrgY);
    clSvg.setAttribute("viewBox", clOrgVB);
}
