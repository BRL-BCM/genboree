<%@ include file="include/fwdurl.incl" %>
<html>
<head>
<title>
Color Wheel
</title>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/prototype.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/util.js<%=jsVersion%>"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="/javaScripts/colorWheel.js<%=jsVersion%>"></SCRIPT>
<link rel="stylesheet" href="/styles/colorWheel.css<%=jsVersion%>" type="text/css">
</head>
<body>
<!-- EXAMPLE USAGE: --


<!-- The Color Wheel Widget -->
<div id="wheel" >
  <div class="colorImage">
    <a  onclick="colorWheel.setColor()">
      <img  id="wheelImage" name="wheelImage" src="/images/colorWheel.png"   border="0" width="200"  height="200">
    </a>
  </div>
  <div class="colorField">
    <div id="displayBorder">
      <input type="text"  name="selColor" id="selColor" size="11" maxlength="11" value="#FFFFCC">
      <input type="button" name="setColorBtn" id="setColorBtn" width="50" value="Set" onClick="colorWheel.setWheelColor();" >
    </div>
  </div>
</div>


</body>
</html>