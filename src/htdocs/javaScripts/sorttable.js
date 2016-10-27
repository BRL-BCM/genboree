addEvent(window, "load", sortables_init);

var SORT_COLUMN_INDEX;
var SAW_USA_DATE = false ;

function sortables_init() {
    // Find all tables with class sortable and make them sortable
    if (!document.getElementsByTagName) return;
    tbls = document.getElementsByTagName("table");
    for (ti=0;ti<tbls.length;ti++) {
        thisTbl = tbls[ti];
        if (((' '+thisTbl.className+' ').indexOf("sortable") != -1) && (thisTbl.id)) {
            //initTable(thisTbl.id);
            ts_makeSortable(thisTbl);
        }
    }
}

function ts_makeSortable(table) {
    if (table.rows && table.rows.length > 0) {
        var firstRow = table.rows[0];
    }
    if (!firstRow) return;
    
    // We have a first row: assume it's the header, and make its contents clickable links
    for (var i=0;i<firstRow.cells.length;i++) {
        var cell = firstRow.cells[i];
        var txt = ts_getInnerText(cell);
        // cell.innerHTML = '<a href="#" class="sortheader" onclick="ts_resortTable(this);return false;">'+txt+'<span class="sortarrow">&nbsp;</span></a>';
        tmpHtml = cell.innerHTML ;
        cell.innerHTML = '<a href="#" class="sortheader" onclick="ts_resortTable(this);return false;">'+tmpHtml+'<span class="sortarrow">&nbsp;</span></a>';
    }
}

function ts_getInnerText(el) {
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el };
	if (el.innerText) return el.innerText;	//Not needed but it is faster
	var str = "";
	
	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
			case 1: //ELEMENT_NODE
				str += ts_getInnerText(cs[i]);
				break;
			case 3:	//TEXT_NODE
				str += cs[i].nodeValue;
				break;
		}
	}
	return str;
}

function ts_resortTable(lnk) {
    // get the span
    var span;
    for (var ci=0;ci<lnk.childNodes.length;ci++) {
        if (lnk.childNodes[ci].tagName && lnk.childNodes[ci].tagName.toLowerCase() == 'span') span = lnk.childNodes[ci];
    }
    var spantext = ts_getInnerText(span);
    var td = lnk.parentNode;
    var column = td.cellIndex;
    var table = getParent(td,'TABLE');
    
    // Work out a type for the column
    if (table.rows.length <= 1) return;
    var itm = ts_getInnerText(table.rows[1].cells[column]);
    sortfn = ts_sort_caseinsensitive;
    if (itm.match(/^\d?\d[\/-]\d?\d[\/-]\d\d\d\d$/))
      sortfn = ts_sort_date;
    else if (itm.match(/^\d?\d[\/-]\d?\d[\/-]\d?\d$/))
      sortfn = ts_sort_date;
    else if (itm.match(/^[£$]/))
      sortfn = ts_sort_currency;
    else if (itm.match(/^(\d+,)*[\d\.]+$/))
      sortfn = ts_sort_numeric;
    
    SORT_COLUMN_INDEX = column;
    var firstRow = new Array();
    var newRows = new Array();
    for (i=0;i<table.rows[0].length;i++) { firstRow[i] = table.rows[0][i]; }
    for (j=1;j<table.rows.length;j++) { newRows[j-1] = table.rows[j]; }

    newRows.sort(sortfn);
    if(SAW_USA_DATE)
    {
      newRows.sort(sortfn) ;
      SAW_USA_DATE = false;
    }

    if (span.getAttribute("sortdir") == 'down') {
        ARROW = '&uarr;';
        newRows.reverse();
        span.setAttribute('sortdir','up');
    } else {
        ARROW = '&darr;';
        span.setAttribute('sortdir','down');
    }
    
    // We appendChild rows that already exist to the tbody, so it moves them rather than creating new ones
    // don't do sortbottom rows
    for (i=0;i<newRows.length;i++) { if (!newRows[i].className || (newRows[i].className && (newRows[i].className.indexOf('sortbottom') == -1))) table.tBodies[0].appendChild(newRows[i]);}
    // do sortbottom rows only
    for (i=0;i<newRows.length;i++) { if (newRows[i].className && (newRows[i].className.indexOf('sortbottom') != -1)) table.tBodies[0].appendChild(newRows[i]);}
    
    // Delete any other arrows there may be showing
    var allspans = document.getElementsByTagName("span");
    for (var ci=0;ci<allspans.length;ci++) {
        if (allspans[ci].className == 'sortarrow') {
            if (getParent(allspans[ci],"table") == getParent(lnk,"table")) { // in the same table as us?
                allspans[ci].innerHTML = '&nbsp;';
            }
        }
    }
        
    span.innerHTML = ARROW;
}

function getParent(el, pTagName) {
	if (el == null) return null;
	else if (el.nodeType == 1 && el.tagName.toLowerCase() == pTagName.toLowerCase())	// Gecko bug, supposed to be uppercase
		return el;
	else
		return getParent(el.parentNode, pTagName);
}

