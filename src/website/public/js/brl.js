function toggler(divId) {
    $("#" + divId).toggle();
}

$(document).ready(function() {
  $(".collapseContent").hide();
  $(".collapseHeading").click(function()
  {
  // 	if ($("#expanderSign").text() == "+"){
		// 	$("#expanderSign").html("-")
		// }
		// else {
		// 	$("#expanderSign").text("+")
		// }
    $(this).next(".collapseContent").slideToggle(100);
  });
});
