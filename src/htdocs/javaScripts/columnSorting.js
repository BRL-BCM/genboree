
function hideArrow(colId , alength ) {
	var i = 0 ; 	
	for (i=0; i<alength; i++) {    
		if (i!= colId && $('span_'+ i)){
			$('span_'+ i).innerHTML= '&nbsp;';
		}
	}
}

function sortingSampleName(alength) {
		var continueSorting = false;
		var sortingOrder = "ascending order"; 
		var ARROW = '&uarr;'; 
	    var colName = 'sampleName'; 
		var span = $('span_sampleName'); 
		if (span) {
			if (span.getAttribute("sortdir") == 'down') {
				sortingOrder = "ascending order"; 
			} 
			else if (span.getAttribute("sortdir") == 'up') {
				sortingOrder = "descending order"; 
			}
			else {
				if (sortingArrow =="down") {
				sortingOrder = "ascending order"; 
				}
				else if (sortingArrow =="up") {
					var lastSortingName = $('sortingColumnName').value
					if (colName != null && lastSortingName != null && lastSortingName == colName) {             
						sortingOrder = "descending order";  
					}
					else if  (colName != null && lastSortingName != null && lastSortingName != colName){
						sortingOrder = "ascending order"; 
					}
				}
				else {
					sortingOrder = "ascending order";  	
				}
			}
		}
		else {   
			$('sampleName').innerHTML= '<a href="#" class="sortheader"><font color="white"><nobr>Sample</nobr></a></font><span id="sampleName"  class="sortarrow">' + ARROW+ '</span>';
			$("sortingColumnOrder").value = "up"; 	
		}
			
	if ( !confirm("\nNOTE:\nYou are about to sort your dataset in " + sortingOrder +". \nIt may take some time to order your databaset, depending on" +  
	" its structure.\nFollowing the preparation phase, browsing your data should be reasonably responsive.\n\n" + 
	"Do you still want to proceed?"))
	return; 

	if (span && sortingOrder == "ascending order" ) {
		span.setAttribute('sortdir','up');
		$("sortingColumnOrder").value = "up"; 	
		ARROW = '&uarr;'; 
	}
	else if (span && sortingOrder == "descending order" ) {
		ARROW = '&darr;';
		span.setAttribute('sortdir','down');
		$("sortingColumnOrder").value = "down"; 	
	}
	
		if (span) 
		span.innerHTML = ARROW;
	
	hideArrow(-1, alength) ; 
	$('sortingColumnName').value = colName;  
	//alert (" before submit"   + colName + "  length " +  colName.length ); 
	
	viewForm.submit(); 
}






function sortingByColumn(colID, alength, colName ) {
		var continueSorting = false;
		var sortingOrder = "ascending order"; 
		var ARROW = '&uarr;'; 
		var span = $('span_'+ colID); 
		if (span) {
			if (span.getAttribute("sortdir") == 'down') {
				sortingOrder = "ascending order"; 
			} 
			else if (span.getAttribute("sortdir") == 'up') {
				sortingOrder = "descending order"; 
			}
			else {
				if (sortingArrow =="down") {
				sortingOrder = "ascending order"; 
				}
				else if (sortingArrow =="up") {
					var lastSortingName = $('sortingColumnName').value
					if (colName != null && lastSortingName != null && lastSortingName == colName) {             
						sortingOrder = "descending order";  
					}
					else if  (colName != null && lastSortingName != null && lastSortingName != colName){
						sortingOrder = "ascending order"; 
					}
				}
				else {
					sortingOrder = "ascending order";  	
				}
			}
		}
		else {   
		$('id_' + colID).innerHTML= '<a href="#" class="sortheader"><font color="white"><nobr>' + unescape(colName) + '</nobr></a></font><span id="span_' + colID + '" class="sortarrow">' + ARROW+ '</span>';
		$("sortingColumnOrder").value = "up"; 	
		}
			
	if ( !confirm("\nNOTE:\nYou are about to sort your dataset in " + sortingOrder +". \nIt may take some time to order your databaset, depending on" +  
	" its structure.\nFollowing the preparation phase, browsing your data should be reasonably responsive.\n\n" + 
	"Do you still want to proceed?"))
	return; 

	if (span && sortingOrder == "ascending order" ) {
		span.setAttribute('sortdir','up');
		$("sortingColumnOrder").value = "up"; 	
		ARROW = '&uarr;'; 
	}
	else if (span && sortingOrder == "descending order" ) {
		ARROW = '&darr;';
		span.setAttribute('sortdir','down');
		$("sortingColumnOrder").value = "down"; 	
	}
	
		if (span) 
		span.innerHTML = ARROW;
	
	hideArrow(colID, alength) ; 
	$('sortingColumnName').value = colName;  
	//alert (" before submit"   + colName + "  length " +  colName.length ); 
	
	viewForm.submit(); 
}