function ts_sort_date(a,b) {
    // y2k notes: two digit years less than 50 are treated as 20XX, greater than 50 are treated as 19XX
    // ARJ: I rewrote almost all of this and added the SAW_USA_DATE flag above.
    // ARJ: I fixed:
    //      - incorrect handling of single digit month or days
    //      - missing detection and handling of USA date style: mm/dd/yy or mm/dd/yyyy
    //      - substr parsing of dates replaced with more flexible reg-exp parsing.
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    // ARJ: Dates are now represented as arrays of dd,mm,yy strings
    var aaDateArray;
    var bbDateArray;
    if(aa.match(/^(\d?\d)[\/-](\d?\d)[\/-](\d\d\d\d)$/)) // 4 digit year ok
    {
      aaDateArray = [RegExp.$1, RegExp.$2, RegExp.$3] ;
    }
    else // 2 digit year needs fixing
    {
      aa.match(/^(\d?\d)[\/-](\d?\d)[\/-](\d?\d)$/)
      aaDateArray = [RegExp.$1, RegExp.$2, RegExp.$3] ;
      if(parseInt(aaDateArray[2]) < 50) aaDateArray[2] = '20'+aaDateArray[2] ;
      else aaDateArray[2] = '19'+aaDateArray ;
    }
    // ARJ: Fix single digit days or months
    if(parseInt(aaDateArray[0]) < 10) aaDateArray[0] = '0'+aaDateArray[0] ;
    if(parseInt(aaDateArray[1]) < 10) aaDateArray[1] = '0'+aaDateArray[1] ;
    
    if(bb.match(/^(\d?\d)[\/-](\d?\d)[\/-](\d\d\d\d)$/)) // 4 digit year ok
    {
      bbDateArray = [RegExp.$1, RegExp.$2, RegExp.$3] ;
    }
    else // 2 digit year needs fixing
    {
      bb.match(/^(\d?\d)[\/-](\d?\d)[\/-](\d?\d)$/)
      bbDateArray = [RegExp.$1, RegExp.$2, RegExp.$3] ;
      if(parseInt(bbDateArray[2]) < 50) bbDateArray[2] = '20'+bbDateArray[2] ;
      else bbDateArray[2] = '19'+bbDateArray ;
    }
    // ARJ: Fix single digit days or months
    if(parseInt(bbDateArray[0]) < 10) bbDateArray[0] = '0'+bbDateArray[0] ;
    if(parseInt(bbDateArray[1]) < 10) bbDateArray[1] = '0'+bbDateArray[1] ;
    
    // ARJ: If we encounter a USA date (mm/dd/yy), then we'll need to redo the whole sort all over again
    if(((aaDateArray[0] <= 12 && aaDateArray[1] > 12) || (bbDateArray[0] <= 12 && bbDateArray[1] > 12)) && !SAW_USA_DATE)
    {
      SAW_USA_DATE = true ;
      return 0; // ARJ: This calls a tie, but we'll be repeating the sort anyway...
    }
    else
    {
      if(SAW_USA_DATE)  // ARJ: We previously encountered at least 1 USA date during the previous sorting attempt
      {
        // ARJ: So swap the month and day
        var tmpDate = aaDateArray[1] ;
        aaDateArray[1] = aaDateArray[0] ;
        aaDateArray[0] = tmpDate; 
        tmpDate = bbDateArray[1] ;
        bbDateArray[1] = bbDateArray[0] ;
        bbDateArray[0] = tmpDate;
      }
      // Make date string: yyyymmdd <-- sort using this
      var dt1 = aaDateArray[2] + aaDateArray[1] + aaDateArray[0] ;
      var dt2 = bbDateArray[2] + bbDateArray[1] + bbDateArray[0] ;
      // ARJ: here is original code...short and not so good.
  //    if (aa.length == 10) {
  //        dt1 = aa.substr(6,4)+aa.substr(3,2)+aa.substr(0,2);
  //    } else {
  //        yr = aa.substr(6,2);
  //        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
  //        dt1 = yr+aa.substr(3,2)+aa.substr(0,2);
  //    }
  //    if (bb.length == 10) {
  //        dt2 = bb.substr(6,4)+bb.substr(3,2)+bb.substr(0,2);
  //    } else {
  //        yr = bb.substr(6,2);
  //        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
  //        dt2 = yr+bb.substr(3,2)+bb.substr(0,2);
  //    }
      if (dt1==dt2) return 0;
      if (dt1<dt2) return -1;
      return 1;
   }
}

function ts_sort_currency(a,b) { 
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    return parseFloat(aa) - parseFloat(bb);
}

function ts_sort_numeric(a,b) { 
    aa = parseFloat(ts_getInnerText(a.cells[SORT_COLUMN_INDEX]));
    if (isNaN(aa)) aa = 0;
    bb = parseFloat(ts_getInnerText(b.cells[SORT_COLUMN_INDEX])); 
    if (isNaN(bb)) bb = 0;
    return aa-bb;
}

function ts_sort_caseinsensitive(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).toLowerCase();
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).toLowerCase();
    if (aa==bb) return 0;
    if (aa<bb) return -1;
    return 1;
}

function ts_sort_default(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    if (aa==bb) return 0;
    if (aa<bb) return -1;
    return 1;
}


function addEvent(elm, evType, fn, useCapture)
// addEvent and removeEvent
// cross-browser event handling for IE5+,  NS6 and Mozilla
// By Scott Andrew
{
  if (elm.addEventListener){
    elm.addEventListener(evType, fn, useCapture);
    return true;
  } else if (elm.attachEvent){
    var r = elm.attachEvent("on"+evType, fn);
    return r;
  } else {
    alert("Handler could not be removed");
  }
} 
