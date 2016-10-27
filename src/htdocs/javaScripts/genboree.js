DaysofWeek = new Array()
DaysofWeek[0]="Sunday"
DaysofWeek[1]="Monday"
DaysofWeek[2]="Tuesday"
DaysofWeek[3]="Wednesday"
DaysofWeek[4]="Thursday"
DaysofWeek[5]="Friday"
DaysofWeek[6]="Saturday"
Months = new Array()
Months[0]="January"
Months[1]="February"
Months[2]="March"
Months[3]="April"
Months[4]="May"
Months[5]="June"
Months[6]="July"
Months[7]="August"
Months[8]="September"
Months[9]="October"
Months[10]="November"
Months[11]="December"


function fixNumber(the_number) {
	if (the_number < 10){
		the_number = "0" + the_number;
	}
	return the_number;
}
function fixPMHours(the_number){
	if (the_number>12){
		the_number = the_number - 12;
	}
	return the_number;
}
var dayVal;
var timeVal=new Date()
var m=timeVal.getMinutes()
var h=timeVal.getHours()
var fixed_hour = fixPMHours(h);
var da=timeVal.getDate()
var mo=timeVal.getMonth()
var year=timeVal.getYear()
var showDay=DaysofWeek[timeVal.getDay()]
var showMonth=Months[timeVal.getMonth()]
var fixed_minute = fixNumber(m);
var the_time = fixed_hour + ":" + fixed_minute;
var the_date = (showDay+", "+showMonth+" "+da+", "+year+"  ")
function showTime(){
	var timeValue = the_date+" "+the_time;
	timeValue +=(h >= 12) ? " p.m." : " a.m.";
	return timeValue;
}
function is_num(e) {
   if (e.keyCode < 48 || e.keyCode > 57) {
      alert("Only digits permitted");
      e.returnValue = false;
      return true;
   }
   e.returnValue = true;
   return false;
}
function update_coords(item, dir) {
	var amt;
	var fromValue;
	var toValue;
	fromValue = document.gb.from.value;
	toValue = document.gb.to.value;
	if (fromValue == "") {
		alert("You must enter a start value for range");
		document.gb.from.focus();
		return false;
	}
	if (isNaN(parseInt(fromValue))) {
		alert("From value (" + fromValue + ") is not an integer number");
		document.gb.from.value="";
		document.gb.from.focus();
		return false;
	}
	fromInt = parseInt(fromValue);
	if (fromValue <= 0) {
		alert('From value less or equal 0');
		return false;
	}
	if (toValue == "") {
		alert("You must enter an end value for range");
		document.gb.to.focus();
		return false;
	}
	if (isNaN(parseInt(toValue))) {
		alert("To value (" + toValue + ") is not an integer number");
		document.gb.to.value="";
		document.gb.to.focus();
		return false;
	}
	toInt = parseInt(toValue);
	if (toValue < 0) {
		alert('To value less or equal 0');
		return false;
	}
	if (fromInt >= toInt) {
		alert("From value (" + fromValue + ") greater or equal to To value (" + toValue + ")");
		return false;
	}
	if (item.name.match("zoom")) {
		var factor;
		if (item.value == "") {
			alert('Zoom value cannot be NULL');
			item.focus();
			return false;
		}
		if (isNaN(parseFloat(item.value))) {
			alert('Zoom value is not a floating point number');
			item.value = "";
			item.focus();
			return false;
		}
		if (Number(item.value) <= 0) {
			alert('Zoom value cannot be less or equal to 0');
			item.value = "";
			item.focus();
			return false;
		}
		var range = document.gb.to.value - document.gb.from.value + 1;
		if (dir == 'in') {
			amt = (range / item.value) / 2;
			midPoint = fromInt + (range / 2);
			document.gb.from.value = midPoint - amt;
			document.gb.to.value = midPoint + amt;
		}
		else {
			factor = item.value;
			amt = (range * factor - range)/2;
			document.gb.from.value = fromInt - amt;
			if (Number(document.gb.from.value) < 1.0) {
				document.gb.from.value = 1;
			}
			document.gb.to.value = toInt + amt;
		}
	} else {
		if (item.value == "") {
			alert((dir == 'left' ? 'Left' : 'Right') + (item.name.match("shift") ? ' shift' : ' extend') + ' value cannot be NULL');
			item.focus();
			return false;
		}
		if (isNaN(parseInt(item.value))) {
			alert((dir == 'left' ? 'Left' : 'Right') + (item.name.match("shift") ? ' shift' : ' extend') + ' value is not a number');
			item.value = "";
			item.focus();
			return false;
		}
		amt = item.value * (dir == 'left' ? -1 : 1);
		if (item.name.match("left") || item.name.match("shift")) {
			document.gb.from.value = Number(document.gb.from.value) + amt;
			if (Number(document.gb.from.value) < 1.0) {
				document.gb.from.value = 1;
			}
		}
		if (item.name.match("right") || item.name.match("shift")) {
			document.gb.to.value = Number(document.gb.to.value) + amt;
			if (Number(document.gb.to.value) < 1.0) {
				document.gb.to.value = 1;
			}
		}
	}
	document.gb.submit();
}
function validateFromTo(viewForm) {
	fromValue = viewForm.from.value;
	toValue = viewForm.to.value;
	if (fromValue == "") {
    	alert("You must enter a start value for range");
    	viewForm.from.focus();
    	return false;
	}
	if (isNaN(parseInt(fromValue))) {
    	alert("From value (" + fromValue + ") is not an integer number");
    	viewForm.from.value="";
    	viewForm.from.focus();
    	return false;
	}
	fromInt = parseInt(fromValue);
	if (fromValue <= 0) {
    	alert('From value less or equal 0');
    	return false;
	}
	if (toValue == "") {
    	alert("You must enter an end value for range");
    	viewForm.to.focus();
    	return false;
	}
	if (isNaN(parseInt(toValue))) {
    	alert("To value (" + toValue + ") is not an integer number");
    	viewForm.to.value="";
    	viewForm.to.focus();
    	return false;
	}
	toInt = parseInt(toValue);
	if (toValue < 0) {
    	alert('To value less or equal 0');
    	return false;
	}
	if (fromInt >= toInt) {
    	alert("From value (" + fromValue + ") greater or equal to To value (" + toValue + ")");
    	return false;
	}
	return true;
}
function openNewWindow(url, theTargetWin)
{
    var w = window.open (url, "theTargetWin", "height=600,width=800,location,menubar,resizable,scrollbars,status,toolbar");
    return false;
}
function setAllbottoms(formObj, state) 
{
	for (var i=0;i < formObj.length;i++)
	{
		fldObj = formObj.elements[i];
		if(fldObj.type == 'select-one' && fldObj.options[0].text == 'Expand')
			fldObj.selectedIndex = state;
	}
}

