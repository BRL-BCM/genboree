function selectAll(numAnnos) {
   if (confirm("This operation will select all annotations, including those in other pages. \n\nAre you sure?")) {
    for (ii=0; ii<numAnnos; ii++) {
        $("checkBox_" + ii).checked = true;
        var tempdivid ="colorImageId"+ii;
        var tempinputid ="hiddenInputId"+ii;
        $(tempdivid).style.backgroundColor=  $('AllimageId').style.backgroundColor;
        $(tempinputid).value=   $('hiddenInputId').value;
    }
    }
    else {
     return false; 
    }
}

function unSelectAll(numAnnos, color) {
 for (ii=0; ii<numAnnos; ii++) {
       document.getElementById('checkBox_' + ii).checked = false;

      var tempdivid ="colorImageId"+ii;
      var tempinputid ="hiddenInputId"+ii;
      $(tempdivid).style.backgroundColor= color
      $(tempinputid).value=   color;

    }
}
