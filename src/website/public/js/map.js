function init_map() {

  var lat_var = document.getElementById('latitude').value;
  var lon_var = document.getElementById('longitude').value;

  //var var_location = new google.maps.LatLng(29.709916, -95.396242);
  var var_location = new google.maps.LatLng(lat_var, lon_var);

  var var_mapoptions = {
    center: var_location,
    zoom: 14
  };

  var var_marker = new google.maps.Marker({
    position: var_location,
    map: var_map,
    title:"Houston, TX"});

  var var_map = new google.maps.Map(document.getElementById("map-container"),
    var_mapoptions);

  var_marker.setMap(var_map); 


}

google.maps.event.addDomListener(window, 'load', init_map);