var proceed = false;
var layoutName;
var allChromosomes = "All Chromosomes";
var showAllChromosome = false;
if ($('chrSelNames')) {
var chr = $('chrSelNames').value;
if (chr && chr.indexOf (allChromosomes) >= 0 )
showAllChromosome = true;
}
var generalWarnView = "\nNOTE:\nIt may take some time to prepare your dataset for viewing, depending on" +
" its structure. Please be patient during this preparation phase.\n\n" +
"Following the preparation phase, browsing your data should be reasonably responsive.\n\n";
var sortTextWarn1 = "\nWARNING:\n"
+"Sorting by annotation comments or sequences may take a long time and is generally not recommended due to their typically large size.";
var sortTextWarn2 =  "\n\nDo you still want to proceed?\n";

var generalWarnDownload = "\nNOTE:\nINOTE: depending on the amount of data, the download may take some time to start. " +
" The download will be throttled.\n\n" +
"NOTE: Please 'SAVE' the LFF file rather than opening it, since your computer probably won't have an application for opening LFF files." +
"\n\nDepending on your browser, you should make sure the file name makes sense (e.g. Internet Explorer 6 has a bug where the download file will have an inappropriate name, rather than our suggested name).";

function  displayWarning (numAnno, maxLimit) {
if (numAnno >= maxLimit) {
if (confirm("Display and order "  + numAnno + "  annotations may take a long time. \n Do you still want too proceed?  " )) {
return true;
}
else
return false;
}
else
return true;
}

function setAllChromosome () {
	showAllChromosome = false;

if ($('chrSelNames')) {
var chr = $('chrSelNames').value;
if (chr && chr.indexOf (allChromosomes) >= 0 )
showAllChromosome = true;
}
}


function  processDeleteLayout (myform) {
	   var selectionForm = $('selectionForm');
	   var layout = $('viewNames').value;
	//   alert ("  to be deleted " + layout);
		var lo = unescape (layout);
		if (!isLayoutOwner)     {
			alert ("Sorry, you don't have access rights to delete layout \"" + lo + "\".   Either you " +
			"must be the creator of this layout or you must be an administrator for this group.");
			return ;
		}

		if (lo && lo.indexOf('Default All Annos')>=0) {
			alert ("Default Layout can not be deleted.");
			return;
		}

		if (lo && lo.indexOf('Default Grouped Annos')>=0) {
			alert ("Default Layout can not be deleted.");
			return;
		}

		if (lo && lo.indexOf('Create New')>=0) {
			alert ("Please select a layout for deletion.");
			return;
		}

		if (confirm("You are about to delete layout \""  + lo + "\" permanently. \nAre you sure?" ))
		{
			 $('crv').value ="1";
			 $('dfcrv').value = "1";
			$('deleteLayoutTxt').value = layout;
		  selectionForm.submit();
		}
		else
		return;
	}


function  processRCV() {
	if ($('totalNumAnnotations') && $('totalNumAnnotations').value == 0 )
	   return;

	var defButton = "Show Layout Interface";
	var  crButton = "Show Simple Interface";
	 var btnValue = $('modeButton').value;
	// case 1: create mode
   if(btnValue && btnValue.indexOf('Show Layout Inter')  <0 ) {
		$('modeButton').value = defButton;
	if ( $('viewNames').selectedIndex ==0)
		$('viewNames').selectedIndex = 1;

		// if (showButtons) {
		    $('dfjsparams').value  = layoutArray['Default%20Grouped%20Annos.'];
    	$('buttoncr').style.display = "none";
		$('buttondf').style.display = "block";
		$('selectUI').style.display = "none";
		$('radioCrView').value = "";
		$('viewInput').value = 'Default Grouped Annos.';
		$('dfviewInput').value = 'Default Grouped Annos.';
		if ( $('selectUI'))
		$('selectUI').style.display = "none";
		changeLayout (2);

   }    //  default mode
    else if(btnValue && btnValue.indexOf('Show Layout Inter') >=0 ) {
	    $('modeButton').value = crButton;
	     $('radioCrView').value = " checked";
		 $('buttondf').style.display = "none";

		$('selectUI').style.display = "block";
		$('jsparams').value  = layoutArray['Default%20Grouped%20Annos.'];

		var showButtons = false;
		//$('viewInput').value = 'Default Grouped Annos.';
		//$('dfviewInput').value = 'Default Grouped Annos.';
	     if ($("showGroup"))
	     showButtons = true;
	    changeLayout (1);
	    if (!showButtons)
	    	$('buttoncr').style.display = "block";
	     else
	        $('buttoncr').style.display = "none";
   }
}


  function changeLayout (layoutMode) {
  }


function  processDFSubmit (mode) {
	if ($('totalNumAnnotations') && $('totalNumAnnotations').value == 0 )
		   return;
	var jsparams = $('dfjsparams').value;
	setAllChromosome() ;
	var defButton = "Show Layout Interface";
	var  crButton = "Show Simple Interface";
	 var btnValue = $('modeButton').value;
   if(btnValue && btnValue.indexOf('Layout Inter')  <0 ) {
	recordOrder();
	}

	 var df = 2;  // default to group annotation
	if ($('crv') && $('showGroup') && $('showGroup').checked)
	    df = 1;

	else if (!$('crv') && $('grouping') && $('grouping').value == "" )
	    df = 1;


	if (!hasTrack( mode) )
	   return;

	if (!df) {
		var selectedChr = $('chrSelNames').value;
		$('dfchrName').value = selectedChr;
		$('dfchrStop').value = $('chrStops').value ;
		$('dfchrStart').value = $('chrStarts').value ;
		$('dfrid').value = $('rid').value ;
	}
	else {
		$('dfchrName').value = allChromosomes;
	}

			var chr = $('chrSelNames').value;
		if ($('chrStops'))
		$('dfchrStop').value =  $('chrStops').value;
		if ($('chrStarts'))
		$('dfchrStart').value =  $('chrStarts').value;
		if (chr.indexOf (allChromosomes) < 0 ) {
			if (!validateChromosome())
			return;
		}
		else {
			var chrstart = $('dfchrStart').value;
			var chrStop = 	$('dfchrStop').value;
			var chrid =  chromosomeNameArray[ chr ];
			var chrlength = chromosomeArray[ chrid ];
			if (chrlength && chrstart == 1 && chrStop == chrlength  ) {
				//showAllChromosome = true;
		    }
		}
		processChromosomeChange();
		$('chrName').value = $('chrSelNames').value;
		$('dfchrName').value = $('chrSelNames').value;

	$('viewDataDF').value = "1";

	if (mode ==1 ) {
		if (df == 2) {  // df 2
			$('selectionForm').action = "viewAnnotation.jsp";
	   }
		else if (df == 1) {   // df 1
			$('selectionForm').action = "viewGroupAnnotations.jsp";
				if (!showAllChromosome)
				   $('selectionForm').action = "viewGroupAnnotationsByRegion.jsp";

		}
		else {  //  create view or user's view
				   $('selectionForm').action = "viewAnnotation.jsp";
				if ($('grouping') && $('grouping').value.indexOf ("checked") >=0) {
				$('selectionForm').action = "viewGroupAnnotations.jsp" ;

				if (!showAllChromosome)
				   $('selectionForm').action = "viewGroupAnnotationsByRegion.jsp";
				}
		}
	}
	else if (mode == 0 ) {
		if (df == 2)
		$('selectionForm').action = "downloadAnnotations.jsp";
		else if (df == 1)
		$('selectionForm').action = "downloadGroupAnnotations.jsp";
		else {
			$('selectionForm').action ="downloadAnnotations.jsp";
			if ($('grouping') && $('grouping').value.indexOf("checked") >=0) {
				$('selectionForm').action = "downloadGroupAnnotations.jsp"
			}
		}
	}

//	alert ( $('dfjsparams').value  + " before suubmit 210 " );

			selectionForm.submit();
	selectionForm.action = "displaySelection.jsp";
}


