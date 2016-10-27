function displaySuccessDialog(result, request) {
  alert("implement me");
}

/**
 * This should handle a variety of response formats and display as prettily as possible
 * The response could be an API json response
 * or html text
 */
function displayFailureDialog(result, windowTitle) {
  alert("implement me");
}

/** Use this to show the tool settings dialog with rest of page masked. i.e. MODAL */
var pwDialogWindow = null;
var gnDialogWindow = null;

function showPathwayDialog(geneName) {
  /* Be sure resources that are in the inputs/outputs are loaded to hash in the order displayed */
  pageMask = new Ext.LoadMask(Ext.getBody(), {
    msg: null
  });
  pageMask.show();
  /* initialize, and ensure we don't have data from a previous dialog */
  delete pwDialogWindow;
  pwDialogWindow = new Ext.Window({
    id: 'pathwayWin',
    modal: false,
    autoScroll: true,
    title: 'Pathways',
    stateful: false,
    autoLoad: {
      url: '/genboree/findPathways.rhtml?geneName=' + geneName,
      scripts: false,
      discardUrl: true,
      callback: pwCallback,
      timeout: 15
    }
  });
  pwDialogWindow.addListener('close', closeToolWindows, pwDialogWindow, {
    single: true
  });
  /* Workaround for 'jumpy' window when loaded, hide it immediately, use pageMask, then unhide it in the callback */
  pwDialogWindow.show();
  pwDialogWindow.hide();
}

function toggleSelect(chkBox, divName) {
  var chkDiv = document.getElementById(divName);
  var chkBoxes = chkDiv.getElementsByTagName('input');
  for (i = 0; i <= chkBoxes.length - 1; i++) {
    if(!chkBoxes[i].disabled) {chkBoxes[i].checked = chkBox.checked;}
  }
}

function showGeneDialog(pathwayName, geneName, keggLink) {
  /* initialize, and ensure we don't have data from a previous dialog */
  delete gnDialogWindow;
  gnDialogWindow = new Ext.Window({
    id: 'geneWin',
    modal: true,
    autoScroll: false,
    title: 'Choose from genes in a pathway',
    stateful: false,
    autoLoad: {
      url: '/genboree/pathwayWrapper.rhtml?geneName=' + geneName + '&keggUrl=' + keggLink + '&pathwayName=' + pathwayName,
      scripts: false,
      discardUrl: true,
      callback: gnCallback,
      timeout: 15
    },
    pathwayName:pathwayName
  });
  gnDialogWindow.addListener('close', closeGeneWindow, gnDialogWindow, {
    single: true
  });
  /* Workaround for 'jumpy' window when loaded, hide it immediately, use pageMask, then unhide it in the callback */
  gnDialogWindow.show();
  gnDialogWindow.hide();
}

function pwCallback(el, success, response) {

  pwDialogWindow.center();
  /* center before showing so it doesn't jump */
  pwDialogWindow.show();

}

function gnCallback(el, success, response) {
  if (!success) {
    displayFailureDialog(response);
    gnDialogWindow.show();
    /* need to show before we try to close */
    gnDialogWindow.close();
  }
  else
  {
  gnDialogWindow.center();
  /* center before showing so it doesn't jump */
  gnDialogWindow.show();
  updateGeneList(gnDialogWindow.initialConfig.pathwayName);
  checkSelectedGenes(gnDialogWindow.initialConfig.pathwayName);
  }
}

function dialogCallback(el, success, response) {

  /* For IE8 protection against 6000px-wide dialogs: */
  if (pwDialogWindow.container) {
    var wbDialogContent = pwDialogWindow.container.child('div.wbDialog.wbHelp');
    if (!wbDialogContent) // Then must be a settings dialog which has a <form> not a <div> as content
    {
      wbDialogContent = pwDialogWindow.container.child('form.wbDialog.wbForm');
    }

    if (wbDialogContent) {
      /* Force width of pwDialogWindow based on contents */
      var scrollBarWidth = (Ext.isIE ? 52 : 64);
      var divWidth = parseInt(wbDialogContent.getStyle('width'));
      divWidth = (isNaN(divWidth) ? wbDialogContent.getComputedWidth() : divWidth);
      pwDialogWindow.setWidth(divWidth + scrollBarWidth);
      /* Force height of pwDialogWindow based on contents */
      var divHeight = parseInt(wbDialogContent.getStyle('height'));
      divHeight = (isNaN(divHeight) ? wbDialogContent.getComputedHeight() : divHeight);
      pwDialogWindow.setHeight(divHeight);
    }
  }
  if (!success) {
    displayFailureDialog(response);
    pwDialogWindow.show();
    /* need to show before we try to close */
    pwDialogWindow.close();
  } else {
    pwDialogWindow.center();
    /* center before showing so it doesn't jump */
    pwDialogWindow.show();
  }
}

