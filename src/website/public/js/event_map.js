$(document).ready(function() {
//$(window).load(function(){ 

function init_map_multi() {
  console.log("Entering multi map function");

  mapUpperCount = document.getElementById('mapUpperCount').value;
  //alert(mapUpperCount);

  //msg = "blah\n"
  //for (i=0; i < mapUpperCount; i++) {
  for (i=0; i < mapUpperCount; i++) {
    lat_str = 'latitude_' + i.toString();
    raw_lat_val = document.getElementById(lat_str);

    lon_str = 'longitude_' + i.toString();
    raw_lon_val = document.getElementById(lon_str);
    
    lat_var = ""
    lon_var = ""

    if (raw_lat_val != null && raw_lon_val != null) {
      lat_var = raw_lat_val.value
      lon_var = raw_lon_val.value

      

      var var_location = null
      var var_mapoptions = null
      var var_marker = null
      var var_map = null


      var var_location = new google.maps.LatLng(lat_var, lon_var);

      var var_mapoptions = {
        center: var_location,
        zoom: 10,
        mapTypeId: google.maps.MapTypeId.ROADMAP
      };

      var var_marker = new google.maps.Marker({
        position: var_location,
        map: var_map,
        title:"Event Map " + i.toString()});

      map_name = "map-container_"+i.toString();
      var var_map = new google.maps.Map(document.getElementById(map_name), var_mapoptions);

      var_marker.setMap(var_map);

      //alert(map_name);
      console.log(map_name);
      console.log(lat_var);
      console.log(lon_var);
      console.log(var_location);
      console.log(var_mapoptions);
      console.log(var_marker);
      console.log("");
      console.log("------------------");

      var var_location = null
      var var_mapoptions = null
      var var_marker = null
      var var_map = null

      //console.log(document.getElementById(map_name));

      

      //google.maps.event.addDomListener(window, 'load', init_map);
    }




  }
}


  //alert(document.getElementById(str).value);



function init_map() {
  console.log("Entering map function");
  var lat_var = document.getElementById('latitude').value;
  var lon_var = document.getElementById('longitude').value;

  var var_location = null
  var var_mapoptions = null
  var var_marker = null
  var var_map = null


  //var lat_var = "39.0470574"
  //var lon_var = "-77.1157322"

  //var var_location = new google.maps.LatLng(29.709916, -95.396242);
  var var_location = new google.maps.LatLng(lat_var, lon_var);

  var var_mapoptions = {
    center: var_location,
    zoom: 10,
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };

  var var_marker = new google.maps.Marker({
    position: var_location,
    map: var_map,
    title:"Event Map"});


  map_name = "zap-container_1"
  map_name = "zap-container"
  map_name = "map-container"
  //var var_map = new google.maps.Map(document.getElementById("map-container"), var_mapoptions);
  var var_map = new google.maps.Map(document.getElementById(map_name), var_mapoptions);

  

  var_marker.setMap(var_map);

  console.log(map_name);
  console.log(lat_var);
  console.log(lon_var);
  console.log(var_location);
  console.log(var_mapoptions);
  console.log(var_marker);
  console.log("");
  console.log("------------------");

  var var_location = null
  var var_mapoptions = null
  var var_marker = null
  var var_map = null

  //
}

google.maps.event.addDomListener(window, 'load', init_map_multi);
google.maps.event.addDomListener(window, 'load', init_map);

//google.maps.event.addDomListener(window, 'load', init_map_multi);
//google.maps.event.addDomListener(window, 'load', init_map);


//window.onload = init_map;
//window.onload = init_map_multi;



});