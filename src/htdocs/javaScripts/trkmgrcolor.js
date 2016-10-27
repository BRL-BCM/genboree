/*************************************************************************
*   javascript functions used for setting style color of trackmgr.jsp                                                                   *
**************************************************************************/


var colorDivId="#";  //style color div id
var hiddenInputId="#";   // value from hidden input
var trkColor ="#";  // initial color
var numAnnos = 0;  // initial color
var isDefaultColorId; 
var externalObservers = [] ;  // MFS EDIT

// function to set color and hidden input value for trk manager style
function  setTrkElemColor () {

    if ($(colorDivId) != null && colorWheel != null)  {
    if ( $(colorDivId).style && $(colorDivId).style.backgroundColor != null)
    $(colorDivId).style.backgroundColor= colorWheel.getColor();
    }

    if ($(hiddenInputId) != null && colorWheel != null)  {
    var temp =  colorWheel.getColor();
   if (temp!=null && temp.indexOf('#')!=0)
    temp= "#" +temp;
    $(hiddenInputId).value= temp;
    if (isDefaultColorId) 
     $(isDefaultColorId).value = 'false';         
    }  
    if (colorDivId.indexOf("All") >= 0 ) {
     updateAllColor();
    }
}


// JavaScript file initializer
function init_colorWheelWidget()
{
  colorWheel = new ColorWheel() ;
  colorWheel.addObserver(setTrkElemColor);

  /** START MFS EDIT **/
  for(var count = 0 ; count < externalObservers.length ; count++)
  {
    colorWheel.addObserver(externalObservers[count]) ;
  }
  /** END MFS EDIT **/

  return ;
}

/** START MFS EDIT **/
function addExternalColorWheelObserver(observer)
{
  externalObservers.push(observer) ;
}
/** END MFS EDIT **/

function showColorWheelPop() {
     colorWheel = new ColorWheel() ;
    var htmlTxt = '<div id="wheel" align="center">' +
    '<div   class="wheelImage">' +
    '<a  onclick="colorWheel.setColor()">' +
    '<img  id="wheelImage" name="wheelImage" src="/images/colorWheel.png"   border="0" width="183"  height="183" onClick="handleImgClick(this, event);" >' +
    '</a>' +
    '</div><br>';
if (colorWheel) {
    var text1 ="<table border='0' cellpadding='0' cellspacing='0'><tr align='center'><td><table border='0' cellpadding='0' cellspacing='0'>";
    var serialNum = 0;
    var bottomBrdrWidth ;
    for(i=0; i < colorWheel.rowNum; i++)
    {
      if(i == (colorWheel.rowNum - 1))
        bottomBrdrWidth = '1px' ;
      else
        bottomBrdrWidth = '0px' ;
      text1 = text1 +   '<tr align="center"><td><div align="center" class="colorP">'
      for(j=0; j < colorWheel.colNum; j++)
      {
        serialNum = (i*colorWheel.colNum) + j;
        if(j==0)
          text1 = text1 +   '<div  name="selColor' + serialNum + '" id="selColor' + serialNum + '" class="colorPaletteLeft" style="background-color:' +colorWheel.paletteArray[i][j] + '; border-width: 1px 1px ' + bottomBrdrWidth + ' 1px;" onClick="setPaletteColor(\'' + colorWheel.paletteArray[i][j] + '\')"><!-- -->' +     '</div>' ;
        else
          text1 = text1 +   '<div  name="selColor' + serialNum + '" id="selColor' + serialNum + '" class="colorPalette" style="background-color:' +colorWheel.paletteArray[i][j] + '; border-width: 1px 1px ' + bottomBrdrWidth + ' 0px;"  onClick="setPaletteColor(\'' + colorWheel.paletteArray[i][j] + '\')"><!-- -->' + '</div>' ;
      }
      text1 = text1 +   '</div></td></tr>';
    }
      text1 = text1 + '</table></td></tr>';
   //  alert(text1);
    htmlTxt = htmlTxt +  text1;
};

   htmlTxt = htmlTxt +
    '<tr><td><div class="colorField">' +
    '<div id="displayBorder">'+
    '<table><tralign="center"><td><input type="text" name="selColor" id="selColor" size="11"   maxlength="11"  value="' + trkColor + '"    onkeypress="colorWheel.processKeyPress(event);">' +
//    '<input type="button" name="setColorBtn" id="setColorBtn" width="50" value="Set" onClick="colorWheel.setWheelColor();" >' +
 '</td><td><input type="button" name="setColorBtn" id="setColorBtn" width="50" class="btn" value="Set" onClick="setColorPressed();" >' +
    '</td></tr></table></div>' +
    '</div>'
    + '<div id="triggerElem" name="triggerElem"></div>'
     + '<input type="hidden" id="triggerElem2" name="triggerElem2"></td></tr></table>';

overlib(htmlTxt, STICKY, CLOSECLICK,
    FGCOLOR, 'FFFFFF', BGCOLOR, '#9F833F', WRAP,
    CAPTIONFONTCLASS, 'capFontClass', CAPTION,
        '&nbsp;Select&nbsp;a&nbsp;color', CLOSEFONTCLASS, 'closeFontClass',
     CLOSETEXT, '&nbsp;&nbsp;<FONT COLOR="white">X</FONT>&nbsp;', HEIGHT, '183', WIDTH, '183' );
     init_colorWheelWidget();
   // colorWheel.addObserver(setTrkElemColor);
     setDefaultStyleColor ();
   return;
  }

 function setColorPressed () {
  colorWheel.setWheelColor();
  nd();    nd();
 }


 function setPaletteColor (c) {
 
        if (isDefaultColorId) 
     $(isDefaultColorId).value = 'false'; 
 
 
 
       if ($(colorDivId) != null && colorWheel != null)  {
        if ( $(colorDivId).style && $(colorDivId).style.backgroundColor != null)
        $(colorDivId).style.backgroundColor= c;
        }

        if ($(hiddenInputId) != null && colorWheel != null)  {

       if (c!=null && c.indexOf('#')!=0)
        c= "#" +c;
        $(hiddenInputId).value= c;
        }

       if ("displayBorder")
       $("displayBorder").style.backgroundColor= c;
        if ("selColor")
            $("selColor").value = c;
        if (colorDivId.indexOf("All") >= 0 ) {
         updateAllColor();
        }
  }




