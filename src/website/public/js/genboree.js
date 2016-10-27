Ext.onReady(function() {
  //
  // Setup expandable left menu
  Ext.select('nav .expandable').each(function(el, c, idx) {
    el.on('click', function(e) {
      var menu = Ext.get(e.target.id + '-sublist');
      if (menu && !menu.hasClass("expanded")) 
      {
        // Open menu
        menu.slideIn() ;
        menu.addClass("expanded");
      }
      else
      {
        // Close menu
        menu.slideOut('t', {useDisplay: true});
        menu.removeClass("expanded");
      }
      e.preventDefault();
    }) ;
  }) ;

  // 
  // Simulate form submit for Login button
  Ext.get('loginButton').on('click', function(e) {
    // Add a click listener to our login 'button' (anchor) to submit our form
    var loginForm = Ext.get('logusr') ;
    if (loginForm)
    {
      e.stopEvent() ;
      loginForm.dom.submit() ;
    }
  }) ;

  // 
  // Image carousel
  var slider = Ext.get('slider')
  if (slider)
  {
    // Identify first image
    Ext.get(sliderInfo[curSlider]["id"]).addClass("active");

    // Setup image rotation
    sliderTimeout = window.setInterval(function() {
      // Select our next index
      Ext.get(sliderInfo[curSlider]["id"]).removeClass("active");
      curSlider++;
      if (curSlider >= sliderInfo.length) curSlider = 0;
      Ext.get(sliderInfo[curSlider]["id"]).addClass("active");

      // Rotate the image
      var mainImage = Ext.select('#focus img') ;
      var mainImageOverlay = Ext.select('#focus div.overlay', true).first() ;
      var mainImageTitle = Ext.select('#focus div.title', true).first();
      var mainImageCaption = Ext.select('#focus div.caption', true).first();

      if (mainImage)
      {
        mainImageOverlay.fadeOut({ useDisplay: true, duration: 0.5, callback: function() {
          mainImage.set({ 'src' : sliderInfo[curSlider]['full']}) ;
          mainImageTitle.dom.innerHTML = sliderInfo[curSlider]['title'];
          mainImageCaption.dom.innerHTML = sliderInfo[curSlider]['caption'];
        }}).fadeIn({ useDisplay: true, duration: 0.5 }) ;
      }
    }, 10000);

    // Setup slider next button
    Ext.get('slider-next').on("click", function(el) {
      // Stop current image rotator
      window.clearTimeout(sliderTimeout);

      // Select our next index
      Ext.get(sliderInfo[curSlider]["id"]).removeClass("active");
      curSlider++;
      if (curSlider >= sliderInfo.length) curSlider = 0;
      Ext.get(sliderInfo[curSlider]["id"]).addClass("active");

      // Rotate the image
      var mainImage = Ext.select('#focus img') ;
      var mainImageTitle = Ext.select('#focus div.title', true).first();
      var mainImageCaption = Ext.select('#focus div.caption', true).first();

      if (mainImage)
      {
        mainImage.set({ 'src' : sliderInfo[curSlider]['full'] }) ;
        mainImageTitle.dom.innerHTML = sliderInfo[curSlider]['title'];
        mainImageCaption.dom.innerHTML = sliderInfo[curSlider]['caption'];
      }
    });

    // Setup slider prev button
    Ext.get('slider-prev').on("click", function(el) {
      // Stop current image rotator
      window.clearTimeout(sliderTimeout);

      // Select our next index
      Ext.get(sliderInfo[curSlider]["id"]).removeClass("active");
      curSlider--;
      if (curSlider < 0) curSlider = sliderInfo.length - 1;
      Ext.get(sliderInfo[curSlider]["id"]).addClass("active");

      // Rotate the image
      var mainImage = Ext.select('#focus img') ;
      var mainImageTitle = Ext.select('#focus div.title', true).first();
      var mainImageCaption = Ext.select('#focus div.caption', true).first();

      if (mainImage)
      {
        mainImage.set({ 'src' : sliderInfo[curSlider]['full'] }) ;
        mainImageTitle.dom.innerHTML = sliderInfo[curSlider]['title'];
        mainImageCaption.dom.innerHTML = sliderInfo[curSlider]['caption'];
      }
    });

    // Setup image clicks
    slider.select('.thumbnail').each(function(el) {
      el.on('click', function(e) {
        // Stop current image rotator
        window.clearTimeout(sliderTimeout);

        var mainImage = Ext.select('#focus img') ;
        var mainImageTitle = Ext.select('#focus div.title', true).first();
        var mainImageCaption = Ext.select('#focus div.caption', true).first();

        if (mainImage)
        {
          // Attempt to match the click to the object from our sliderInfo array
          var parentEl = Ext.get(e.target).parent();
          var index = curSlider;
          Ext.get(sliderInfo[curSlider]["id"]).removeClass("active");

          for (var ii = 0; ii < sliderInfo.length; ii++)
          {
            if (sliderInfo[ii]["id"] == parentEl.id)
            {
              curSlider = ii;
              break;
            }
          }
          parentEl.addClass("active");

          // Rotate to the next
          mainImage.set({ 'src' : sliderInfo[curSlider]['full'] }) ;
          mainImageTitle.dom.innerHTML = sliderInfo[curSlider]['title'];
          mainImageCaption.dom.innerHTML = sliderInfo[curSlider]['caption'];
        }

        e.stopEvent() ;

      }) ;
    }) ;
  }
}) ;
