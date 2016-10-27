//addEvent(window, "load", init_colorWheelWidget) ;  //register yet another initializer with the "load" state

// Define ColorWheel Class

ColorWheel = Class.create() ;
var colorWheel;

ColorWheel.prototype = {
  // wheel image width and height
  wheelImageWidth: 1,
  wheelImageHeight: 1,
  inputFieldId: 'selColor',
  displayBoxId: 'displayBorder',
 triggerElem: null,
 triggerElem2: null,
  // initial h, s, v
  hue: 60,
  sat: 1,
  val: 1,
  rowNum: 4,
  colNum : 18,
  paletteArray: null,
   // initial degree
  selectedColor: "#",

  // color table
  colorTable: [],

  fireTrigger: function()
  {

    var fireOnThis = this.triggerElem;

    if( document.createEvent )
    {
        var evObj = document.createEvent('MouseEvents');
        evObj.initEvent( 'mousemove', true, false );
        fireOnThis.dispatchEvent(evObj);

        //this.triggerElem2.dispatchEvent('keypress');
    }
    else if( document.createEventObject )
    {
        fireOnThis.fireEvent('onmousemove');
       // this.triggerElem2.fireEvents('onkeypress');
    }
  },



  fireTriggerKeyPress: function()
    {

      var fireOnThis = this.triggerElem2;

      if( document.createEvent )
      {
          var evObj = document.createEvent('keyEvents');
          evObj.initEvent( 'keypress', true, false );
          fireOnThis.dispatchEvent(evObj);

         // this.triggerElem2.dispatchEvent('keypress');
      }
      else if( document.createEventObject )
      {
          fireOnThis.fireEvent('onkeypress');
          //this.triggerElem2.fireEvents('onkeypress');
      }
    },



  initialize: function()
  {
    this ;

    this.initPalette() ;
    this.initColorTable() ;
    this.triggerElem= $('triggerElem') ; //document.createElement("<div id='testElem' name='testElem'>");
    this.triggerElem2= $('triggerElem2') ; //document.createElement("<div id='testElem' name='testElem'>");

    if($('wheelImage'))
    {

      this.wheelImageWidth = $('wheelImage').width ;
      this.wheelImageHeight = $('wheelImage').height ;
      if(this.wheelImageWidth <= 0 && this.wheelImageHeight <= 0 )
      {
        this.wheelImageWidth = 100 ;
        this.wheelImageHeight = 100 ;
      }
      else if(this.wheelImageWidth <= 0 && wheelImageHeight > 0)
      {
        this.wheelImageWidth = wheelImageHeight ;
      }
      else if(this.wheelImageWidth > 0 && this.wheelImageHeight <= 0)
      {
        this.wheelImageHeight =  this.wheelImageWidth;
      }
    }
  
    if(this.wheelImageWidth < 1 || this.wheelImageHeight < 1)
    {
      alert ("image size is too small");
      return false;
    }
   // this.capture() ;
  },  // END: initialize: function()


  addObserver: function (setTrkElemColor ) {
  Event.observe(this.triggerElem, 'mousemove', setTrkElemColor, false);
  Event.observe(this.triggerElem, 'keypress', setTrkElemColor, false);

  },


  setInitColor: function(hexString)
  {
    this.selectedColor = hexString ;
    return ;
  },

  setColor: function()
  { 
    this.setDisplayBox(this.hue);
    return false;
  },
  
  getColor: function()
  {
    return this.selectedColor ;
  },
  
  colorName2Hex: function(colorName)
  {
    if(this.colorTable[colorName])
      return this.colorTable[colorName] ;
    else if(this.colorTable[colorName.toUpperCase()])
      return this.colorTable[colorName] ;
    else
      return false ;
  },
  
  processKeyPress: function(event)
  {
    if(event.keyCode == Event.KEY_RETURN)
    {
      this.setWheelColor();
      this.fireTriggerKeyPress();
    }
  },
  
  setDisplayBox: function(deg)
  {
    this.hue = deg ;
    var hexStr = this.rgbArray2HexStr(this.hsv2rgb(this.hue, this.sat, this.val)) ;
    this.selectedColor = hexStr ;
    $(this.inputFieldId).value =  hexStr ;
    $(this.displayBoxId).style.backgroundColor = hexStr ;
    this.setInitColor( hexStr ) ;
    this.fireTrigger();
  },
  
  setWheelColor: function()
  {
    var asHex ;
    if($('selColor'))
    {
      var tempColor = $('selColor').value ;
      if(!(asHex = this.validateColorInput(tempColor)))
      {
        return ;
      }
    }
    $('displayBorder').style.backgroundColor = asHex ; 
    this.selectedColor = asHex ;
    $('selColor').value = asHex ;

     this.fireTrigger();
   return;
  },

  validateColorInput: function(hexS)
  {
    var retVal ;
    var theMatch ;
    var formatError = "The value you entered ('" + hexS + "') doesn't look like a color specification.\n" +
                      "Your can enter colors by name or RGB value (in decimal or hex formats).\nExamples:\n\n" +
                      " By Name: blue\n As RGB Hex: #CC33AA\n As RGB Dec: 204,51,170\n"
    hexS = hexS.gsub(/^\s+/, "").gsub(/\s+$/, "") ;
    hexS = hexS.toUpperCase() ;
    if(retVal = colorWheel.colorName2Hex(hexS))
    {
      return retVal ;
    }
    else if(theMatch = hexS.match(/^(\d+)\s*,\s*(\d+)\s*,\s*(\d+)$/))
    {
      var redC = parseInt(theMatch[1]) ;
      var greenC = parseInt(theMatch[2]) ;
      var blueC = parseInt(theMatch[3]) ;
  
      if(redC > 255 || redC < 0)
      {
        alert("RED value ('" + redC + "') is out of range (0, 255)");  return;
      }
      if(greenC > 255 || greenC < 0)
      {
        alert ("GREEN value ('" + greenC + "') is out of range (0, 255)");  return;
      }
      if(blueC > 255 || blueC < 0)
      {
        alert ("BLUE value ('" + blueC + "') is out of range (0, 255)");  return;
      }
      return retVal = this.rgbArray2HexStr([ redC, greenC, blueC ]) ;
    }
    else if(theMatch = hexS.match(/^#?([A-Fa-f0-9]+)$/))
    {
      retVal = theMatch[0] ;
      var hexSLen = hexS.length ;
      if(hexSLen == 6 && hexS.charAt(0)!= '#')
      {
        retVal  = "#" + hexS;
      }
      if(retVal.length != 7)
      {
        alert(formatError);
        return false;
      }
      return retVal ;
    }
    else // Can't recognize
    {
      alert(formatError) ;
      return false ;
    }
  },

  // HSV conversion algorithm adapted from easyrgb.com
  hsv2rgb: function(hueDeg, sat, val)
  {
    var hue = hueDeg/360;  // convert from degrees to 0 to 1
    if(sat==0)
    {  // HSV values = From 0 to 1
      red = val*255;  // RGB results = From 0 to 255
      green = val*255;
      blue = val*255;
    }
    else
    {
      var_h = hue*6;
      var_i = Math.floor( var_h );  //Or ... var_i = floor( var_h )
      var_1 = val*(1-sat);
      var_2 = val*(1-sat*(var_h-var_i));
      var_3 = val*(1-sat*(1-(var_h-var_i)));
      if(var_i==0)  {var_r=val ;  var_g=var_3; var_b=var_1}
      else if(var_i==1) {var_r=var_2; var_g=val;  var_b=var_1}
      else if(var_i==2) {var_r=var_1; var_g=val;  var_b=var_3}
      else if(var_i==3) {var_r=var_1; var_g=var_2; var_b=val}
      else if(var_i==4) {var_r=var_3; var_g=var_1; var_b=val}
      else  {var_r=val;  var_g=var_1; var_b=var_2}
      red = Math.round(var_r*255);  //RGB results = From 0 to 255
      green = Math.round(var_g*255);
      blue = Math.round(var_b*255);
    }
    return new Array(red, green, blue);
  },
  
  rgbArray2HexStr: function(rgbary)
  {
    return "#" + rgbary[0].toColorPart() + rgbary[1].toColorPart() + rgbary[2].toColorPart() ;
  },

  initPalette: function() {
      this.paletteArray = new Array(this.rowNum);
     for (i=0; i < this.rowNum; i++) {
         this.paletteArray[i] = new Array(this.colNum)
     }

     var rowNum = 0;
     this.paletteArray[rowNum][0] = "000000";
     this.paletteArray[rowNum][1] = "304040";
     this.paletteArray[rowNum][2] = "707070";
     this.paletteArray[rowNum][3] = "909090";
     this.paletteArray[rowNum][4] = "b2b2b2";
     this.paletteArray[rowNum][5] = "c3c3c3";
     this.paletteArray[rowNum][6] = "0000ff";
     this.paletteArray[rowNum][7] = "00ffff";
     this.paletteArray[rowNum][8] = "00ff00";
     this.paletteArray[rowNum][9] = "ffff00";
     this.paletteArray[rowNum][10] = "ff0000";
     this.paletteArray[rowNum][11] = "ff00ff";
     this.paletteArray[rowNum][12] = "9900cc";
     this.paletteArray[rowNum][13] = "6600cc";
     this.paletteArray[rowNum][14] = "330066";
     this.paletteArray[rowNum][15] = "663399";
     this.paletteArray[rowNum][16] = "7755dd";
     this.paletteArray[rowNum][17] = "9900ff";

     rowNum = 1;
     this.paletteArray[rowNum][0] = "990099";
     this.paletteArray[rowNum][1] = "990066";
     this.paletteArray[rowNum][2] = "cc3366";
     this.paletteArray[rowNum][3] = "cc6699";
     this.paletteArray[rowNum][4] = "ff6699";
     this.paletteArray[rowNum][5] = "ff3399";
     this.paletteArray[rowNum][6] = "cc3399";
     
     this.paletteArray[rowNum][7] = "000066";
     this.paletteArray[rowNum][8] = "003399";
     this.paletteArray[rowNum][9] = "336699";
     this.paletteArray[rowNum][10] = "6666cc";
     this.paletteArray[rowNum][11] = "6666ff";
     this.paletteArray[rowNum][12] = "00ccff";
     this.paletteArray[rowNum][13] = "88eeff";
     this.paletteArray[rowNum][14] = "99cccc";
     this.paletteArray[rowNum][15] = "669999";
     this.paletteArray[rowNum][16] = "336666";
     this.paletteArray[rowNum][17] = "003333";

     rowNum = 2;
     this.paletteArray[rowNum][0] = "006633";
     this.paletteArray[rowNum][1] = "009933";
     this.paletteArray[rowNum][2] = "339966";
     this.paletteArray[rowNum][3] = "33cc66";
     this.paletteArray[rowNum][4] = "33cc33";
     this.paletteArray[rowNum][5] = "55ee55";
     this.paletteArray[rowNum][6] = "66ffcc";
     this.paletteArray[rowNum][7] = "99cc77";
     this.paletteArray[rowNum][8] = "669966";
     this.paletteArray[rowNum][9] = "669933";
     this.paletteArray[rowNum][10] = "77aa44";
     this.paletteArray[rowNum][11] = "99cc33";
     this.paletteArray[rowNum][12] = "99cc66";
     this.paletteArray[rowNum][13] = "ccff66";
     this.paletteArray[rowNum][14] = "333300";
     this.paletteArray[rowNum][15] = "666633";
     this.paletteArray[rowNum][16] = "999966";
     this.paletteArray[rowNum][17] = "999933";

      rowNum = 3;
      this.paletteArray[rowNum][0] = "ccbb00";
      this.paletteArray[rowNum][1] = "cccc33";
      this.paletteArray[rowNum][2] = "ffcc00";
      this.paletteArray[rowNum][3] = "aa7700";
      this.paletteArray[rowNum][4] = "663300";
      this.paletteArray[rowNum][5] = "774411";
      this.paletteArray[rowNum][6] = "996633";
      this.paletteArray[rowNum][7] = "cc9933";
      this.paletteArray[rowNum][8] = "ffcc99";
      this.paletteArray[rowNum][9] = "ff9966";
      this.paletteArray[rowNum][10] = "ff9933";
      this.paletteArray[rowNum][11] = "ff6633";
      this.paletteArray[rowNum][12] = "cc6633";
      this.paletteArray[rowNum][13] = "883311";
      this.paletteArray[rowNum][14] = "990000";
      this.paletteArray[rowNum][15] = "cc3300";
      this.paletteArray[rowNum][16] = "ff6666";
      this.paletteArray[rowNum][17] = "ff9999";
},



  initColorTable: function() {
    this.colorTable["ALICEBLUE"] = "#F0F8FF" ;
    this.colorTable["ANTIQUEWHITE"] = "#FAEBD7" ;
    this.colorTable["AQUA"] = "#00FFFF" ;
    this.colorTable["AQUAMARINE"] = "#7FFFD4" ;
    this.colorTable["AZURE"] = "#F0FFFF" ;
    this.colorTable["BEIGE"] = "#F5F5DC" ;
    this.colorTable["BISQUE"] = "#FFE4C4" ;
    this.colorTable["BLACK"] = "#000000" ;
    this.colorTable["BLANCHEDALMOND"] = "#FFEBCD" ;
    this.colorTable["BLUE"] = "#0000FF" ;
    this.colorTable["BLUEVIOLET"] = "#8A2BE2" ;
    this.colorTable["BROWN"] = "#A52A2A" ;
    this.colorTable["BURLYWOOD"] = "#DEB887" ;
    this.colorTable["CADETBLUE"] = "#5F9EA0" ;
    this.colorTable["CHARTREUSE"] = "#7FFF00" ;
    this.colorTable["CHOCOLATE"] = "#D2691E" ;
    this.colorTable["CORAL"] = "#FF7F50" ;
    this.colorTable["CORNFLOWERBLUE"] = "#6495ED" ;
    this.colorTable["CORNSILK"] = "#FFF8DC" ;
    this.colorTable["CRIMSON"] = "#DC143C" ;
    this.colorTable["CYAN"] = "#00FFFF" ;
    this.colorTable["DARKBLUE"] = "#00008B" ;
    this.colorTable["DARKCYAN"] = "#008B8B" ;
    this.colorTable["DARKGOLDENROD"] = "#B8860B" ;
    this.colorTable["DARKGRAY"] = "#A9A9A9" ;
    this.colorTable["DARKGREEN"] = "#006400" ;
    this.colorTable["DARKKHAKI"] = "#BDB76B" ;
    this.colorTable["DARKMAGENTA"] = "#8B008B" ;
    this.colorTable["DARKOLIVEGREEN"] = "#556B2F" ;
    this.colorTable["DARKORANGE"] = "#FF8C00" ;
    this.colorTable["DARKORCHID"] = "#9932CC" ;
    this.colorTable["DARKRED"] = "#8B0000" ;
    this.colorTable["DARKSALMON"] = "#E9967A" ;
    this.colorTable["DARKSEAGREEN"] = "#8FBC8F" ;
    this.colorTable["DARKSLATEBLUE"] = "#483D8B" ;
    this.colorTable["DARKSLATEGRAY"] = "#2F4F4F" ;
    this.colorTable["DARKTURQUOISE"] = "#00CED1" ;
    this.colorTable["DARKVIOLET"] = "#9400D3" ;
    this.colorTable["DEEPPINK"] = "#FF1493" ;
    this.colorTable["DEEPSKYBLUE"] = "#00BFFF" ;
    this.colorTable["DIMGRAY"] = "#696969" ;
    this.colorTable["DODGERBLUE"] = "#1E90FF" ;
    this.colorTable["FELDSPAR"] = "#D19275" ;
    this.colorTable["FIREBRICK"] = "#B22222" ;
    this.colorTable["FLORALWHITE"] = "#FFFAF0" ;
    this.colorTable["FORESTGREEN"] = "#228B22" ;
    this.colorTable["FUCHSIA"] = "#FF00FF" ;
    this.colorTable["GAINSBORO"] = "#DCDCDC" ;
    this.colorTable["GHOSTWHITE"] = "#F8F8FF" ;
    this.colorTable["GOLDENROD"] = "#DAA520" ;
    this.colorTable["GOLD"] = "#FFD700" ;
    this.colorTable["GRAY"] = "#808080" ;
    this.colorTable["GREEN"] = "#008000" ;
    this.colorTable["GREENYELLOW"] = "#ADFF2F" ;
    this.colorTable["HONEYDEW"] = "#F0FFF0" ;
    this.colorTable["HOTPINK"] = "#FF69B4" ;
    this.colorTable["INDIANRED"] = "#CD5C5C" ;
    this.colorTable["INDIGO"] = "#4B0082" ;
    this.colorTable["IVORY"] = "#FFFFF0" ;
    this.colorTable["KHAKI"] = "#F0E68C" ;
    this.colorTable["LAVENDERBLUSH"] = "#FFF0F5" ;
    this.colorTable["LAVENDER"] = "#E6E6FA" ;
    this.colorTable["LAWNGREEN"] = "#7CFC00" ;
    this.colorTable["LEMONCHIFFON"] = "#FFFACD" ;
    this.colorTable["LIGHTBLUE"] = "#ADD8E6" ;
    this.colorTable["LIGHTCORAL"] = "#F08080" ;
    this.colorTable["LIGHTCYAN"] = "#E0FFFF" ;
    this.colorTable["LIGHTGOLDENRODYELLOW"] = "#FAFAD2" ;
    this.colorTable["LIGHTGREEN"] = "#90EE90" ;
    this.colorTable["LIGHTGREY"] = "#D3D3D3" ;
    this.colorTable["LIGHTPINK"] = "#FFB6C1" ;
    this.colorTable["LIGHTSALMON"] = "#FFA07A" ;
    this.colorTable["LIGHTSEAGREEN"] = "#20B2AA" ;
    this.colorTable["LIGHTSKYBLUE"] = "#87CEFA" ;
    this.colorTable["LIGHTSLATEBLUE"] = "#8470FF" ;
    this.colorTable["LIGHTSLATEGRAY"] = "#778899" ;
    this.colorTable["LIGHTSTEELBLUE"] = "#B0C4DE" ;
    this.colorTable["LIGHTYELLOW"] = "#FFFFE0" ;
    this.colorTable["LIME"] = "#00FF00" ;
    this.colorTable["LIMEGREEN"] = "#32CD32" ;
    this.colorTable["LINEN"] = "#FAF0E6" ;
    this.colorTable["MAGENTA"] = "#FF00FF" ;
    this.colorTable["MAROON"] = "#800000" ;
    this.colorTable["MEDIUMAQUAMARINE"] = "#66CDAA" ;
    this.colorTable["MEDIUMBLUE"] = "#0000CD" ;
    this.colorTable["MEDIUMORCHID"] = "#BA55D3" ;
    this.colorTable["MEDIUMPURPLE"] = "#9370DB" ;
    this.colorTable["MEDIUMSEAGREEN"] = "#3CB371" ;
    this.colorTable["MEDIUMSLATEBLUE"] = "#7B68EE" ;
    this.colorTable["MEDIUMSPRINGGREEN"] = "#00FA9A" ;
    this.colorTable["MEDIUMTURQUOISE"] = "#48D1CC" ;
    this.colorTable["MEDIUMVIOLETRED"] = "#C71585" ;
    this.colorTable["MIDNIGHTBLUE"] = "#191970" ;
    this.colorTable["MINTCREAM"] = "#F5FFFA" ;
    this.colorTable["MISTYROSE"] = "#FFE4E1" ;
    this.colorTable["MOCCASIN"] = "#FFE4B5" ;
    this.colorTable["NAVAJOWHITE"] = "#FFDEAD" ;
    this.colorTable["NAVY"] = "#000080" ;
    this.colorTable["OLDLACE"] = "#FDF5E6" ;
    this.colorTable["OLIVE"] = "#808000" ;
    this.colorTable["OLIVEDRAB"] = "#6B8E23" ;
    this.colorTable["ORANGE"] = "#FFA500" ;
    this.colorTable["ORANGERED"] = "#FF4500" ;
    this.colorTable["ORCHID"] = "#DA70D6" ;
    this.colorTable["PALEGOLDENROD"] = "#EEE8AA" ;
    this.colorTable["PALEGREEN"] = "#98FB98" ;
    this.colorTable["PALETURQUOISE"] = "#AFEEEE" ;
    this.colorTable["PALEVIOLETRED"] = "#DB7093" ;
    this.colorTable["PAPAYAWHIP"] = "#FFEFD5" ;
    this.colorTable["PEACHPUFF"] = "#FFDAB9" ;
    this.colorTable["PERU"] = "#CD853F" ;
    this.colorTable["PINK"] = "#FFC0CB" ;
    this.colorTable["PLUM"] = "#DDA0DD" ;
    this.colorTable["POWDERBLUE"] = "#B0E0E6" ;
    this.colorTable["PURPLE"] = "#800080" ;
    this.colorTable["RED"] = "#FF0000" ;
    this.colorTable["ROSYBROWN"] = "#BC8F8F" ;
    this.colorTable["ROYALBLUE"] = "#4169E1" ;
    this.colorTable["SADDLEBROWN"] = "#8B4513" ;
    this.colorTable["SALMON"] = "#FA8072" ;
    this.colorTable["SANDYBROWN"] = "#F4A460" ;
    this.colorTable["SEAGREEN"] = "#2E8B57" ;
    this.colorTable["SEASHELL"] = "#FFF5EE" ;
    this.colorTable["SIENNA"] = "#A0522D" ;
    this.colorTable["SILVER"] = "#C0C0C0" ;
    this.colorTable["SKYBLUE"] = "#87CEEB" ;
    this.colorTable["SLATEBLUE"] = "#6A5ACD" ;
    this.colorTable["SLATEGRAY"] = "#708090" ;
    this.colorTable["SNOW"] = "#FFFAFA" ;
    this.colorTable["SPRINGGREEN"] = "#00FF7F" ;
    this.colorTable["STEELBLUE"] = "#4682B4" ;
    this.colorTable["TAN"] = "#D2B48C" ;
    this.colorTable["TEAL"] = "#008080" ;
    this.colorTable["THISTLE"] = "#D8BFD8" ;
    this.colorTable["TOMATO"] = "#FF6347" ;
    this.colorTable["TURQUOISE"] = "#40E0D0" ;
    this.colorTable["VIOLET"] = "#EE82EE" ;
    this.colorTable["VIOLETRED"] = "#D02090" ;
    this.colorTable["WHEAT"] = "#F5DEB3" ;
    this.colorTable["WHITE"] = "#FFFFFF" ;
    this.colorTable["WHITESMOKE"] = "#F5F5F5" ;
    this.colorTable["YELLOW"] = "#FFFF00" ;
    this.colorTable["YELLOWGREEN"] = "#9ACD32" ;
  }
}  // end of object


function handleImgClick(imgElem, event) {
    if(colorWheel == null){
    return;
    }

    // showRelCoords(imgElem, event) ;
    var relCoords = getRelCoords(imgElem, event) ;
    x = relCoords[0] ;
    y = relCoords[1] ;

    if(x > colorWheel.wheelImageWidth)
    {
        x = colorWheel.wheelImageWidth;
    }

    if(y > colorWheel.wheelImageHeight)
    {
    y = colorWheel.wheelImageHeight;
    }

    if(x < 0)
    {
    x =  0;
    }

    if(y < 0)
    {
    y = 0;
    }
      cartx = (x) - colorWheel.wheelImageWidth/2 ;
      carty = colorWheel.wheelImageHeight/2 - (y) ;

      cartx2 = cartx * cartx;
      carty2 = carty * carty;

      cartxs = (cartx < 0)?-1:1 ;
      cartys = (carty < 0)?-1:1 ;
      cartxn = cartx/(colorWheel.wheelImageWidth/2) ;  //normalize x
      rraw = Math.sqrt(cartx2 + carty2) ;  //raw radius
      rnorm = rraw/(colorWheel.wheelImageWidth/2) ; //normalized radius
      if(rraw == 0)
      {
        sat = 0;
        val = 0;
        rgb = new Array(0,0,0);
      }
      else
      {
        arad = Math.acos(cartx/rraw);  //angle in radians
        aradc = (carty>=0)?arad:2*Math.PI - arad;  //correct below axis
        angledeg = 360 * aradc/(2*Math.PI);  //convert to degrees

        if(rnorm > 1)
        {  // outside circle
          rgb = new Array(255,255,255);
          sat = 1;
          val = 1;
        }
        else if(rnorm >= .5)
        {
      	  sat = 1 - ((rnorm - .5) *2);
          val = 1;
      	  rgb = colorWheel.hsv2rgb(angledeg,sat,val);
      	}
        else // rnorm < 0.5
        {
          sat = 1;
      	  val = rnorm * 2 ;
      	  rgb = colorWheel.hsv2rgb(angledeg,sat,val);
      	}
      }
      colorWheel.hue = angledeg;
      colorWheel.sat = sat ;
      colorWheel.val = val ;

      colorWheel.setColor();
      return false;
    }