function setDefaultStyleColor () {
    if ($("selColor")) {
    $("selColor").value= trkColor;
    }
   
   if ($("displayBorder") != null) {
    $("displayBorder").style.backgroundColor = trkColor;
    }
}



function setDivIdndfColor(did, inputid, initColor, isdefaultID) {
 
    trkColor = initColor;
    if ($(inputid) != null)
        trkColor = $(inputid).value;

    if (trkColor.indexOf('#')>=0 && trkColor.length==1)
     trkColor="000000";

    isDefaultColorId = isdefaultID; 

    colorDivId = did;
    hiddenInputId=inputid;    
   
    showColorWheelPop();
}


function setDivId(did, inputid, initColor) {

    trkColor = initColor;
    if ($(inputid) != null)
        trkColor = $(inputid).value;

    if (trkColor.indexOf('#')>=0 && trkColor.length==1)
     trkColor="000000";


    colorDivId = did;
    hiddenInputId=inputid;    
    showColorWheelPop();
}


function setSelectedDivId(did, inputid, initColor, n ) {
   if ($('changed')){
     $('changed').value="1";
   }

    trkColor = initColor;
    colorDivId = did;
    hiddenInputId=inputid;
    numAnnos=n;
    showColorWheelPop();
}

function updateAllColor() {
   for (i=0; i<numAnnos; i++) {
      var tempdivid ="colorImageId"+i;
      var tempinputid ="hiddenInputId"+i;
      var checkBoxid = "checkBox_" + i;
      var dfcolor ="isDefaultColor_" + i;
      if ($(checkBoxid) && ($(checkBoxid).checked)){
      
      if ($(dfcolor)) 
     $(dfcolor).value = 'false'; 
      
      
      
        if ( $(tempdivid) && colorWheel)
          $(tempdivid).style.backgroundColor= colorWheel.getColor();
         if ( $(tempinputid) && colorWheel)
          $(tempinputid).value= colorWheel.getColor();
      }
   }
}


function setDefaultColor (checkboxid, color, groupColorId, colorImageId, hid) {
   if (color.indexOf ("#") <0)
   color = "#" + color;
   var groupColor = $(groupColorId).value;
    if (groupColor.indexOf ("#") <0)
  groupColor = "#" + groupColor;

   if ($(checkboxid).checked) {
       if (  $(colorImageId)!= null){
       $(colorImageId).style.backgroundColor = groupColor;
       
      }
       if ( $(hid) != null)
       $(hid).value = groupColor;
   }
   else {
      if (  $(colorImageId)!= null)
             $(colorImageId).style.backgroundColor = color;

           if ( $(hid) != null)
           $(hid).value = color;
   }

}


