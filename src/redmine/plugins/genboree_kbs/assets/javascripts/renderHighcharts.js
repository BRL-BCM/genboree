
// @param divId a string of the div id attribute to render to
// @param configUrl location on web where highcharts config can be GET
// requires jquery, highcharts
function renderHighcharts(divId, configUrl) {
  xmlhttp = new XMLHttpRequest();
  xmlhttp.open("GET", configUrl, false);
  xmlhttp.send();
  jsonStr = xmlhttp.responseText;
  $(function () { 
    $("#" + divId).highcharts(JSON.parse(jsonStr));
  });
}