function  submitChromosomeChange () {
    var selectedChr = $('chrSelNames').value;

	$('chrName').value = selectedChr;
	$('chrStop').value = $('chrStops').value ;
	$('chrStart').value = $('chrStarts').value ;
	$('rid').value = $('rid').value ;
	$('chrChanged').value= "1";
	    var btnValue = $('modeButton').value;
   if(btnValue && btnValue.indexOf('Layout Inter')  <0 ) {
	$('crv').value= "1";
	      	$('dfcrv').value= "1";
			 }
	else {
				$('crv').value= "";
	   	$('dfcrv').value= "";

		 }
	$('selectionForm').submit();
	//$('createview').value= "";
}


function  processChromosomeChange () {
	var selectedChr = $('chrSelNames').value;
	$('chrName').value = selectedChr;
	$('chrStop').value = $('chrStops').value ;
	$('chrStart').value = $('chrStarts').value ;
	$('rid').value = $('rid').value ;
	$('chrChanged').value= "1";

//	selectionForm.submit();

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
	viewForm.submit();
}


function hideArrow(colId , alength ) {
var i = 0 ;
for (i=0; i<alength; i++) {
if (i!= colId && $('span_'+ i)){
$('span_'+ i).innerHTML= '&nbsp;';
}
}
}


function   toggleRadio (totalNumAnnotations, numSelectedAssociation) {
var warnMsg = "\nDue to the large amount of data in the selected track(s), grouping of annotations in the tabular view is disabled." +
"\n\nIf you have more than one track selected, you may try unselecting all but he most relevant track.\n";

if (  numSelectedAssociation >= 1000000  ||(totalNumAnnotations && totalNumAnnotations >= 300000)){
if ($('showGroup')) {
	$('groupMode1').disabled = true;
	$('groupMode2').disabled = true;

	$('showGroup').checked = false;
	}
	alert(warnMsg);
	return;
}
	else {
		if ($('groupMode1') && $('groupMode1').disabled )
		$('groupMode1').disabled = false;

		else if ($('groupMode1') && !$('groupMode1').disabled )
		$('groupMode1').disabled = true;

		if ($('groupMode2') && $('groupMode2').disabled )
		$('groupMode2').disabled = false;

		else if ($('groupMode2') && !$('groupMode2').disabled )
			$('groupMode2').disabled = true;
	}
}

function    parseJSParams (s,  isSort) {
var  elements =  s.split("]");
var  names = null;

if (elements && elements.length >0)
var  arr = new Array(elements.length);
var count = 0;
if (s != null)  {
elements[0] = "," + elements[0];
for (var j=0; j<elements.length; j++){
var  items = elements[j].split(",");
if (items != null && items.length ==3) {
var  booValue = items[2];
if (items[1] != null)
items[1] = items[1].substring(1, items[1].length-1);
if (isSort)
items[1] = items[1].substring(0, items[1].length-5);

if (booValue != null && booValue.indexOf("1")>=0){
arr[j] = (items[1]);
count++;
}
else
arr[j] = null;
}
}
}
names = new Array(count);
var counter = 0;
for (var i=0; i<elements.length; i++)
if (arr[i] != null) {
names [counter] = arr[i];
counter ++;
}

return names;
}


//-----------------------------------------------------------------------------
// POP-UP HELP: in this function, make a pop-up help for each parameter/field in the form.
// This is done by supplying a helpSection arg indicating what help info to display.
//-----------------------------------------------------------------------------
function overlibHelp(helpSection)
{
var overlibCloseText = '<FONT COLOR=white><B>X&nbsp;</B></FONT>' ;
var leadingStr = '&nbsp;<BR>' ;
var trailingStr = '<BR>&nbsp;' ;
var helpText;

if(helpSection == "showGroup")
{
overlibTitle = "Help: Show annotation groups" ;
helpText = "\n<UL>\n" ;
helpText += "  <LI>An annotation group is formed from annotations with same name, track, and chromosome.</LI>" ;
helpText += "  <LI>An example of annotation group is a gene with one or more exons.</LI>" ;
helpText += "  <LI>Please refer to <a HREF=\"showHelp.jsp?topic=layoutSetup#groupingData\" target=\"_helpWin\">Grouping of Annotation Data</a> for more.</LI>" ;

helpText += "</UL>\n\n" ;
}



if(helpSection == "helpLayout")
{
	overlibTitle = "Help: What is Layout?" ;
	helpText = "\n<UL>\n" ;
	helpText += "  <LI>Layout is a custom designed form of data view.</LI>" ;
	helpText += "  <LI>If you are new to tabular view, you can select a layout from the list under \"Table Layout\", or just use the default layout.</LI>" ;
	helpText += "  <LI>If you are familar with tabular view, or wish to create your own, you can do so by clicking on the check box \"Show Layout Interface\".</LI>" ;
	helpText += "  <LI>Please refer to  <a class=\"helpNav\" HREF=\"showHelp.jsp?topic=layoutSetup\"  target=\"_helpWin\">Tabular View and Layout Design</a> for more.</LI>" ;
	helpText += "</UL>\n\n" ;
}


overlibBody = helpText;
return overlib( overlibBody, STICKY, DRAGGABLE, CLOSECLICK, FGCOLOR, '#CCF8FF', BGCOLOR, '#9F833F',
CAPTIONFONTCLASS, 'capFontClass', CAPTION, overlibTitle, CLOSEFONTCLASS, 'closeFontClass',
CLOSETEXT, overlibCloseText, WIDTH, '300');
}


