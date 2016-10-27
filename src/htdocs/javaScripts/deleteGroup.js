
// function for single annotation delete confirmation
function confirmDelete (num, orderNum) {
     if (confirm ("Delete just  annotation " + orderNum + " ?") ){
        $("okDelete_" + num).value="1";
        $("btnDelete_" + num).value="btnDelete_" + num;
        $('editorForm').submit();
     }
     else {
          $("okDelete_" + num).value="0";
     
     }
}

