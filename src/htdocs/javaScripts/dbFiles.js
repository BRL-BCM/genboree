/* global variables */
var FILE_DIR = 'dbFiles';
/* used for the resize bar */
var curWidth=0;
var curRWidth=0;
var curRLeftPos=0;
var curPos=0;
var newPos=0;
var mouseStatus='up';


/**
 * Get the original div widths
 */
function setPos(e) {
  // for handling events in ie vs. w3c
  curevent=(typeof event=='undefined'?e:event);
  // Set mouse flag as down
  mouseStatus='down';
  // Gets position of click
  curPos=curevent.clientX;
  // Split the width value from the 'px' units
  widthArray=$('leftPane').style.width.split('p');
  curWidth=parseInt(widthArray[0]);
  // Set the left side of the rightpane div
  curRWidthArray=$('rightPane').style.width.split('p');
  curRWidth=parseInt(curRWidthArray[0]);
  curRLeftPosArray=$('rightPane').style.left.split('p');
  curRLeftPos=parseInt(curRLeftPosArray[0]);
}

/**
 * Changes the div sizes while the mouse button is pressed
 */
function getPos(e){
  if(mouseStatus=='down') {
    curevent=(typeof event=='undefined'?e:event);
    // Get new mouse position
    newPos=curevent.clientX;
    // Calculate movement in pixels
    var pxMove=parseInt(newPos-curPos);
    // Determine new height
    var newWidth=parseInt(curWidth+pxMove);
    // Set the new widths of the divs
    $('leftPane').style.width=parseInt(curWidth+pxMove)+'px';
    $('rightPane').style.left=parseInt(curRLeftPos+pxMove)+'px';
    $('rightPane').style.width=parseInt(curRWidth-pxMove)+'px';
  }
}

/* Array that will hold the API resorce response data */
var dbFilesObj = [];
/* Array containing the API resources organized by subdir */ 
var fileObjsByDir = [];
/* Must be set before onload is called */
var rsrcUri;
var treeNodes = [];
var fileTree;
var fileGrid;


/**
 * Uses the API to do a GET request for the list of files.
 */
function retrieveFileList() {
  fileTree.body.mask('Loading', 'x-mask-loading');  
  Ext.Ajax.request({
    method: 'post',
    params: {rsrcPath: rsrcUri, method: 'get'},
    url: '/java-bin/apiCaller.jsp',
    success: loadFileListToTree,
    failure: function(resp) {alert('FAIL ' + resp.responseText)},
    async: false
  });
}

/**
 * This method parses the response which is a list of files and builds the globals
 * fileObjsByDir
 */
function loadFileListToTree(response) {
  dbFilesObj = JSON.parse(response.responseText);
  var nodesAdded = []; // Array to track which dirs have been added to the tree
  // First organize the files into subdirs
  for(var ii=0; ii<dbFilesObj.data.length; ii++) {
    var filePathArr = dbFilesObj.data[ii].fileName.split('/');
    var parentNode = fileTree.getRootNode();
    var fileDir = '';
    var dirSep = '';
    for(var ff=0; ff<filePathArr.length; ff++) {
      /* last part of the path, should be the file */
      if(ff == filePathArr.length-1) {
        leafNode = parentNode.appendChild( {
                                              text: filePathArr[ff],
                                              id: 'dbFileId_' + ii,
                                              href: null,
                                              leaf: true,
                                              cls: "file",
                                              expanded: false,
                                              allowDrag: false,
                                              allowDrop: false
                                            } );
        parentNode.collapse();
      } else {
        /* dir, add it if it hasn't been added yet */
        /* make string of the absolute path */
        fileDir += dirSep + filePathArr[ff];
        dirSep = '/';
        if(nodesAdded[fileDir]) {
          /* If it's already been added, get it so we can use for the next iteration */
          parentNode = nodesAdded[fileDir];
        } else {
          newNode = parentNode.appendChild( {
                                                  id: fileDir,
                                                  text: filePathArr[ff],
                                                  href: null,
                                                  leaf: false,
                                                  cls: "folder",
                                                  expanded: true,
                                                  allowDrag: false,
                                                  allowDrop: false,
                                                  allowChildren: true,
                                                  children: []
                                                } );
          parentNode.renderChildren();
          nodesAdded[fileDir] = newNode;
          parentNode = newNode;
        }
      }
    }
    if(!fileObjsByDir[fileDir]) fileObjsByDir[fileDir] = [];
    fileObjsByDir[fileDir].push(dbFilesObj.data[ii]);
  }
  fileTree.body.unmask(); 
}


function loadFileListDetail(node, event) {
  var ds = fileGrid.getStore();
  if(!node.isLeaf() && node.getDepth() != 0) {
    if(fileObjsByDir[node.id]) {
      ds.loadData(fileObjsByDir[node.id]);
    }
  } else if(node.isLeaf()) {
    /* strip 'dbFileId_' from the id */
    fileId = node.id.replace('dbFileId_', '');
    ds.loadData([dbFilesObj.data[fileId]]);
    rowExpander.toggleRow(0);
  }
  
}