function validateForm () {

// if database is not selected, return;
if ($('rseq_id').value == "" ) {
alert(" Please select a database ");
return false;
}
return true;
}

	function selectAllDisplay(n){
		for(var ii=0; ii<n; ii++){
			$('item_' + ii+ '_chkdiv').style.backgroundPosition = "-10px 0px" ;
		    $('item_' + ii+ '_chkdiv').className ="checkBoxDiv1";
			trackName = $('item_' + ii + '_trackName').value;
			if (trackName)
				$(trackName).value = "1";
		}
	}

	function clearAllDisplay(n){
		var trackName = null;
		for(var ii=0; ii<n; ii++){
			$('item_' + ii+ '_chkdiv').style.backgroundPosition = "0px 0px" ;
			$('item_' + ii+ '_chkdiv').className ="checkBoxDiv";
			trackName = $('item_' + ii + '_trackName').value;
			if (trackName)
			$(trackName).value = "0";
		}
	}

	function clearAllSort(n){

		var trackName ;
		// $("saName_sort").value = "0";
		// $('sortitem_chkdiv').style.backgroundPosition = "0px 0px" ;
			for(var x=0; x<n; x++){
				if ($('sortitem_' + x + '_trackName'))
					trackName = $('sortitem_' + x + '_trackName').value;

				  if (trackName) {
					$(trackName).value = "0";
					$('sortitem_' + x + '_chkdiv').style.backgroundPosition = "0px 0px" ;
					 	$('sortitem_' + x + '_chkdiv').className  ="checkBoxDiv";
				}
			}
	}

function  findSortNum (numAtt) {
var num = 0;
for (i=0; i<numAtt; i++) {
if ($("displayOrder" + i ).checked == 'true')
num ++;
}
return  num;
}

function isSelected (displayNames) {
var ststus = 0;
var isChecked = false;
for (i=0; i<displayNames.length; i++) {
status = displayNames[i][2];
if (status == 1)
{
isChecked = true;
break;
}
}

return isChecked;
}

function saveLayoutConfirmation(btn){
	   setAllChromosome ();
	if (btn== 'yes')  {
		Ext.MessageBox.prompt('Layout Input', 'Please enter layout name:', saveLayout);
	}
	else {
		var formId = "viewForm";
		var target = "viewGroupAnnotations.jsp"
		if ($('showGroup') && !$('showGroup').checked) {
		target = "viewAnnotation.jsp" ;

		}
		if ($('showGroup') && $('showGroup').checked) {
		if (!showAllChromosome)
		target = "viewGroupAnnotationsByRegion.jsp";
		}
		submitForm2Target (formId, target);
	}
};

function saveDownloadLayoutConfirmation(btn){
	if (btn && btn== 'yes')  {
	Ext.MessageBox.prompt('Layout Input', 'Please enter layout name:', saveDownloadLayout);
	}
	else  if (btn && btn== 'no') {
	var formId = "viewForm";
	var target = "downloadAnnotations.jsp"
	if ($('showGroup') && $('showGroup').checked)
	target = "downloadGroupAnnotations.jsp"
	submitForm2Target (formId, target);
	}
};

function saveLayout(btn, text) {

	setAllChromosome () ;

	if (btn == 'cancel') {

	return false;
	}
	else {
		text = trim(text);
		if (!text|| text.length ==0 ) {
			Ext.Msg.show({
			title: 'Layout Input',
			msg: '<font color="red">Sorry, empty name is not allowed.</font>' + '<br><br>Please enter layout name again: ',
			width: 300,
			buttons: Ext.MessageBox.OKCANCEL,
			prompt: true,
			fn: saveView});
		}
		else {
			if (text.indexOf("Default All Anno") >=0 || text.indexOf ("Default Group") >= 0 ) {
				alert ("Default Layout can not be changed." );
				return ;
			 }

			var   target ="viewAnnotation.jsp";
			var  encodedText = escape (text);
			layoutName = encodedText;
			if ( layoutNames[encodedText]) {
			Ext.MessageBox.confirm('Confirmation', 'Are you sure you want to overwrite layout \"'  + text  + '\" that already exists?', showResult1);
			}
			else {
			$('viewStatus').value = "1";
			$('viewInput').value =encodedText;
			target ="viewGroupAnnotations.jsp";
			if ($('showGroup') && !$('showGroup').checked ){
			target ="viewAnnotation.jsp";
			}
			else  if ($('showGroup') && $('showGroup').checked ){
			if (!showAllChromosome)
			target = "viewGroupAnnotationsByRegion.jsp";
			}
			submitForm2Target ('viewForm', target);
			}
		}
	}
}

function saveDownloadLayout(btn, text) {
if (btn == 'cancel') {
/*  var formId = "viewForm";
var target = "viewAnnotation.jsp"
submitForm2Target (formId, target);

*/
return false;
}
else {
	text = trim(text);
	if (!text|| text.length ==0 ) {
		Ext.Msg.show({
		title: 'Layout Input',
		msg: '<font color="red">Sorry, empty name is not allowed.</font>' + '<br><br>Please enter layout name again: ',
		width: 300,
		buttons: Ext.MessageBox.OKCANCEL,
		prompt: true,
		fn: saveView});
	}
	else {
		 if (text.indexOf("Default All Anno") >=0 || text.indexOf ("Default Group") >= 0 ) {
           alert ("Default Layout can not be changed. " );
            return ;
          }
		var  encodedText = escape (text);
		layoutName = encodedText;
		if ( layoutNames[encodedText]) {
		Ext.MessageBox.confirm('Confirmation', 'Are you sure you want to overwrite layout \"'  + text  + '\" that already exists?', showDownloadResult);
		}
		else {
		$('viewStatus').value = "1";
		$('viewInput').value =encodedText;
		addOption (0, text, 'viewNames');
		refreshLayout ();
		viewForm.action ="downloadAnnotations.jsp";
		viewForm.submit();
	}
	}
	}
}

	function addOption (index, text, selId ) {
	var myoption = new Option(text,index);
	myoption.value = text;
	myoption.selected = " selected";
	$(selId).options.add(myoption, index);
	}

	function refreshLayout ()  {
	var jsparams =  $("jsparams").value;
	var displayNames = eval ('(' + jsparams + ')').rearrange_list_1;
	var sortNames =  eval ('(' + jsparams + ')').rearrange_list2;
	layoutDisplayNames = new Array();
	for (ii=0; ii<displayNames.length; ii++){
	var thisname = displayNames[ii][1];
	var thisNameSelected =(displayNames[ii][2] == 1);
	if ( thisNameSelected) {
	layoutDisplayNames[thisname] = "1";
	}
	}

	layoutSortNames = new Array();
	if (sortNames && sortNames.length >0) {
	for (ii=0; ii<sortNames.length; ii++){
	var sortName = sortNames [ii][1];

	if (sortName && sortName.indexOf ("_sort") > 0)
	sortName = sortName.substring(0, sortName.indexOf("_sort"));
	var sortNameSelected =(sortNames[ii][2] == 1);
	if ( sortNameSelected ) {
	layoutSortNames[sortName] = "1";
	}
	}
	}
	};