function closeGeneWindow() {
  toolWindow = Ext.WindowMgr.get('geneWin');
  if (toolWindow && toolWindow.show && toolWindow.close) {
    toolWindow.show();
    toolWindow.close();
  }
}


function findUniqueGenes()
{
  var geneLists = document.getElementsByClassName("geneList");
  var uniqueGenes = [];
  for (i = 0; i <= geneLists.length - 1; i++) {
      curGenes = geneLists[i].value.split(/,/);
      for (j = 0; j <= curGenes.length - 1; j++) {
        k=0;
          foundGene = false;
          while(k<= uniqueGenes.length-1 && !foundGene)
          {
            if(uniqueGenes[k] == curGenes[j]) {foundGene=true;} else {k++;}
          }
          if(!foundGene && curGenes[j].match(/\S/)){uniqueGenes.push(curGenes[j]);}
      }
  }
  return uniqueGenes;
}

function addGenesAndSubmit() {
  var uniqueGenes = findUniqueGenes();
  for (i = 0; i <= uniqueGenes.length - 1; i++) {
    document.getElementById('geneNames').value += "," + uniqueGenes[i];
  }
  document.getElementById('searchForm').submit();
}

function closeToolWindows() {
  pageMask.hide();
  toolWindow = Ext.WindowMgr.get('geneWin');
  if (toolWindow && toolWindow.show && toolWindow.close) {
    toolWindow.show();
    toolWindow.close();
  }
  toolWindow = Ext.WindowMgr.get('pathwayWin');
  if (toolWindow && toolWindow.show && toolWindow.close) {
    toolWindow.show();
    toolWindow.close();
  }

}

function checkSelectedGenes(listName)
{
  var chkBoxDiv = document.getElementById("chkBoxDiv");
  var chkBoxes = chkBoxDiv.getElementsByTagName("input");
  var curGeneList = document.getElementById(listName).value.split(/,/);
  for (j = 0; j <= chkBoxes.length - 1; j++) {
          k=0;
          foundGene = false;
          while(k<=curGeneList.length-1 && !foundGene)
          {
            if(curGeneList[k] == chkBoxes[j].value) {foundGene=true;} else {k++;}
          }
          if(foundGene) {
            //If checked gene exists in list, do nothing
          chkBoxes[j].checked = true;
          }
  }
}

  function updateGeneSelection(listName) {
  var chkBoxDiv = document.getElementById("chkBoxDiv");
  var chkBoxes = chkBoxDiv.getElementsByTagName("input");
  var geneLists = document.getElementsByClassName("geneList");
  for (i = 0; i <= geneLists.length - 1; i++) {
      curGenes = geneLists[i].value.split(/,/)
      for (j = 0; j <= chkBoxes.length - 1; j++) {
          k=0;
          foundGene = false;
          while(k<=curGenes.length-1 && !foundGene)
          {
            if(curGenes[k] == chkBoxes[j].value) {foundGene=true;} else {k++;}
          }
          if(foundGene) {
            //If checked gene exists in list, do nothing
            if(!chkBoxes[j].checked) //exists in list but has now been unchecked
            {
              curGenes.splice(k,1);
            }
          }
          else
          {
            if(chkBoxes[j].checked && geneLists[i].id==listName) // gene is not found, should be added if checked only to current list
            {
              curGenes.push(chkBoxes[j].value);
            }
          }
      }
      document.getElementById(geneLists[i].id).value = curGenes.join(',').replace(/^,/,"");
  }
}

function updateGeneList(listName) {
  var chkBoxDiv = document.getElementById("chkBoxDiv");
  var chkBoxes = chkBoxDiv.getElementsByTagName("input");
  var geneLists = document.getElementsByClassName("geneList");
  var curGeneList = document.getElementById(listName).value.split(/,/);
  for (i = 0; i <= geneLists.length - 1; i++) {
    if(geneLists[i].id!=listName){
      curGenes = geneLists[i].value.split(/,/)
      for (k = 0; k <= curGenes.length - 1; k++) {
          j=0;
          foundGene = false;
          while(j<=chkBoxes.length-1 && !foundGene)
          {
            if(chkBoxes[j].value == curGenes[k]) {foundGene=true;} else {j++;}
          }
          if(foundGene) {
            l=0;
            foundGeneinList = false;
            while(l<=curGeneList.length-1 && !foundGeneinList)
          {
            if(curGeneList[l] == curGenes[k]) {foundGeneinList = true;} else {l++;}
          }
          if(!foundGeneinList) {curGeneList.push(curGenes[k]);}
          }
      }
  }
  }
      document.getElementById(listName).value = curGeneList.join(',').replace(/^,/,"");
}