function changeGroupMode (groupMode) {
	if (groupMode == 'terse' || groupMode == 'verbose') {
	    if ($('showGroup')) {
			$('showGroup').checked = true;

			$('groupMode1').disabled = false;
		$('groupMode2').disabled = false;
		if (groupMode == 'terse')
			$('groupMode1').checked =  true;
		else
			$('groupMode2').checked = true;
			}
	}
	else {
		if ($('showGroup')) {
		$('showGroup').checked = false;
		$('groupMode1').disabled = true;
		$('groupMode2').disabled = true;     }
	}

}


 function updateViewParams (displayArr, sortArr, grpMode) {
	var selectedView = $('viewNames').value;

	if (selectedView  && selectedView.indexOf("Create New") <0 )  {
		var templayoutDisplayNames = new Array();
        var mi = 0;
		for (mi=0; mi<displayArr.length; mi++) {
				var myorder = mi +1;
				templayoutDisplayNames[displayArr[mi]] = "" + myorder;
			}

		//layoutDisplayNames =templayoutDisplayNames;
		//layoutSortNames = new Array();
		for (n=0; n<sortArr.length; n++) {
			var myorder = n +1;
			//layoutSortNames[sortArr[n]] = ""  + n ;
			}
	   groupMode =  grpMode ;
	}
	$('viewInput').value = selectedView;
	$('dfviewInput').value = selectedView;
 }


function  setDefault () {
		if (alldisplayNames ) {
		groupModee =  "terse";

		var displayNames = alldisplayNames;
		var sortNames = displayNames;
		if (displayNames && displayNames.length >0) {
		sortNames = new Array();
		for (i=0; i<displayNames.length; i++ ) {

		layoutDisplayNames[displayNames[i]] = "1" ;
		if (i>0) {   sortNames [i-1] = displayNames[i];
		layoutSortNames[sortNames[i-1]] = ""  + i ;  }
		}
		}

		orderedLayoutDisplayNames = displayNames;
		orderedLayoutSortNames = sortNames;

	var displayString = "";
	for (i=0; i<alldisplayNames.length; i++) {
				var name = alldisplayNames[i];
				var booValue = "1";
				var item = "item_" + i;
				var index = i +1;
				checkBoxDiv =	"checkBoxDiv1";
				var dname = unescape(name);
				dname = dname.substring(0, dname.length -8 ) ;
				$(item+ '_chkdiv').style.backgroundPosition = "-10px  0px";
				$(item+ '_chkdiv').className = "checkBoxDiv1";
				if ( $(item+ "_span"))
				$(item+ "_span").innerHTML  = index + ".";

				if ($(item+ '_span2'))
				$(item+ '_span2').innerHTML   = dname;

				if ($(item + '_trackName'))
				$(item + '_trackName').value = name;
				if  ($(name))
				$(name).value = booValue;
				}
		}

		 sortString = "";
		for (i=0; i<alldisplayNames.length; i++) {
			  name = alldisplayNames[i];
			  name = name.replace("_display", "_sort");
			var item = "sortitem_" + i ;
			var sortIndex = i +1;
		    var dname = unescape(name);
			dname = dname.substring(0, dname.length -5 ) ;
	        if ($(item+ '_chkdiv')) {
				$(item+ '_chkdiv').className = "checkBoxDiv";
				$(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
			}

			if ( $(item+ "_span"))
			$(item+ "_span").innerHTML = sortIndex + ".";

			if ($(item+ '_span2'))
			$(item+ '_span2').innerHTML   = dname;

			if ($(item + '_trackName'))
			$(item + '_trackName').value = name;
			if($(name))
			$(name).value =  "0";
		}

	var selectedView = $('viewNames').value;
	$('viewInput').value = selectedView;
	$('dfviewInput').value = selectedView;

	var btnValue = $('modeButton').value;
	var defButton = "Show Layout Interface";
	var crButton = "Show Simple Interface";
	if(btnValue && btnValue.indexOf('Layout Inter') >=0){
		$('viewNames').selectedIndex = 0;
		$('buttoncr').style.display = "none";
		$('buttondf').style.display = "none";
		$('selectUI').style.display = "block";
		$('modeButton').value = crButton;
	}

	if ($('showGroup')) {
		$('showGroup').checked = true;
		$('groupMode1').disabled = false;
		$('groupMode2').disabled = false;
		$('groupMode1').checked =  true;
	}
}


function processLayoutChange (n) {
	$('layoutChanged').value = "1";
	var selectedView = $('viewNames').value;
	var encodedView = selectedView;
	if (selectedView)   {
	    encodedView = escape(selectedView);
		var myObj = layoutArray[encodedView];
		 if (selectedView.indexOf("Create New")  >=0 )  {
	          setDefault();
			   return;
		 }

		if ($('dfjsparams'))
			  $('dfjsparams').value = myObj;

		 if ($('viewfm')) {   // refresh web page for layout selections
			if ($('jsparams'))
			  $('jsparams').value =  myObj;

				if (myObj) {
				var displayNameArr = new Array ();
				var sortNameArr  = new Array();

			   var jsonObj = eval('(' + (myObj) + ')');
				var grpMode = jsonObj.groupMode;
				if (grpMode)
					changeGroupMode(grpMode);

					var displayNames = jsonObj.rearrange_list_1;
						displayNames = unescape (displayNames);
					var arr = displayNames.split(",");
					var infoArr = new Array ();
					 var index1 = 0;
					for (i=0; i<=arr.length; i++) {
					  if (i%3 ==0) {
						   if (i>0 && (i%3 ==0)) {
							   index1 = i/3 -1;
						  infoArr [index1] = tempArr;
								}
							tempArr = new Array();
						}
						if (i<arr.length) {
					  tempArr [i%3] = arr[i];
							}
					}
				   layoutDisplayNames = new Array();
			 	orderedLayoutDisplayNames = new Array();
					var checkBoxDiv = "";
					var  s = "";
					var index = 0;
					var displayedHash = new Array ();
						var count =  0;
				    var selectedIndex = 0;
			  // from saved json

				for (i=0; i<infoArr.length; i++) {
					   var tempArr = infoArr[i];
					displayNameArr [i] = tempArr[1];
					   var name = escape(tempArr[1]);
						   var booValue = tempArr[2];
						 if (name && name.indexOf("\"Edit\"") < 0 &&   !displayHash[name] ) {
							continue;       // skip attributes not belong to this ftype
						 }
						 else
							displayedHash[name] = "1";

				     count ++;
					  var item = "item_" + index;
					  index = index +1;
					   if (booValue && booValue == "1") {
						   $(item+ '_chkdiv').style.backgroundPosition = "-10px  0px";
						      $(item+ '_chkdiv').className = "checkBoxDiv1";
							   orderedLayoutDisplayNames[selectedIndex] = name;
						   selectedIndex++;
						    layoutDisplayNames [name] = selectedIndex;
						}
						else {
						   $(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
						     $(item+ '_chkdiv').className = "checkBoxDiv";
						}

						var dname = unescape(name);
						dname = dname.substring(0, dname.length -8 ) ;
						if ( $(item+ "_span"))
						    $(item+ "_span").innerHTML   = index + ".";

						if ($(item+ '_span2'))
						    $(item+ '_span2').innerHTML   = dname;

						 if ($(item + '_trackName'))
						 	 	 $(item + '_trackName').value = name;
					     if  ($(name))
						 $(name).value = booValue;
				 }

				if (alldisplayNames && alldisplayNames.length != displayNames.length) {
					for (i=0; i<alldisplayNames.length; i++) {
						  var name = alldisplayNames[i] ;
						 if (!displayedHash[name] ){   //   in ftype, but not in this layout-- list as unchecked
						   item = "item_" + count;
						   index = count + 1;
							var dname = unescape (name);
			$(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
			                 if ($(item+ "_span"))
							$(item+ "_span").innerHTML   = index + ".";
			          if ( $(item+ '_span2'))
							 $(item+ '_span2').innerHTML   = dname;
			$(item + '_trackName').value = name;
							   $(item+ '_chkdiv').className = "checkBoxDiv";
						  if ($(name))
							 $(name).value = "0";
							//layoutDisplayNames [name] = count;
							//	orderedLayoutDisplayNames[count] = name;
						 count ++;
						 }
				   }
				}
			var sortNames = jsonObj.rearrange_list2;
			sortNames = unescape (sortNames);

			var arr2 = sortNames.split(",");
			var sortArr = new Array ();
			index1 = 0;

			for (i=0; i<=arr2.length; i++) {
				if (i%3 ==0) {
					if (i>0 && (i%3 ==0)) {
						index1 = i/3 -1;
						sortArr [index1] = tempArr;
					}
					tempArr = new Array();
				}

				if (i<arr2.length) {
					tempArr [i%3] = arr2[i];
				}
			}
			  checkBoxDiv = "";
			var  sortString = "";
			var sortIndex = 0;
			var displayedSortHash = new Array ();
			count =  0;
		     var sortOrder = 1;
					layoutSortNames = new Array();
					orderedLayoutSortNames = new Array();

				for (i=0; i<sortArr.length; i++) {
					var tempArr =  sortArr[i];
				    sortNameArr [i] = tempArr[1] ;
					var name = escape(tempArr[1]);
					var testname = name.replace("_sort", "_display");

					var booValue = tempArr[2];
					if ( !displayHash[testname] ) {
						continue;
						}
					else
						displayedSortHash[name] = "1";

					count ++;
					var item = "sortitem_" + sortIndex ;
					sortIndex = sortIndex +1;

					if (booValue && booValue == "1") {
						$(item+ '_chkdiv').style.backgroundPosition = "-10px  0px";
						$(item+ '_chkdiv').className = "checkBoxDiv1";
						layoutSortNames [name] = sortOrder ;
						orderedLayoutSortNames[sortOrder-1] =  name;
						sortOrder++;
					}
					else {
						$(item+ '_chkdiv').className = "checkBoxDiv";
						$(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
					}
					var dname = unescape(name);

					dname = dname.substring(0, dname.length -5 ) ;
		         	$(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
						 if ( $(item+ "_span"))
						    $(item+ "_span").innerHTML   =  sortIndex + ".";

						if ($(item+ '_span2'))
						    $(item+ '_span2').innerHTML   = dname;

						 if ($(item + '_trackName'))
						 	 	 $(item + '_trackName').value = name;
					     if  ($(name))
						 $(name).value = booValue;
				}


				   count = 0;
				   if (displayedHash && displayedHash.size != displayNames.length) {
					for (i=0; i<alldisplayNames.length-1; i++) {
						  var name = alldisplayNames[i] ;
						 if (!displayedHash[name] ){
						   item = "sortitem_"  + count;

						 sortIndex = count +1;
						var dname = unescape (name);


						$(item+ '_chkdiv').className = "checkBoxDiv";
						$(item+ '_chkdiv').style.backgroundPosition = "0px  0px";
						 if ( $(item+ "_span"))
						    $(item+ "_span").innerHTML   =  sortIndex + ".";

						if ($(item+ '_span2'))
						    $(item+ '_span2').innerHTML   = dname;

						 if ($(item + '_trackName'))
						 	 	 $(item + '_trackName').value = name;
					     if  ($(name))
						 $(name).value = "0";
						count++;
							// layoutSortNames [name] = count;
					}
				   }
				}

			updateViewParams (displayNameArr, sortNameArr, grpMode);
				}
			}

// change display
	}

	$('viewNames').blur();

	}

	function getOrders (displayNames) {
		var currentOrder = new Array();
		var count = 0;
		for (ii=0; ii<displayNames.length; ii++){
		var thisname = displayNames[ii][1];
		var thisNameSelected =(displayNames[ii][2] == 1);
		if (thisNameSelected) {
			count ++;
			currentOrder[thisname] = count;
			//alert ("name " + thisname + " order " + count);
		}
		}
		return currentOrder;
	}

	function reorderArray (orderedlayoutDisplayNames,  displayNames) {
		var newOrder = new Array();
		var count = 0;
		var nameHash = new Array();
		for (ii=0; ii<displayNames.length; ii++){
			nameHash[ displayNames[ii][1]] = ii+1;
		}
		//alert ("  in function "  + orderedlayoutDisplayNames.length);
		for (ii=0; ii<orderedlayoutDisplayNames.length; ii++){
			var cname = orderedlayoutDisplayNames[ii];
			if (nameHash[cname]) {

				count++;
				//alert ("" + cname + "  count  " + count);
				newOrder[cname] = count ;
			}
		}
		return newOrder;
	}


	function getSortOrders (displayNames) {
		var currentOrder = new Array();
		var count = 0;
		for (ii=0; ii<displayNames.length; ii++){
		var thisname = displayNames[ii][1];
		var thisNameSelected =(displayNames[ii][2] == 1);
		if (thisNameSelected) {
		count ++;
		currentOrder[thisname] = count;
		}
		}
		return currentOrder;
	}


	function reorderSortArray (orderedlayoutSortNames,  mysortNames) {
		var newOrder = new Array();
		var count = 0;
		var nameHash = new Array();
		for (ii=0; ii<mysortNames.length; ii++){
		nameHash[ mysortNames[ii][1]] = ii+1;
		}
		for (ii=0; ii<orderedlayoutSortNames.length; ii++){
		var cname = orderedlayoutSortNames[ii];
		if (nameHash[cname]) {
		count++;
		newOrder[cname] = count ;
		}
		}
		return newOrder;
	}



   function isGrpChanged  () {
		var terseChecked =  $('groupMode1').checked ;
		var verboseChecked   =   $('groupMode2').checked ;
		var  grpChecked = $("showGroup").checked
	    var isChanged = false;
		if (grpChecked) {
			if (terseChecked && groupMode.indexOf ('terse') <0)
			isChanged  = true;
			if (verboseChecked && groupMode.indexOf('verbose')<0)
			isChanged = true;
			}

			if (!grpChecked) {
			if (groupMode && groupMode.indexOf('terse')>=0 )
			isChanged  = true;

			if (groupMode && groupMode.indexOf('verbose')>=0 )
			isChanged  = true;
		}
	   return isChanged;
	}


function hasDisplayNamesChecked ( displayNames){
	var myststus = 0;
	var isChecked = false;
	var ii = 0;
	for (ii=0; ii<displayNames.length; ii++) {
		mystatus = displayNames[ii][2];
		if (mystatus == 1) {
			isChecked = true;
			break;
		}
	}

	if (!isChecked) {
		alert("Please select some attribute name for display. ");
		//return false;
	}

		return  isChecked;

}




function submitForm(dataId, numAnno, maxLimit, total, numAtt, mode) {
	var viewform = $('viewForm');
	var chr = $('chrSelNames').value;
	var layoutChanged = false;
	var ok2go = false;


	if (chr.indexOf (allChromosomes) < 0 ) {
		if (!validateChromosome())
		return;

		$('chrStop').value =  $('chrStops').value;
		$('chrStart').value =  $('chrStarts').value;
	}
	else
		showAllChromosome = true;

	processChromosomeChange();
	$('chrName').value = $('chrSelNames').value;

	if (mode ==1)
		alert(generalWarnView);
	else if (mode ==0)
		alert (generalWarnDownload);

	recordOrder();  // new order
	var jsparams = viewform.jsparams.value;
	var jslayout =  selectionForm.jsparams.value ;

	if (jslayout) {
	   jslayout = unescape(jslayout);
	}

	var displayNames = eval ('(' + jsparams + ')').rearrange_list_1;
	var sortNames =  eval ('(' + jsparams + ')').rearrange_list2;
	if ( displayNames.length ==0) {
		alert("There is no attribute name for display. ");
		return false;
	}

    // check for empty display name selection
    if (!hasDisplayNamesChecked ( displayNames) )
		 return  false;
	var freeComments = escape("Anno. FreeComments");
	var annoSeq = escape("Anno. Seq");
	var trkChanged = ($('trackChanged').value == "1") ;
	var hasError  = false;
	var currentDisplayOrder = getOrders (displayNames);
	var selectedDisplayNames = new Array() ;
	var layoutDisplayOrder = new Array();

	//alert ("1315 all displayanmes " + displayNames.length +" ordered   " +  orderedLayoutDisplayNames.length );
	if (layoutDisplayNames)
		   layoutDisplayOrder = reorderArray(orderedLayoutDisplayNames, displayNames);

	for (ii=0; ii<displayNames.length; ii++){
		var thisname = displayNames[ii][1];
		var thisNameSelected =(displayNames[ii][2] == 1);
		if (thisNameSelected && !selectedDisplayNames [thisname]  ) {
			selectedDisplayNames [thisname] = 1;
		}

		if (!layoutDisplayNames [thisname]  && thisNameSelected) {
			layoutChanged = true;

		}

		if (!trkChanged) {
		// existing unselected
			if (layoutDisplayNames [thisname]  && !thisNameSelected) {
				layoutChanged = true;
			}
			var currentOrder = currentDisplayOrder [thisname];
			var layoutOrder = layoutDisplayOrder[thisname];
		// order changed
			if ( layoutDisplayNames [thisname] && layoutOrder && currentOrder && (layoutOrder != currentOrder) ) {
				layoutChanged = true;

			}
		}
	}


	var isdfLayout = false;
	var  numSelectedSortNames=0;
	var sortingText = false;

	if (sortNames && sortNames.length >0) {
		var currentSortOrder = getOrders (sortNames);

	 	//alert ("  num sortNames is  " + sortNames.length + " layout sortNames length  " + orderedLayoutSortNames.length );
		var layoutSortOrder = new Array();


		if (orderedLayoutSortNames)
			layoutSortOrder = reorderArray(orderedLayoutSortNames, sortNames);

		for (ii=0; ii<sortNames.length; ii++){
			var sortName = sortNames [ii][1];
			if (sortName && sortName.indexOf ("_sort") > 0)
			sortName = sortName.substring(0, sortName.indexOf("_sort"));
			if (sortName.indexOf ("_display") >0 )
				sortName = sortName.substring (0, "_display");

			var sortNameSelected =(sortNames[ii][2] == 1);
			if (sortNameSelected && !selectedDisplayNames[sortName + "_display"]) {
				hasError = true;
				alert ("\n\nYou have selected an attribute for sorting while it is not selected for display." +
				 " \n\nPlease select \"" +  unescape(sortName)  + "\" in the list under \"Display Order\".");
		      //  alert ("selected sortName " + sortName + " in array " + selectedDisplayNames[sortName + "_display"]);
				break;
				}

			if (sortNameSelected) {
				numSelectedSortNames ++;
				if (sortNameSelected && (sortName.indexOf(freeComments) >-1 || sortName.indexOf(annoSeq) >-1) )
				sortingText = true;
			 }

			sortName = sortName + "_sort";
			if (layoutSortNames[sortName]  && !sortNameSelected )  {
				   layoutChanged = true;
				}

				if (!layoutSortNames[sortName]  &&  sortNameSelected ) {
					layoutChanged = true;
				}

			var	currentSortIndex = currentSortOrder[sortName];
			var	layoutSortIndex = layoutSortOrder[sortName];


			if ( layoutSortNames [sortName]  && (layoutSortIndex != currentSortIndex) )   {
				layoutChanged = true;
			}
		}
	}

	//alert("alyout changed ??   " + layoutChanged);

	if (hasError)
	      return false;

	var terseChecked =  $('groupMode1').checked ;
	var verboseChecked   =   $('groupMode2').checked ;
	var avpLimit = 1000000;
	var  grpChecked = $("showGroup").checked
	if ((numAnno >= maxLimit  || numSelectedAssociations > avpLimit )   &&  numSelectedSortNames >1  ) {
		alert(" Due to the large number of annotations (" + total + "), \nplease select only one attribute to sort. ")
		return false;
	}
	else  if ( numSelectedSortNames > 5 && !grpChecked )  {
		alert("Please select up to five attributes to sort.")
		return false;
	}
	viewform.viewData.value = "1";
	if ( !validateForm()){
		viewform.viewData.value = "0";
		return false;
	}


// anno exceeds limit
	if( (mode ==1) && (numAnno >= maxLimit)  && !showAllChromosome) {
		if  (!confirm("There are "  + total + "  annotations in the selected tracks." +
		" \nDisplaying and ordering these annotations may take long time. \n\n Do you still want to proceed?  " ))
		return false;
	}
	// avp exceeds limit 	var layoutDisplayOrder = new Array();
	if (layoutDisplayNames)
	layoutDisplayOrder = reorderArray(orderedLayoutDisplayNames, displayNames);


	else if( mode ==1 && (numAnno < maxLimit && numSelectedAssociations >= avpLimit) && !showAllChromosome) {
		if (!confirm("There are more than one million annotation-to-attribute associations in the selected tracks." +
		" \nDisplaying and ordering these annotations may take long time. \n\n Do you still want to proceed?  " ))
		return false;
	}

	if ( isGrpChanged ())
	 	layoutChanged = true;

	if (layoutDisplayNames)
	layoutDisplayOrder = reorderArray(orderedLayoutDisplayNames, displayNames);


	var selectedView = $('viewNames').value;
	if (selectedView.indexOf("Default All Anno") >=0 ||selectedView.indexOf ("Default Group") >= 0 ) {
		isdfLayout = true;
	}

	// alert (" layout changed: ? " + layoutChanged) ;
	if (selectedView.indexOf ('Create New Layout') >0  && mode == 1) {
		if ($('msgbody'))
		$('msgbody').className = "ext-gecko x-body-masked";
		Ext.MessageBox.confirm('Confirmation', 'Do you want to save this layout?', saveLayoutConfirmation);
	}
	else if (layoutChanged && mode == 1 ){
		if (isAdmin ) {
			if (!isdfLayout &&  confirm('Save changes in layout \"'  +  selectedView + '\"? ')) {
				$('viewStatus').value = "1";
				$('viewInput').value =selectedView ;
			}

		if (isdfLayout) { // don't do anything
				//if ($('msgbody'))
				//$('msgbody').className = "ext-gecko x-body-masked";
				//Ext.MessageBox.confirm('Confirmation', 'Save changes in layout \"'  +  selectedView + '\"? ', saveLayoutConfirmation);
	            // return;
			}

			target = "viewAnnotation.jsp";
			if ($('showGroup') && $('showGroup').checked) {
			if (numAnno < maxLimit && numSelectedAssociations < avpLimit)
			target = "viewGroupAnnotations.jsp"
			if (!showAllChromosome)
			target = "viewGroupAnnotationsByRegion.jsp";

			}
			submitForm2Target ("viewForm", target);
		}
		 // else donothing
	}
	else  if (selectedView.indexOf ('Create New Layout') >0  && mode == 0) {
		if ($('msgbody'))
		$('msgbody').className = "ext-gecko x-body-masked";
		Ext.MessageBox.confirm('Confirmation', 'Do you want to save this layout?', saveDownloadLayoutConfirmation);
	}
	else if (layoutChanged && mode == 0 ) {
		if (isAdmin ) {
			if (!isdfLayout  &&  confirm('Save changes in layout \"'  +  selectedView + '\"? ')) {
			$('viewStatus').value = "1";
			$('viewInput').value =selectedView ;
			refreshLayout();
			}
			else {} // do nothing
			target = "downloadAnnotations.jsp"
			if ($('showGroup') && $('showGroup').checked)
			target = "downloadGroupAnnotations.jsp"
			submitForm2Target ("viewForm", target);
	}
		// else donothing
	}
	else
		ok2go = true;

	if (!isAdmin)
	    ok2go = true;

	if (ok2go) {
			var formId = "viewForm";
		var target =  findTarget (mode) ;
		submitForm2Target (formId, target);
	}
	return;
}



function findTarget (mode) {

		var target ="displaySelection.jsp";

		if (mode == 1)  {
		target = "viewAnnotation.jsp"
		if ($('showGroup') && $('showGroup').checked) {
		target = "viewGroupAnnotations.jsp" ;
		if (!showAllChromosome)
		target = "viewGroupAnnotationsByRegion.jsp";
		}
		}
		else if (mode == 0) {
		target ="downloadAnnotations.jsp"
		if ($('showGroup') && $('showGroup').checked)
		target = "downloadGroupAnnotations.jsp"
		}

	return target;

}



function validateChromosome (){
	var istart =  0;
	var istop =  0;
	var startErr = false;
	var stopErr = false;
	var chrErr = false;
	var msg = "";
	if (!$('chrSelNames') ){
	chrErr = true;  $('chrSelNames').style.backgroundColor="red";
	alert ( "Please select a chromosome.") ;
	return false;
	}

var chrName = $('chrSelNames').value;
if (!chrName || chrName.length==0) {

chrErr = true; $('chrSelNames').style.backgroundColor="red";
alert ("Please select a chromosome.") ;
return false;
}


if (chrName  && chrName.length >0 )  {
	chrName = stripString (chrName);
	if (chrName.length==0) {
		$('chrSelNames').style.backgroundColor="red";
		alert ("Please select a chromosome.") ;
		chrErr = true;
		return false;
	}


	if (!chromosomeNameArray[chrName] ) {
		$('chrSelNames').style.backgroundColor="red";
		alert ("Chromosome name \""  + chrName + "\" is not valid." ) ;
		chrErr = true;
		return false;
	}
	else {
		$('rid').value  =  chromosomeNameArray[chrName];
		$('chrSelNames').style.backgroundColor="white";
	}

}


if (!$('chrStarts')) {
$('chrStarts').style.backgroundcolor="red";
msg = "Please enter a positive integer for chromosome start.\n";
//    return false;
startErr = true;
}
else {


var start = $('chrStarts').value;

if (start) {
start = stripString (start);
istart =  parseInt(start);

if (isNaN (start)) {
$('chrStarts').style.backgroundColor="red";
msg =  msg + ("Please enter a positive integer for chromosome start.\n");
// return false;
startErr = true;
}

else  if (start <=0) {
$('chrStarts').style.backgroundColor="red";      startErr = true;
msg = msg + "Please enter a positive integer chromosome start.\n";
//return false;
}
else {

$('chrStarts').style.backgroundColor="white";

}

}
else {       startErr = true;
$('chrStarts').style.backgroundColor="red";
msg = msg + "Please enter a positive integer for chromosome start.";
// return false;

}
}






if (!$('chrStops'))  {        stopErr = true;
$('chrStops').style.backgroundColor="red";
msg = msg + "Please enter enter a positive integer chromosome stop.\n";
//  return false;
}

else {

if ($('chrStops').value ) {
var stop = $('chrStops').value;
stop =  stripString(stop);

if (isNaN (stop)) {         stopErr = true;
$('chrStops').style.backgroundColor="red";
msg = msg + "Please enter a positive integer chromosome stop.\n";
//  return false;

}
else {
var istop =  parseInt(stop);


if (stop <=0) {     stopErr = true;
$('chrStops').style.backgroundColor="red";
msg = msg + "Please enter a positive integer chromosome stop.\n";
//	return false;
}
}
}
else {

stopErr = true;

$('chrStops').style.backgroundColor="red";
msg = msg + "Please enter a positive integer for chromosome stop.\n" ;
//	return false;




}

}


if (!startErr && !stopErr) {
if (istop < istart)	 {
//	$('chrStops').style.backgroundColor="red";
startErr = true;    stopErr = true;
var temp =$('chrStarts').value ;
$('chrStarts').value = $('chrStops').value ;

$('chrStarts').innerHTML = $('chrStops').value ;

$('chrStops').value  = temp;

$('chrStarts').innerHTML = temp;


msg = msg +  ("Chromosome stop can not be greater than start.\nThe \"start\" and \"stop\" coordinates are exchanged.\n " );
//return false;
}


var rid = $('rid') .value;

var chlength = chromosomeArray[rid];
var ilength = parseInt(chlength);


if (istop > ilength) {
stopErr = true;
$('chrStops').style.backgroundColor="red";
msg = msg + "Chromosome stop can not be greater than chromosome length (" + chlength  + ")." ;
$('chrStops').value = chlength;
//addOptio//return false;
}
}


if (!stopErr )
$('chrStops').style.backgroundColor="white";
if (!startErr)
$('chrStarts').style.backgroundColor="white";

var success = true;

if (startErr || stopErr || chrErr) {
alert (msg) ;
success = false;
}

return success;
}




function validateTracks(formid, ckboxName, mode) {
var count =0 ;
var list = document.getElementsByTagName("input");
var count = 0;
for (var ii=0; ii<list.length; ii++)
{
if(list[ii].getAttribute("id") != null && list[ii].getAttribute("id").indexOf(ckboxName) == 0)
{
if (list[ii].checked){
count ++;
break;
}
}
}
if (count ==0) {
alert ("Please select some tracks.");
return;
}
else if (count >0)   {
$("currentMode").value= mode;
$(formid).submit();
}
}



function hasTrack( mode) {
	var trackName = $("dbTrackNames").value;
	if (!trackName) {
		alert ("Please select some tracks.");
		return false;
	}

	return true;
}




function checkTrack( mode) {
	var trackName = $("dbTrackNames").value;
	if (!trackName) {
		alert ("Please select some tracks.");
		return false;
	}
	else {
		var mode =  $("trkCommand").value;
		if (mode == 1){
			$("trkCommand").value = "viewTrack";
		}
		else if (mode ==0) {
			$("trkCommand").value = "downloadTrack";
		}

		$("selectionForm").submit();
		$("currentMode").value= mode;
	}
	return true;
}


var TOOL_PARAM_FORM = 'pdw' ;
var tmpGlobalVal = false ;var tmpChecked = null ;


function doCheckToggle(divId,  ckId){
	var divElem = $(divId) ;        // Div with image backgroup to adjust
	var className ;
	var position ;
	 if (divElem) {
		 className = divElem.className;
		 position =   $(divId).style.backgroundPosition;
	 }

	//alert ("  id " + divId + "class name  " +   className  );
	if(className && className.indexOf("checkBoxDiv1") >=0){
		$(divId).className =  "checkBoxDiv";
		$(divId).style.backgroundPosition =  "-0px 0px";
	}
	else if(className && className.indexOf ( "checkBoxDiv") >=0){
		$(divId).className =  "checkBoxDiv1";
		$(divId).style.backgroundPosition =  "-10px 0px";
	}
	// alert (" new name  name  " +   $(divId).className    );

	return ;
} ;


	function resetDefault (displayNames, sortNames) {
		for (ii=0; ii<displayNames.length; ii++){
			var thisname = displayNames[ii][1];

			layoutChanged = false;;
			var thisNameSelected =(displayNames[ii][2] == 1);

			if (!layoutDisplayNames [thisname]  && thisNameSelected) {
				layoutChanged = true;
			}

			if (layoutDisplayNames [thisname]  && !thisNameSelected) {
				layoutChanged = true;
			}

			if (layoutChanged) {
				var    divId =   'item_' + ii + '_chkdiv' ;
				doCheckToggle(divId,  thisname);
			}
		}


		if (sortNames && sortNames.length >0) {
			for (ii=0; ii<sortNames.length; ii++){
				var sortName = sortNames [ii][1];
				layoutChanged = false;
				if (sortName && sortName.indexOf ("_sort") > 0)
				sortName = sortName.substring(0, sortName.indexOf("_sort"));
				var sortNameSelected =(sortNames[ii][2] == 1);


				if (!layoutSortNames[sortName]  &&  sortNameSelected ) {
				layoutChanged = true;
				}


				if (layoutSortNames[sortName]  && !sortNameSelected ) {
				layoutChanged = true;
				}

				if (layoutChanged) {
				divid =   'sortitem_' + ii + '_chkdiv' ;
				doCheckToggle(divid,  sortName + "_sort");
				}
			}
		}
		else
			clearAllSort (displayNames.length -1 );
		return ;
	}

function recordOrder(){
var sLists = $H() ;  /* Get any
regular sortable lists */
var lists = $$('.sortableList1') ;
for(var ii=0, lLen = lists.length ; ii<lLen ; ii++)  {
var currSList = $A() ;
sLists.set(lists[ii].id. currSList) ;
/* Get all the <li> in this list */
	var listItems = lists[ii].getElementsByTagName("div") ;
	var count = 0;
	for(var jj=0, iLen = listItems.length ; jj<iLen ; jj++)   {
		var currItemRec = $A() ;
		var currItem = listItems[jj] ;
		currItemRec.push(currItem.id) ;
		if (jj %2 ==0) {
			var trackNameInput = $(currItem.id + '_trackName') ;
			var itemChecked ="0" ;
		    var currentPosition = "0";
	    if(currItem.id)
				currentPosition = $(currItem.id + "_chkdiv").style.backgroundPosition;
			if (currentPosition && currentPosition.indexOf("-10") >=0)
				itemChecked = "1";

			var className =$(currItem.id + "_chkdiv").className;
			if (className && className.indexOf("BoxDiv1") >= 0 )
			    itemChecked = "1";

			if (trackNameInput && trackNameInput.value)  {
				var trackName =   trackNameInput.value;
				currItemRec.push(trackName) ;
			}



			//alert (" track name " + trackName  + " checked " + itemChecked + "  id " +  currItem.id  + "  position " + currentPosition + " className " +  $(currItem.id + "_chkdiv").className  );


			if(itemChecked && itemChecked=='1')
				currItemRec.push('1') ;
			else
				currItemRec.push('0') ;
			currSList.push(currItemRec) ;
		}
	}
	}
		var viewForm = $('viewForm');
		viewForm.jsparams.value = sLists.toJSON() ;
		   // alert (sLists.toJSONString()  );
		var  selectionForm = $('selectionForm');
		selectionForm.jsparams.value = sLists.toJSON() ;
return ;
};

function showResult1(btn){
	if (btn== 'yes') {
	$('viewStatus').value = "1";
	$('viewInput').value = layoutName;

	target = "viewAnnotation.jsp"
	if ($('showGroup') && $('showGroup').checked)   {
	target = "viewGroupAnnotations.jsp"

	if (!showAllChromosome)
	target = "viewGroupAnnotationsByRegion.jsp";

	}

	viewForm.onSubmit = "";
	submitForm2Target ("viewForm", target);
	}
	else {
	 alert ("button clicked is " + btn);
	return false;
	}
};


function showDownloadResult(btn){
if (btn== 'yes') {
$('viewStatus').value = "1";
$('viewInput').value = layoutName;
addOption (0, layoutName, 'viewNames' );
refreshLayout ();
viewForm.action ="downloadAnnotations.jsp";
if ($('showGroup') && $('showGroup').checked)
viewForm.action = "downloadGroupAnnotations.jsp"

viewForm.onSubmit = "";
viewForm.submit();
}
else {
return false;
}
};



function  hideButtons() {
	if ($('apply')) {
	$('apply').disabled = true;
	}

	if ($('download')) {
	$('download').disabled = true;
	}

	if ($("saveConfig" )) {
	$("saveConfig" ).disabled = true;
	}

	if ($("btnCancel")) {
	$("btnCancel").disabled = true;
	}
}

	function processTrackChange () {
		if ($("rearrange_list_1")) {
			hideButtons ();
		}

		$('trackChanged').value='1';


		var selectedTracks = $('dbTrackNames').value;

		   var btnValue = $('modeButton').value;
		 if(btnValue && btnValue.indexOf('Layout Inter')  <0 ) {
	$('crv').value= "1";
	      	$('dfcrv').value= "1";
			 }
	else {
				$('crv').value= "";
	   	$('dfcrv').value= "";

		 }
		selectionForm.submit();
	}

