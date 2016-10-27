/**
 * Image Cropper (v. 1.2.1 - 2009-10-06 )
 * Copyright (c) 2006-2009 David Spurr (http://www.defusion.org.uk/)
 *
 * The image cropper provides a way to draw a crop area on an image and capture
 * the coordinates of the drawn crop area.
 *
 * Features include:
 *   - Based on Prototype and Scriptaculous
 *   - Image editing package styling, the crop area functions and looks
 *     like those found in popular image editing software
 *   - Dynamic inclusion of required styles
 *   - Drag to draw areas
 *   - Shift drag to draw/resize areas as squares
 *   - Selection area can be moved
 *   - Seleciton area can be resized using resize handles
 *   - Allows dimension ratio limited crop areas
 *   - Allows minimum dimension crop areas
 *   - Allows maximum dimesion crop areas
 *   - If both min & max dimension options set to the same value for a single axis,then the cropper will not
 *     display the resize handles as appropriate (when min & max dimensions are passed for both axes this
 *     results in a 'fixed size' crop area)
 *   - Allows dynamic preview of resultant crop ( if minimum width & height are provided ), this is
 *     implemented as a subclass so can be excluded when not required
 *   - Movement of selection area by arrow keys ( shift + arrow key will move selection area by
 *     10 pixels )
 *   - All operations stay within bounds of image
 *   - All functionality & display compatible with most popular browsers supported by Prototype:
 *       PC:  IE 8, 7, 6 & 5.5, Firefox 2, 3, 3.5, Opera 8.5 (see known issues) & 9.0b
 *       MAC: Camino 1.0, Firefox 2, 3, 3.5, Safari 3.x, 4
 *
 * Requires:
 *   - Prototype v. 1.5.0_rc0 > (as packaged with Scriptaculous 1.6.1)
 *   - Scriptaculous v. 1.6.1 > modules: dragdrop
 *
 * Known issues:
 *   - Safari animated gifs, only one of each will animate, this seems to be a known Safari issue
 *
 *   - After drawing an area and then clicking to start a new drag in IE 5.5 the rendered height
 *       appears as the last height until the user drags, this appears to be the related to the error
 *       that the forceReRender() method fixes for IE 6, i.e. IE 5.5 is not redrawing the box properly.
 *
 *   - Lack of CSS opacity support in Opera before version 9 mean we disable those style rules, these
 *     could be fixed by using PNGs with transparency if Opera 8.5 support is high priority for you
 *
 *   - Marching ants keep reloading in IE <6, it is a known issue in IE and I have
 *       found no viable workarounds that can be included in the release. If this really is an issue for you
 *       either try this post: http://mir.aculo.us/articles/2005/08/28/internet-explorer-and-ajax-image-caching-woes
 *       or uncomment the 'FIX MARCHING ANTS IN IE' rules in the CSS file
 *
 *   - Styling & borders on image, any CSS styling applied directly to the image itself (floats, borders, padding, margin, etc.) will
 *     cause problems with the cropper. The use of a wrapper element to apply these styles to is recommended.
 *
 *   - overflow: auto or overflow: scroll on parent will cause cropper to burst out of parent in IE and Opera (maybe Mac browsers too)
 *     I'm not sure why yet.
 *
 * Usage:
 *   See Cropper.Img & Cropper.ImgWithPreview for usage details
 *
 * Changelog:
 * v1.2.1 - 2009-10-06
 *    + Added support for latest versions of Prototype & script.aculo.us
 *      (1.6.1.0 & 1.8.2 respectively). Changes provided by Tom Hirashima.
 *    - No-longer package prototype & script.aculo.us with the release
 *    * Changed tests to use google ajax libraries api to load prototype & script.aculo.us
 *    + Added option to not auto include the cropper CSS file
 *    * #00008 - Fixed bug: Dynamic include of cropper CSS expected cropper.js and failed when using cropper.uncompressed.js
 *    * #00028 - Fixed bug: Doesn't work with latest script.aculo.us - Fix by Tom Hirashima
 *    * #00030 - Fixed bug: Doesn't work in Firefox 3.5 (CSS include issue)
 *    * #00007 - Fixed bug: onEndCrop isn't called when moving with keys
 *    * #00011 - Fixed bug: The image that is to be cropped does not show in IE6.0 -- included CSS fix
 *    * Tidied up source code & fixed issues that jslint found so it will compress better
 *
 * v1.2.0 - 2006-10-30
 *    + Added id to the preview image element using 'imgCrop_[originalImageID]'
 *      * #00001 - Fixed bug: Doesn't account for scroll offsets
 *      * #00009 - Fixed bug: Placing the cropper inside differently positioned elements causes incorrect co-ordinates and display
 *      * #00013 - Fixed bug: I-bar cursor appears on drag plane
 *      * #00014 - Fixed bug: If ID for image tag is not found in document script throws error
 *      * Fixed bug with drag start co-ordinates if wrapper element has moved in browser (e.g. dragged to a new position)
 *      * Fixed bug with drag start co-ordinates if image contained in a wrapper with scrolling - this may be buggy if image
 *      has other ancestors with scrolling applied (except the body)
 *      * #00015 - Fixed bug: When cropper removed and then reapplied onEndCrop callback gets called multiple times, solution suggestion from Bill Smith
 *      * Various speed increases & code cleanup which meant improved performance in Mac - which allowed removal of different overlay methods for
 *        IE and all other browsers, which led to a fix for:
 *    * #00010 - Fixed bug: Select area doesn't adhere to image size when image resized using img attributes
 *      - #00006 - Removed default behaviour of automatically setting a ratio when both min width & height passed, the ratioDimensions must be passed in
 *    + #00005 - Added ability to set maximum crop dimensions, if both min & max set as the same value then we'll get a fixed cropper size on the axes as appropriate
 *        and the resize handles will not be displayed as appropriate
 *    * Switched keydown for keypress for moving select area with cursor keys (makes for nicer action) - doesn't appear to work in Safari
 *
 * v1.1.3 - 2006-08-21
 *    * Fixed wrong cursor on western handle in CSS
 *    + #00008 & #00003 - Added feature: Allow to set dimensions & position for cropper on load
 *      * #00002 - Fixed bug: Pressing 'remove cropper' twice removes image in IE
 *
 * v1.1.2 - 2006-06-09
 *    * Fixed bugs with ratios when GCD is low (patch submitted by Andy Skelton)
 *
 * v1.1.1 - 2006-06-03
 *    * Fixed bug with rendering issues fix in IE 5.5
 *    * Fixed bug with endCrop callback issues once cropper had been removed & reset in IE
 *
 * v1.1.0 - 2006-06-02
 *    * Fixed bug with IE constantly trying to reload select area background image
 *    * Applied more robust fix to Safari & IE rendering issues
 *    + Added method to reset parameters - useful for when dynamically changing img cropper attached to
 *    + Added method to remove cropper from image
 *
 * v1.0.0 - 2006-05-18
 *    + Initial verison
 *
 *
 * Copyright (c) 2006-2009, David Spurr (http://www.defusion.org.uk/)
 *
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *     * Neither the name of the David Spurr nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * http://www.opensource.org/licenses/bsd-license.php
 *
 * See scriptaculous.js for full scriptaculous licence
 */

/**
 * Extend the Draggable class to allow us to pass the rendering
 * down to the Cropper object.
 */
var CropDraggable = Class.create(Draggable, {

  initialize: function(element) {
    this.options = Object.extend(
      {
        /**
         * The draw method to defer drawing to
         */
        drawMethod: function() {}
      },
      arguments[1] || {}
    );

    this.element = $(element);

    this.handle = this.element;

    this.delta    = this.currentDelta();
    this.dragging = false;

    this.eventMouseDown = this.initDrag.bindAsEventListener(this);
    Event.observe(this.handle, "mousedown", this.eventMouseDown);

    Draggables.register(this);
  },

  /**
   * Defers the drawing of the draggable to the supplied method
   */
  draw: function(point) {
    var pos = Element.cumulativeOffset(this.element),
        d = this.currentDelta();
    pos[0] -= d[0];
    pos[1] -= d[1];

    var p = [0,1].map(function(i) {
      return (point[i]-pos[i]-this.offset[i]);
    }.bind(this));

    this.options.drawMethod( p );
  }

});


/**
 * The Cropper object, this will attach itself to the provided image by wrapping it with
 * the generated xHTML structure required by the cropper.
 *
 * Usage:
 *  @param obj Image element to attach to
 *  @param obj Optional options:
 *     - ratioDim obj
 *       The pixel dimensions to apply as a restrictive ratio, with properties x & y
 *
 *     - minWidth int
 *       The minimum width for the select area in pixels
 *
 *     - minHeight  int
 *       The mimimum height for the select area in pixels
 *
 *     - maxWidth int
 *       The maximum width for the select areas in pixels (if both minWidth & maxWidth set to same the width of the cropper will be fixed)
 *
 *     - maxHeight int
 *       The maximum height for the select areas in pixels (if both minHeight & maxHeight set to same the height of the cropper will be fixed)
 *
 *     - displayOnInit int
 *       Whether to display the select area on initialisation, only used when providing minimum width & height or ratio
 *
 *     - onEndCrop func
 *       The callback function to provide the crop details to on end of a crop (see below)
 *
 *     - captureKeys boolean
 *       Whether to capture the keys for moving the select area, as these can cause some problems at the moment
 *
 *     - onloadCoords obj
 *       A coordinates object with properties x1, y1, x2 & y2; for the coordinates of the select area to display onload
 *
 *     - autoIncludeCSS boolean
 *       Whether to automatically include the stylesheet (assumes it lives in the same location as the cropper JS file)
 *-    ---------------------------------------------
 *
 * The callback function provided via the onEndCrop option should accept the following parameters:
 *   - coords obj
 *     The coordinates object with properties x1, y1, x2 & y2; for the coordinates of the select area
 *
 *   - dimensions obj
 *     The dimensions object with properites width & height; for the dimensions of the select area
 *
 *
 *   Example:
 *     function onEndCrop( coords, dimensions ) {
 *         $( 'x1' ).value = coords.x1;
 *         $( 'y1' ).value = coords.y1;
 *         $( 'x2' ).value = coords.x2;
 *         $( 'y2' ).value = coords.y2;
 *         $( 'width' ).value = dimensions.width;
 *         $( 'height' ).value = dimensions.height;
 *     }
 *
 */
var Cropper = {};
Cropper.Img = Class.create({

  /**
   * Initialises the class
   *
   * @access public
   * @param obj Image element to attach to
   * @param obj Options
   * @return void
   */
  initialize: function(element, options) {
    this.options = Object.extend(
      {
        /**
         * @var int
         * ARJ: New option: left-bound (left margin; minimum X value) for crop selection rectangle. Default is 0 (no left margin)
         */
        minX : 0,
        /**
         * @var int
         * ARJ: New option: top-bound (top margin; minimum Y value) for crop selection rectangle. Default is 0 (no top margin)
         */
        minY : 0,
        /**
         * @var int [default: undefined]
         * ARJ: New option: right-bound (right margin; maximum X value) for crop selection rectangle. Default is undefined (i.e. false, use full image width)
         */
        // maxX : <undef>,
        /**
         * @var int [default: undefined]
         * ARJ: New option: bottom-bound (bottom margin; maximum Y value) for crop selection rectangle. Default is undefined (i.e. false, use full image height)
         */
        // maxY : <undef>,
        /**
         * @var boolean
         * ARJ: New option: hide the resize handles (useful for immediate redirects/form-submits upon endCrop). Default is false (show handles).
         */
        hideHandles : false,
        /**
         * @var boolean
         * ARJ: New option: should clicking in an overlay cancel the crop selection (and throw observable 'cancel' event)? Default is false (original behavior; relocates the crop selection)
         */
        overlayCancels : false,
        /**
         * @var boolean
         * ARJ: New option: should the escape key [on most OS's] cancel the selection? Default is false. If you
         * want a selection/cropper that is not [easily] cancellable, both overlayCancels and escCancels should be false,
         * and--obviously--displayOnInit probably should be true.
         */
        escCancels : false,
        /**
         * @var boolean
         * ARJ: New option: should we show some text centered in the overlays? Most useful with overlayCancels to provide indication that an overlay click will cancel crop selection. Default is false (original behavior).
         */
        showOverlayText : false,
        /**
         * @var string
         * ARJ: new option: the text to display in the overlays, if showOverlayText=true. Default is "".
         */
        overlayText : "",
        /**
         * @var boolean
         * ARJ: New option: only activate crop selection when click occurs in a selected region (dev must provide activationRegion bounding box). Default is false (anywhere on image activates).
         */
        useActivationRegion : false,
        /**
         * @var obj (with bounding box properties x1, y1, x2, y2)
         * ARJ: New option: bounding box of activation region where crop selection can initiate. Use with useActivationRegion=true. Default is undefined (i.e. anywhere in image activates)
         */
        // activationRegion : <undef>,
        /**
         * @var ob (with margin properties top, right, bottom, left)
         * ARJ: New option:  the number of pixels the mouseup event can be *outside* the activation region (can be a little more convenient w/o touching other widgets). Default is 0,0,0,0.
         */
        mouseupFuzziness : { top: 0, right: 0, bottom: 0, left: 0 },
        /**
         * @var function
         * ARJ: New option: callback for cancellation of crop selection. Default is an empty function that does nothing.
         */
        onCancel: Prototype.emptyFunction,
        /**
         * @var handleType String ("square" or "full")
         * ARJ: New option: in additon to the square resize handles ("square"), supports making the whole
         * "sides" of the selection area handles rather than the little resize-squares. In using the selector,
         * users continually try to resize by grabbing the selction boundaries rather than the handles. Particularly for
         * large selections whose n,e,s,w square handles are off-page. The cropper now supports two different, and
         * somewhat customizable, handle styles.
         */
        handleType : "square",
        /**
         * @var handleConfig Object (with optional fields size, border, background, opacity)
         * ARJ: Since the static-class approach doesn't easily permit 2+ croppers on the same page to
         * have very different styles and maintaining both a code file and a css file just to tweak some
         * display settings is not productive, this variable lets the user tweak certain key handle display settings
         * which will override the default styles for the "square" or "full" handles. All or some of the config field
         * may be filled in when the object is created using this option. The example below shows the settings are for "square" style handles,
         * but the default for this option is undefined, causing the default config to be used.
         *
        handleConfig : {
          size    : 6,                // size in PIXELS of the handle as css size string; will be used for width & height for "square" and the handle thickness for "full".
          border  : "1px solid #333", // complete css border string; will be used for the borders of the handle [0px should be "none"]
          background : "#FFF",        // the color of the background of the handle
          opacity : 0.5               // an ECMAscript opacity number; IE-proprietary one will be created automatically as well
        },
         */
        /**
         * @var overlayConfig Object (currently with 1 field opacity)
         * ARJ: New option: The static-class approach does not easily permit 2+ croppers on the same page
         * to have different overlay opacities. By having the code set element-specific opacities, we can
         * override any default setting kindly supplied by the generic imgCrop_overlay class and easily tweak this
         * setting without having to worry about defining more CSS classes, which class in a multiple list should override
         * (undefined anyway, although most browsers do right>left), etc. The exmaple below shows the settings for
         * the default of 0.5, which is what you get anyway by default from the CSS file.
        overlayConfig : {
          opacity : 0.5
        },
         */
        /**
         * @var marqueeConfig Object (currently with these fields: vertMarqueeGif (a url), horizMarqueeGif (a url), vertMarqueeWidth, horizMarqueeHeight)
         * ARJ: New option: Programmatically set the background image urls for the marquee, which creates the
         * selection's animated border. Rather than make this a statically coded style class and having to manage that
         * somewhere (and possibly for each separate cropper you have on the page, if they need different appearances),
         * you can set this where you config the cropper: in its constructor. Yay. The example below shows the settings for
         * the default image, which what you get if you don't supply this config option.
        marqueeConfig : {
          vertMarqueeGif  : 'marqueeVert.gif',
          horizMarqueeGif : 'marqueeHoriz.gif',
          vertMarqueeWidth : 1px,
          horizMarqueeHeight : 1px
        },
         */
        /**
         * @var obj
         * The pixel dimensions to apply as a restrictive ratio
         */
        ratioDim: { x: 0, y: 0 },
        /**
         * @var int
         * The minimum pixel width, also used as restrictive ratio if min height passed too
         */
        minWidth:    0,
        /**
         * @var int
         * The minimum pixel height, also used as restrictive ratio if min width passed too
         */
        minHeight:    0,
        /**
         * @var boolean
         * Whether to display the select area on initialisation, only used when providing minimum width & height or ratio
         */
        displayOnInit:  false,
        /**
         * @var function
         * The call back function to pass the final values to
         */
        onEndCrop: Prototype.emptyFunction,
        /**
         * @var boolean
         * Whether to capture key presses or not
         */
        captureKeys: true,
        /**
         * @var obj Coordinate object x1, y1, x2, y2
         * The coordinates to optionally display the select area at onload
         */
        onloadCoords: null,
        /**
         * @var int
         * The maximum width for the select areas in pixels (if both minWidth & maxWidth set to same the width of the cropper will be fixed)
         */
        maxWidth: 0,
        /**
         * @var int
         * The maximum height for the select areas in pixels (if both minHeight & maxHeight set to same the height of the cropper will be fixed)
         */
        maxHeight: 0,
        /**
         * @var boolean - default true
         * Whether to automatically include the stylesheet (assumes it lives in the same location as the cropper JS file)
         */
        autoIncludeCSS: true
      },
      options || {}
    );
    /**
     * @var obj
     * The img node to attach to
     */
    this.img = $( element );
    /**
     * @var obj
     * The x & y coordinates of the click point
     */
    this.clickCoords = { x: 0, y: 0 };
    /**
     * @var boolean
     * Whether the user is dragging
     */
    this.dragging = false;
    /**
     * @var boolean
     * Whether the user is resizing
     */
    this.resizing = false;
    /**
     * @var boolean
     * Whether the user is on a webKit browser
     */
    this.isWebKit = /Konqueror|Safari|KHTML/.test( navigator.userAgent );
    /**
     * @var boolean
     * Whether the user is on IE
     */
    this.isIE = /MSIE/.test( navigator.userAgent );
    /**
     * @var boolean
     * Whether the user is on Opera below version 9
     */
    this.isOpera8 = /Opera\s[1-8]/.test( navigator.userAgent );
    /**
     * @var int
     * The x ratio
     */
    this.ratioX = 0;
    /**
     * @var int
     * The y ratio
     */
    this.ratioY = 0;
    /**
     * @var boolean
     * Whether we've attached sucessfully
     */
    this.attached = false;
    /**
     * @var boolean
     * ARJ: New obj state: whether the crop selection is currently active or not. For use implementing useActivationRegion.
     */
    this.active = false ;
    /**
     * @var boolean
     * Whether we've got a fixed width (if minWidth EQ or GT maxWidth then we have a fixed width
     * in the case of minWidth > maxWidth maxWidth wins as the fixed width)
     */
    this.fixedWidth = ( this.options.maxWidth > 0 && ( this.options.minWidth >= this.options.maxWidth ) );
    /**
     * @var boolean
     * Whether we've got a fixed height (if minHeight EQ or GT maxHeight then we have a fixed height
     * in the case of minHeight > maxHeight maxHeight wins as the fixed height)
     */
    this.fixedHeight = ( this.options.maxHeight > 0 && ( this.options.minHeight >= this.options.maxHeight ) );
    /**
     * @var boolean
     * ARJ: New State: are we currently processing a key event? Handling key event flag is true. Used by other methods to process key events
     * slightly differently that mouse events (especially when calculating positions of the event and such).
     */
    this.doingKeyPress = false ;
    /**
     * @var int
     * ARJ: if user has customized the handle border style, we'll need to dig out the border width
     * so we can use it to fix IE's buggy box model (they couldn't understand the W3C standard) via some hacks
     * when we set handle width. This is necessary because we set the widths in code based on user configurations
     * not via hard-coded values from a static CSS file.
     * This value is in px.
     */
    this.handleBorderWidth = 1 ;

    // quit if the image element doesn't exist
    if( typeof this.img == 'undefined' ) { return; }

    // include the stylesheet
    if( this.options.autoIncludeCSS ) {
      $$('script').each(function(s) {
        if( s.src.match( /\/cropper([^\/]*)\.js/ ) ) {
          var path    = s.src.replace( /\/cropper([^\/]*)\.js.*/, '' ),
              style   = document.createElement( 'link' );
          style.rel   = 'stylesheet';
          style.type  = 'text/css';
          style.href  = path + '/cropper.css';
          style.media = 'screen';
          document.getElementsByTagName( 'head' )[0].appendChild( style );
        }
      });
    }

    // ARJ: initialize the activationRegion. Will default whole image if useActivationRegion=false OR dev forgot
    //      to give us their specific activationRegion bounding box.
    if( !this.options.useActivationRegion || !this.options.activationRegion )
    {
      this.options.activationRegion = { x1: 0, y1: 0, x2: this.img.width, y2: this.img.height } ;
    }

    // calculate the ratio when neccessary
    if( this.options.ratioDim.x > 0 && this.options.ratioDim.y > 0 ) {
      var gcd = this.getGCD( this.options.ratioDim.x, this.options.ratioDim.y );
      this.ratioX = this.options.ratioDim.x / gcd;
      this.ratioY = this.options.ratioDim.y / gcd;
      // dump( 'RATIO : ' + this.ratioX + ':' + this.ratioY + '\n' );
    }

    // initialise sub classes
    this.subInitialize();

    // only load the event observers etc. once the image is loaded
    // this is done after the subInitialize() call just in case the sub class does anything
    // that will affect the result of the call to onLoad()
    if( this.img.complete || this.isWebKit ) {
      this.onLoad(); // for some reason Safari seems to support img.complete but returns 'undefined' on the this.img object
    } else {
      Event.observe( this.img, 'load', this.onLoad.bindAsEventListener( this) );
    }
  },

  /**
   * The Euclidean algorithm used to find the greatest common divisor.
   * ARJ: Note: recursive algorithms are expensive and run risk of stack-heap collisions (unless implemented as tail-recursion).
   *      The iterative version (the kind Euclid described) is: function gcd(aa,bb) { while(bb != 0) { tmp = bb ; bb = aa mod bb; aa = tmp; } ; return a ; }
   *
   * @acces private
   * @param int Value 1
   * @param int Value 2
   * @return int
   */
  getGCD : function( a , b ) {
    if( b === 0 ) { return a; }
    return this.getGCD(b, a % b );
  },

  /**
   * Attaches the cropper to the image once it has loaded
   *
   * @access private
   * @return void
   */
  onLoad: function( ) {
    /*
     * Build the container and all related elements, will result in the following
     *
     * <div class="imgCrop_wrap">
     *   <img ... this.img ... />
     *   <div class="imgCrop_dragArea">
     *     <!-- the inner spans are only required for IE to stop it making the divs 1px high/wide -->
     *     <div class="imgCrop_overlay imageCrop_north"><span></span></div>
     *     <div class="imgCrop_overlay imageCrop_east"><span></span></div>
     *     <div class="imgCrop_overlay imageCrop_south"><span></span></div>
     *     <div class="imgCrop_overlay imageCrop_west"><span></span></div>
     *     <div class="imgCrop_selArea">
     *       <!-- marquees -->
     *       <!-- the inner spans are only required for IE to stop it making the divs 1px high/wide -->
     *       <div class="imgCrop_marqueeHoriz imgCrop_marqueeNorth"><span></span></div>
     *       <div class="imgCrop_marqueeVert imgCrop_marqueeEast"><span></span></div>
     *       <div class="imgCrop_marqueeHoriz imgCrop_marqueeSouth"><span></span></div>
     *       <div class="imgCrop_marqueeVert imgCrop_marqueeWest"><span></span></div>
     *       <!-- handles -->
     *       <div class="imgCrop_handle imgCrop_handleN"></div>
     *       <div class="imgCrop_handle imgCrop_handleNE"></div>
     *       <div class="imgCrop_handle imgCrop_handleE"></div>
     *       <div class="imgCrop_handle imgCrop_handleSE"></div>
     *       <div class="imgCrop_handle imgCrop_handleS"></div>
     *       <div class="imgCrop_handle imgCrop_handleSW"></div>
     *       <div class="imgCrop_handle imgCrop_handleW"></div>
     *       <div class="imgCrop_handle imgCrop_handleNW"></div>
     *       <div class="imgCrop_clickArea"></div>
     *     </div>
     *     <div class="imgCrop_clickArea"></div>
     *   </div>
     * </div>
     */
    var cNamePrefix = 'imgCrop_';
    // ARJ: id prefix, based on img id so we can support multiple croppers on the page
    var cIdPrefix = this.img.id + '_imgCrop_' ;

    // get the point to insert the container
    var insertPoint = this.img.parentNode;

    // apply an extra class to the wrapper to fix Opera below version 9
    var fixOperaClass = '';
    if( this.isOpera8 ) { fixOperaClass = ' opera8'; }
    this.imgWrap = new Element( 'div', { 'id' : cIdPrefix + 'wrap_id1', 'class': cNamePrefix + 'wrap' + fixOperaClass } );
    // ARJ: give this div an id, we'll want quick, efficient access to it elsewhere
    this.dragArea = new Element( 'div', { 'id' : cIdPrefix + 'dragArea_id1', 'class': cNamePrefix + 'dragArea' } );

    // ARJ: orginal puts in an empty span (a necesary hack), but we'll put in a div that can be used to hold the overlay text if enabled
    this.north = new Element( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'north' }).insert(new Element( 'div', { 'class': cNamePrefix + 'overlayText'}));
    this.east  = new Element( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'east' }).insert(new Element( 'div', { 'class': cNamePrefix + 'overlayText'}));
    this.south = new Element( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'south' }).insert(new Element( 'div', { 'class': cNamePrefix + 'overlayText'}));
    this.west  = new Element( 'div', { 'class': cNamePrefix + 'overlay ' + cNamePrefix + 'west' }).insert(new Element( 'div', { 'class': cNamePrefix + 'overlayText'}));

    // ARJ: let's keep this convenient array of overlays for use elsewhere
    this.overlays = [ this.north, this.east, this.south, this.west ] ;
    // ARJ: set custom overlay config, if any
    if(this.options.overlayConfig)
    {
      this.overlays.each( function(overlay)
      {
        var style = "" ;
        var opac = this.options.overlayConfig.opacity ;
        if(opac)
        {
          var ieOpac = Math.round(100.0 * opac) ;
          overlay.setStyle({
            'opacity' : opac,
            'filter'  : "alpha(opacity=" + ieOpac + ")"
          }) ;
        }
      }, this) ;
    }

    // ARJ: While inserting each overlay into the dragArea div, also add the overlay display text.
    //      Actually, it will be added as innerHTML alllowing some simple/basic formatting (e.g. <br>'s or such)
    this.overlays.each(  function(overlay)
    {
      // ARJ: insert the overlay div into its parent
      this.dragArea.insert(overlay) ;
      // ARJ: add the overlay display text if enabled.
      if(this.options.showOverlayText)
      {
        overlay.down().innerHTML = this.options.overlayText ;
      } ;
    }, this) ;

    // ARJ: give selArea's clickArea div an id for quick, efficient access later; so important, let's also save it in object state.
    //      In particular, to solve an open IE bug that some cropper users encounter (including me),
    //      we'll need to ensure this div hasLayout = true in IE for this when applying to images displayed within tables.
    //      Else opacity/alpha-filter won't work in IE!
    this.selAreaClickArea = new Element( 'div', { 'id' : cIdPrefix + 'clickArea_id1', 'class': cNamePrefix + 'clickArea' }) ;
    // ARJ: similarly, give image clickArea div an id and save in object state for quick, efficient access later.
    //      As with the selArea's clickArea, we'll need to ensure hasLayout = true in IE for this when applying to images within tables.
    this.imgClickArea = new Element( 'div', { 'id' : cIdPrefix + 'clickArea_id2', 'class': cNamePrefix + 'clickArea' } ) ;

    // ARJ: selArea itself
    this.selArea = new Element( 'div', { 'class': cNamePrefix + 'selArea' }) ;
    // ARJ: prep custom background style for marquees, if any:
    var marqueeBackgroundStyle = this.makeCustomMarqueeBackgroundStyles() ;
    // ARJ: Collect the internal elements of selArea, starting with the marquees.
    // ARJ: The marquee's now have names. This fixes the getElementsByClassName() bug (which, for cross-browser
    // support, ought to be Element.select() due to FF3.5 and IE8 implementing this themselves (and thus Prototype has dropped it!)
    // while other browsers not having it won't work with Prototype because it's been deprecated out of the library). Now we will get
    // the marquee faster, by id.
    var selAreaInternalElems =
    [
      new Element( 'div', { 'id' : cIdPrefix + 'marqueeNorth', 'class': cNamePrefix + 'marqueeHoriz ' + cNamePrefix + 'marqueeNorth', 'style' : marqueeBackgroundStyle.horz + marqueeBackgroundStyle.height }).insert(new Element( 'span' )),
      new Element( 'div', { 'id' : cIdPrefix + 'marqueeEast', 'class': cNamePrefix + 'marqueeVert ' + cNamePrefix + 'marqueeEast', 'style' : marqueeBackgroundStyle.vert + marqueeBackgroundStyle.width }).insert(new Element( 'span' )),
      new Element( 'div', { 'id' : cIdPrefix + 'marqueeSouth', 'class': cNamePrefix + 'marqueeHoriz ' + cNamePrefix + 'marqueeSouth', 'style' : marqueeBackgroundStyle.horz + marqueeBackgroundStyle.height }).insert(new Element( 'span' )),
      new Element( 'div', { 'id' : cIdPrefix + 'marqueeWest', 'class': cNamePrefix + 'marqueeVert ' + cNamePrefix + 'marqueeWest', 'style' : marqueeBackgroundStyle.vert + marqueeBackgroundStyle.width }).insert(new Element( 'span' ))
    ] ;

    // ARJ: Create the handles and add if supposed to show them
    // First, if there's a custom handle border style, we need to dig out the border width since we'll need it later:
    if(this.options.handleConfig && this.options.handleConfig.border)
    {
      var matches = /(\d+)(?:px|em|%|pt)/.exec(this.options.handleConfig.border) ;
      if(matches)
      {
        this.handleBorderWidth = parseInt(matches[1]) ;
      }
    }
    // Ok, can now make the handles and do any IE hacks needed
    var hndls = new Object() ;
    var hndlsNeeded = ((this.options.handleType == "full") ?  ['n', 'e', 's', 'w'] : ['n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw']) ;
    hndlsNeeded.each( function(hndl)
    {
      var handleElem = this.makeHandleElem(hndl, cNamePrefix) ;
      hndls[hndl] = handleElem ;
      selAreaInternalElems.push(handleElem) ;
    }, this) ;
    // ARJ: Last internal div for selArea is the clickArea
    selAreaInternalElems.push(this.selAreaClickArea) ;

    // ARJ: Save the handles that were created in the original convenience instance variables
    // (handles that are not going to be shown will be undefined).
    this.handleN  = hndls.n ;
    this.handleNE = hndls.ne ;
    this.handleE  = hndls.e ;
    this.handleSE = hndls.se ;
    this.handleS  = hndls.s ;
    this.handleSW = hndls.sw ;
    this.handleW  = hndls.w ;
    this.handleNW = hndls.nw ;
    // Keep them in a convenient iteratable array too...
    this.handles = [ this.handleN, this.handleNE, this.handleE, this.handleSE, this.handleS, this.handleSW, this.handleW, this.handleNW ];
    // ARJ: Now add all the internal elements of selArea
    selAreaInternalElems.each(  function(elem)
    {
      this.selArea.insert(elem);
    }, this) ;

    this.imgWrap.appendChild( this.img );
    this.imgWrap.appendChild( this.dragArea );
    this.dragArea.appendChild( this.selArea );
    // ARJ: add image's clickArea
    this.dragArea.appendChild(this.imgClickArea) ;

    insertPoint.appendChild( this.imgWrap );

    // add event observers
    this.startDragBind = this.startDrag.bindAsEventListener( this );
    Event.observe( this.dragArea, 'mousedown', this.startDragBind );

    this.onDragBind = this.onDrag.bindAsEventListener( this );
    Event.observe( document, 'mousemove', this.onDragBind );

    this.endCropBind = this.endCrop.bindAsEventListener( this );
    Event.observe( document, 'mouseup', this.endCropBind );

    this.resizeBind = this.startResize.bindAsEventListener( this );
    this.registerHandles( true );

    if( this.options.captureKeys ) {
      this.keysBind = this.handleKeys.bindAsEventListener( this );
      Event.observe( document, 'keydown', this.keysBind );
    }

    // ARJ: observe the activation event
    this.activateDragBind = this.activateDrag.bindAsEventListener(this) ;
    Event.observe(this.imgWrap, 'mousedown', this.activateDragBind) ;

    // attach the dragable to the select area
    var x = new CropDraggable( this.selArea, { drawMethod: this.moveArea.bindAsEventListener( this ) } );

    this.setParams() ;

    // ARJ: All done initializing...except we MUST hide the dragArea IF the dev has enabled and defined the
    //      activationRegion. Otherwise, dragArea will intercept click events OUTSIDE the activationRegion;
    //      click events that should have gone to an image's <map> for example will be intercepted and cancelled (sucks).
    //      Thus: hide dragArea and show it when a click arrives in the activationRegion, and then pass the click event
    //      over to the dragArea (as if it had been clicked directly) for usual processing.
    if(!this.options.displayOnInit)
    {
      this.dragArea.hide() ;
    }
    else // is displayed and thus also needs to be active
    {
      this.active = true ;
    }
  },

  /**
   * Manages adding or removing the handle event handler and hiding or displaying them as appropriate.
   * ARJ: handles that are undefined (probably due to this.options.handleType=='full' not using all of them) will
   * be skipped properly.
   *
   * @access private
   * @param boolean registration true = add, false = remove
   * @return void
   */
  registerHandles: function( registration )
  {
    for( var i = 0; i < this.handles.length; i++ )
    {
      var handle = $( this.handles[i] ) ;
      // ARJ: Register handle listeners etc, if they exist
      if(handle)
      {
        if( registration )
        {
          var hideHandle  = false;  // whether to hide the handle
          // disable handles as appropriate if we've got fixed dimensions
          // if both dimensions are fixed we don't need to do much
          if( (this.fixedWidth && this.fixedHeight) || (this.options.hideHandles) )
          {
            hideHandle = true;
          }
          else if( this.fixedWidth || this.fixedHeight )
          {
            // if one of the dimensions is fixed then just hide those handles
            // ARJ: this makes sense for both "square" and "full" type handles
            var isCornerHandle = handle.className.match( /([S|N][E|W])$/ ),
                isWidthHandle  = handle.className.match( /(E|W)$/ ),
                isHeightHandle = handle.className.match( /(N|S)$/ );
            // ARJ: changed: corner handles always shown. Users struggled when the image & selection were very
            // large and the only resize handle was off-page because the height was fixed [to be full image height].
            // Better to show the corner ones always (but with their constrained resize functionality) and just get
            // rid of the ones in the middle of the side perpendicular to the fixed axis.
            if( ( this.fixedWidth && isWidthHandle ) || ( this.fixedHeight && isHeightHandle ) )
            {
              hideHandle = true;
            }
          }
          if( hideHandle )
          {
            handle.hide();
          }
          else
          {
            Event.observe( handle, 'mousedown', this.resizeBind );
          }
        }
        else
        {
          handle.show();
          Event.stopObserving( handle, 'mousedown', this.resizeBind );
        }
      }
    }
  },

  /**
   * Sets up all the cropper parameters, this can be used to reset the cropper when dynamically
   * changing the images
   *
   * @access private
   * @return void
   */
  setParams: function() {
    /**
     * @var int
     * The image width
     */
    this.imgW = this.img.width;
    /**
     * @var int
     * The image height
     */
    this.imgH = this.img.height;

    $( this.north ).setStyle( { height: 0 } );
    $( this.east ).setStyle( { width: 0, height: 0 } );
    $( this.south ).setStyle( { height: 0 } );
    $( this.west ).setStyle( { width: 0, height: 0 } );

    // resize the container to fit the image
    $( this.imgWrap ).setStyle( { 'width': this.imgW + 'px', 'height': this.imgH + 'px' } );
    // ARJ: also must resize the image's clickArea div. Failure to do this means cropper breaks in IE
    //      when the image is within a table (or tables within tables). This is due to a long-standing set of
    //      bugs related to applying filters to page elements in IE (e.g. to add an opacity filter).
    $( this.imgClickArea ).setStyle( { 'width': this.imgW + 'px', 'height': this.imgH + 'px' } );

    // hide the select area
    $( this.selArea ).hide();

    // setup the starting position of the select area
    var startCoords = { x1: 0, y1: 0, x2: 0, y2: 0 },
        validCoordsSet = false;

    // display the select area
    if( this.options.onloadCoords !== null ) {
      // if we've being given some coordinates to
      startCoords = this.cloneCoords( this.options.onloadCoords );
      validCoordsSet = true;
    } else if( this.options.ratioDim.x > 0 && this.options.ratioDim.y > 0 ) {
      // if there is a ratio limit applied and the then set it to initial ratio
      startCoords.x1 = Math.ceil( ( this.imgW - this.options.ratioDim.x ) / 2 );
      startCoords.y1 = Math.ceil( ( this.imgH - this.options.ratioDim.y ) / 2 );
      startCoords.x2 = startCoords.x1 + this.options.ratioDim.x;
      startCoords.y2 = startCoords.y1 + this.options.ratioDim.y;
      validCoordsSet = true;
    }

    this.setAreaCoords( startCoords, false, false, 1 );

    if( this.options.displayOnInit && validCoordsSet ) {
      this.selArea.show();
      this.drawArea();
      this.endCrop();
    }

    this.attached = true;
  },

  /**
   * Removes the cropper
   *
   * @access public
   * @return void
   */
  remove: function() {
    if( this.attached ) {
      this.attached = false;

      // remove the elements we inserted
      this.imgWrap.parentNode.insertBefore( this.img, this.imgWrap );
      this.imgWrap.parentNode.removeChild( this.imgWrap );

      // remove the event observers
      Event.stopObserving( this.dragArea, 'mousedown', this.startDragBind );
      Event.stopObserving( document, 'mousemove', this.onDragBind );
      Event.stopObserving( document, 'mouseup', this.endCropBind );
      this.registerHandles( false );
      if( this.options.captureKeys ) {
        Event.stopObserving( document, 'keypress', this.keysBind );
      }
    }
  },

  /**
   * Resets the cropper, can be used either after being removed or any time you wish
   *
   * @access public
   * @return void
   */
  reset: function() {
    if( !this.attached ) {
      this.onLoad();
    } else {
      this.setParams();
    }
    this.endCrop();
  },

  /**
   * ARJ: Cancels an active crop selection. Hides the dragArea again if useActivationRegion=true so
   *      clicks won't get intercepted before they hit the image's <map> or such. Calls the dev's
   *      onCancel callback so they can do what they need to upon cancel.
   */
  doCancel: function()
  {
    //if(this.options.useActivationRegion)
    //{
      this.dragArea.hide() ;
    //}
    this.active = false ;
    this.reset() ;
    this.options.onCancel() ;
  },

  /**
   * Handles the key functionality, currently just using arrow keys to move, if the user
   * presses shift then the area will move by 10 pixels.
   * ARJ: Note: the arrows don't seem to work. I don't really get it. But the 'Esc' key works,
   *      except in Safari which has a long history of dealing with key events badly and against spec when it does actually fire.
   */
  handleKeys: function( e ) {
    // ARJ: Handling key event flag is true. Used by other methods to process key events
    // slightly differently that mouse events (especially when calculating positions of the event and such).
    this.doingKeyPress = true ;
    var dir = { x: 0, y: 0 }; // direction to move it in & the amount in pixels
    if(this.options.escCancels && e.keyCode == Event.KEY_ESC) // ARJ: check for escape key to do a cancel
    {
      this.doCancel() ;
    }
    else                // ARJ: some other key
    {
      // Does it look like the event even occured for the cropper divs or is the
      // user editing some other form widget and hitting arrow keys? This is difficult
      // to determine for Javascripts KeyPress events, but we might be able to get a good guess.
      // Otherwise, hitter arrow keys within text input widgets while the cropper is activated
      // will more the cropper AND move the cursor within the text input widget.
      // Note: the place I've put this means that "Esc" will be applied no matter where on the
      // page you are.
      // We will try carefull to get the active element (yay, IE vs FF vs wth Safari)
      var withinFormElement = Event.findElement(e, "input,textarea,label,fieldset,select,optgroup,option,button,isindex") ;
      if(!withinFormElement) // then probably should be paying attention to keydown (either within cropper div or on a non-form element elsewhere)
      {
        if( !this.dragging )
        {
          // catch the arrow keys
          switch( e.keyCode ) {
            case( Event.KEY_LEFT ) : // left
              dir.x = -1;
              break;
            case( Event.KEY_UP ) : // up
              dir.y = -1;
              break;
            case( Event.KEY_RIGHT ) : // right
              dir.x = 1;
              break;
            case( Event.KEY_DOWN ) : // down
              dir.y = 1;
              break;
          }

          if( dir.x !== 0 || dir.y !== 0 ) {
            // if shift is pressed then move by 10 pixels
            if( e.shiftKey ) {
              dir.x *= 10;
              dir.y *= 10;
            }

            this.moveArea( [ this.areaCoords.x1 + dir.x, this.areaCoords.y1 + dir.y ] );
            this.endCrop(e);
            Event.stop( e );
          }
        }
      }
    }
    // ARJ: done handling key event:
    this.doingKeyPress = false ;
  },

  /**
   * Calculates the width from the areaCoords
   *
   * @access private
   * @return int
   */
  calcW: function() {
    return (this.areaCoords.x2 - this.areaCoords.x1);
  },

  /**
   * Calculates the height from the areaCoords
   *
   * @access private
   * @return int
   */
  calcH: function() {
    return (this.areaCoords.y2 - this.areaCoords.y1);
  },

  /**
   * Moves the select area to the supplied point (assumes the point is x1 & y1 of the select area)
   *
   * @access public
   * @param array Point for x1 & y1 to move select area to
   * @return void
   */
  moveArea: function( point ) {
    // dump( 'moveArea        : ' + point[0] + ',' + point[1] + ',' + ( point[0] + ( this.areaCoords.x2 - this.areaCoords.x1 ) ) + ',' + ( point[1] + ( this.areaCoords.y2 - this.areaCoords.y1 ) ) + '\n' );
    this.setAreaCoords(
    {
      x1: point[0],
      y1: point[1],
      x2: point[0] + this.calcW(),
      y2: point[1] + this.calcH()
    },
    true,
    false
    );
    this.drawArea();
  },

  /**
   * Clones a co-ordinates object, stops problems with handling them by reference
   *
   * @access private
   * @param obj Coordinate object x1, y1, x2, y2
   * @return obj Coordinate object x1, y1, x2, y2
   */
  cloneCoords: function( coords ) {
    return { x1: coords.x1, y1: coords.y1, x2: coords.x2, y2: coords.y2 };
  },

  /**
   * Sets the select coords to those provided but ensures they don't go
   * outside the bounding box
   *
   * @access private
   * @param obj Coordinates x1, y1, x2, y2
   * @param boolean Whether this is a move
   * @param boolean Whether to apply squaring
   * @param obj Direction of mouse along both axis x, y ( -1 = negative, 1 = positive ) only required when moving etc.
   * @param string The current resize handle || null
   * @return void
   */
  setAreaCoords: function( coords, moving, square, direction, resizeHandle ) {
    // dump( 'setAreaCoords (in) : ' + coords.x1 + ',' + coords.y1 + ',' + coords.x2 + ',' + coords.y2 );
    if( moving )
    {
      this.moving = true ;
      // if moving
      var targW = coords.x2 - coords.x1,
          targH = coords.y2 - coords.y1;

      // ensure we're within the bounds
      // ARJ: check that crop selection within the minX bounds and apply constraint if not.
      if(coords.x1 < this.options.minX)
      {
        coords.x1 = this.options.minX ;
        coords.x2 = this.options.minX + targW ;
      }
      if( coords.x1 < 0 )
      {
        coords.x1 = 0 ;
        coords.x2 = targW ;
      }
      // ARJ: check that crop selection within the minY bounds and apply constraint if not.
      if(coords.y1 < this.options.minY)
      {
        coords.y1 = this.options.minY ;
        coords.y2 = this.options.minY + targH ;
      }
      if(coords.y1 < 0)
      {
        coords.y1 = 0 ;
        coords.y2 = targH ;
      }
      // ARJ: check that crop selection within the maxX bounds and apply constraint if not.
      if(this.options.maxX && coords.x2 > this.options.maxX)
      {
        coords.x2 = this.options.maxX ;
        coords.x1 = coords.x2 - targW ;
      }
      if(coords.x2 > this.imgW)
      {
        coords.x2 = this.imgW;
        coords.x1 = this.imgW - targW;
      }
      // ARJ: check that crop selection within the maxY bounds and apply constraint if not.
      if(this.options.maxY > -1 && coords.y2 > this.options.maxY)
      {
        coords.y2 = this.options.maxY ;
        coords.y1 = coords.y2 - targH ;
      }
      if(coords.y2 > this.imgH)
      {
        coords.y2 = this.imgH;
        coords.y1 = this.imgH - targH;
      }
    }
    else
    {
      // ensure we're within the bounds
      // ARJ: As above, first check crop selection is within any min/max bounds, apply constraint if not, then sanity checks:
      if(coords.x1 < this.options.minX) { coords.x1 = this.options.minX ; }
      if( coords.x1 < 0 ) { coords.x1 = 0; }
      if(coords.y1 < this.options.minY) { coords.y1 = this.options.minY ; }
      if( coords.y1 < 0 ) { coords.y1 = 0; }
      if(this.options.maxX > -1 && coords.x2 > this.options.maxX) { coords.x2 = this.options.maxX ; }
      if( coords.x2 > this.imgW ) { coords.x2 = this.imgW ; }
      if(this.options.maxY > -1 && coords.y2 > this.options.maxY) { coords.y2 = this.options.maxY ; }
      if( coords.y2 > this.imgH ) { coords.y2 = this.imgH; }

      // This is passed as null in onload
      if( direction !== null ) {

        // apply the ratio or squaring where appropriate
        if( this.ratioX > 0 ) {
          this.applyRatio( coords, { x: this.ratioX, y: this.ratioY }, direction, resizeHandle );
        } else if( square ) {
          this.applyRatio( coords, { x: 1, y: 1 }, direction, resizeHandle );
        }

        var mins = [ this.options.minWidth, this.options.minHeight ], // minimum dimensions [x,y]
            maxs = [ this.options.maxWidth, this.options.maxHeight ]; // maximum dimensions [x,y]

        // apply dimensions where appropriate
        if( mins[0] > 0 || mins[1] > 0 || maxs[0] > 0 || maxs[1] > 0) {

          var coordsTransX = { a1: coords.x1, a2: coords.x2 },
              coordsTransY = { a1: coords.y1, a2: coords.y2 },
              boundsX      = { min: 0, max: this.imgW },
              boundsY      = { min: 0, max: this.imgH };

          // handle squaring properly on single axis minimum dimensions
          if( (mins[0] !== 0 || mins[1] !== 0) && square ) {
            if( mins[0] > 0 ) {
              mins[1] = mins[0];
            } else if( mins[1] > 0 ) {
              mins[0] = mins[1];
            }
          }

          if( (maxs[0] !== 0 || maxs[0] !== 0) && square ) {
            // if we have a max x value & it is less than the max y value then we set the y max to the max x (so we don't go over the minimum maximum of one of the axes - if that makes sense)
            if( maxs[0] > 0 && maxs[0] <= maxs[1] ) {
              maxs[1] = maxs[0];
            } else if( maxs[1] > 0 && maxs[1] <= maxs[0] ) {
              maxs[0] = maxs[1];
            }
          }

          if( mins[0] > 0 ) { this.applyDimRestriction( coordsTransX, mins[0], direction.x, boundsX, 'min' ); }
          if( mins[1] > 1 ) { this.applyDimRestriction( coordsTransY, mins[1], direction.y, boundsY, 'min' ); }
          if( maxs[0] > 0 ) { this.applyDimRestriction( coordsTransX, maxs[0], direction.x, boundsX, 'max' ); }
          if( maxs[1] > 1 ) { this.applyDimRestriction( coordsTransY, maxs[1], direction.y, boundsY, 'max' ); }

          coords = { x1: coordsTransX.a1, y1: coordsTransY.a1, x2: coordsTransX.a2, y2: coordsTransY.a2 };
        }
      }
    }

    // dump( 'setAreaCoords (out) : ' + coords.x1 + ',' + coords.y1 + ',' + coords.x2 + ',' + coords.y2 + '\n' );
    this.areaCoords = coords;
  },

  /**
  * Applies the supplied dimension restriction to the supplied coordinates along a single axis
   *
   * @access private
   * @param obj Single axis coordinates, a1, a2 (e.g. for the x axis a1 = x1 & a2 = x2)
   * @param int The restriction value
   * @param int The direction ( -1 = negative, 1 = positive )
   * @param obj The bounds of the image ( for this axis )
   * @param string The dimension restriction type ( 'min' | 'max' )
   * @return void
   */
  applyDimRestriction: function( coords, val, direction, bounds, type ) {
    var check;
    if( type == 'min' ) { check = ( ( coords.a2 - coords.a1 ) < val ); }
    else { check = ( ( coords.a2 - coords.a1 ) > val ); }
    if( check ) {
      if( direction == 1 ) { coords.a2 = coords.a1 + val; }
      else { coords.a1 = coords.a2 - val; }

      // make sure we're still in the bounds (not too pretty for the user, but needed)
      if( coords.a1 < bounds.min ) {
        coords.a1 = bounds.min;
        coords.a2 = val;
      } else if( coords.a2 > bounds.max ) {
        coords.a1 = bounds.max - val;
        coords.a2 = bounds.max;
      }
    }
  },

  /**
   * Applies the supplied ratio to the supplied coordinates
   *
   * @access private
   * @param obj Coordinates, x1, y1, x2, y2
   * @param obj Ratio, x, y
   * @param obj Direction of mouse, x & y : -1 == negative 1 == positive
   * @param string The current resize handle || null
   * @return void
   */
  applyRatio : function( coords, ratio, direction, resizeHandle ) {
    // dump( 'direction.y : ' + direction.y + '\n');
    var newCoords;
    if( resizeHandle == 'N' || resizeHandle == 'S' ) {
      // dump( 'north south \n');
      // if moving on either the lone north & south handles apply the ratio on the y axis
      // ARJ: this should still apply for both "square" and "full" type handles
      newCoords = this.applyRatioToAxis(
        { a1: coords.y1, b1: coords.x1, a2: coords.y2, b2: coords.x2 },
        { a: ratio.y, b: ratio.x },
        { a: direction.y, b: direction.x },
        { min: 0, max: this.imgW }
      );
      coords.x1 = newCoords.b1;
      coords.y1 = newCoords.a1;
      coords.x2 = newCoords.b2;
      coords.y2 = newCoords.a2;
    } else {
      // otherwise deal with it as if we're applying the ratio on the x axis
      newCoords = this.applyRatioToAxis(
        { a1: coords.x1, b1: coords.y1, a2: coords.x2, b2: coords.y2 },
        { a: ratio.x, b: ratio.y },
        { a: direction.x, b: direction.y },
        { min: 0, max: this.imgH }
      );
      coords.x1 = newCoords.a1;
      coords.y1 = newCoords.b1;
      coords.x2 = newCoords.a2;
      coords.y2 = newCoords.b2;
    }

  },

  /**
   * Applies the provided ratio to the provided coordinates based on provided direction & bounds,
   * use to encapsulate functionality to make it easy to apply to either axis. This is probably
   * quite hard to visualise so see the x axis example within applyRatio()
   *
   * Example in parameter details & comments is for requesting applying ratio to x axis.
   *
   * @access private
   * @param obj Coords object (a1, b1, a2, b2) where a = x & b = y in example
   * @param obj Ratio object (a, b) where a = x & b = y in example
   * @param obj Direction object (a, b) where a = x & b = y in example
   * @param obj Bounds (min, max)
   * @return obj Coords object (a1, b1, a2, b2) where a = x & b = y in example
   */
  applyRatioToAxis: function( coords, ratio, direction, bounds ) {
    var newCoords = Object.extend( coords, {} ),
        calcDimA = newCoords.a2 - newCoords.a1, // calculate dimension a (e.g. width)
        targDimB = Math.floor( calcDimA * ratio.b / ratio.a ), // the target dimension b (e.g. height)
        targB = null, // to hold target b (e.g. y value)
        targDimA = null, // to hold target dimension a (e.g. width)
        calcDimB = null; // to hold calculated dimension b (e.g. height)

    // dump( 'newCoords[0]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');

    if( direction.b == 1 ) { // if travelling in a positive direction
      // make sure we're not going out of bounds
      targB = newCoords.b1 + targDimB;
      if( targB > bounds.max ) {
        targB = bounds.max;
        calcDimB = targB - newCoords.b1; // calcuate dimension b (e.g. height)
      }

      newCoords.b2 = targB;
    } else { // if travelling in a negative direction
      // make sure we're not going out of bounds
      targB = newCoords.b2 - targDimB;
      if( targB < bounds.min ) {
        targB = bounds.min;
        calcDimB = targB + newCoords.b2; // calcuate dimension b (e.g. height)
      }
      newCoords.b1 = targB;
    }

    // dump( 'newCoords[1]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');

    // apply the calculated dimensions
    if( calcDimB !== null ) {
      targDimA = Math.floor( calcDimB * ratio.a / ratio.b );

      if( direction.a == 1 ) { newCoords.a2 = newCoords.a1 + targDimA; }
      else { newCoords.a1 = newCoords.a1 = newCoords.a2 - targDimA; }
    }

    // dump( 'newCoords[2]: ' + newCoords.a1 + ',' + newCoords.b1 + ','+ newCoords.a2 + ',' + newCoords.b2 + '\n');

    return newCoords;
  },

  /**
   * Draws the select area
   *
   * @access private
   * @return void
   */
  drawArea: function( ) {
    /*
      NOTE: I'm not using the Element.setStyle() shortcut as they make it
      quite sluggish on Mac based browsers
    */
    // dump( 'drawArea        : ' + this.areaCoords.x1 + ',' + this.areaCoords.y1 + ',' + this.areaCoords.x2 + ',' + this.areaCoords.y2 + '\n' );
    var areaWidth     = this.calcW(),
        areaHeight    = this.calcH();

    /*
      Calculate all the style strings before we use them, allows reuse & produces quicker
      rendering (especially noticable in Mac based browsers)
    */
    var px = 'px',
      params = [
        this.areaCoords.x1 + px, // the left of the selArea
        this.areaCoords.y1 + px, // the top of the selArea
        areaWidth + px,          // width of the selArea
        areaHeight + px,         // height of the selArea
        this.areaCoords.x2 + px, // bottom of the selArea
        this.areaCoords.y2 + px, // right of the selArea
        (this.img.width - this.areaCoords.x2) + px, // right edge of selArea
        (this.img.height - this.areaCoords.y2) + px // bottom edge of selArea
    ];

    // do the select area
    var areaStyle    = this.selArea.style;
    areaStyle.left   = params[0];
    areaStyle.top    = params[1];
    areaStyle.width  = params[2];
    areaStyle.height = params[3];
    // ARJ: also must resize selArea's clickArea div. Failure to do this means cropper breaks in IE
    //      when the image is within a table (or tables within tables). This is due to a long-standing set of
    //      bugs related to applying filters to page elements in IE (e.g. to add an opacity filter).
    this.selAreaClickArea.style.width = params[2] ;
    this.selAreaClickArea.style.height = params[3] ;

    // position the north, east, south & west handles
    // ARJ: This depends on the type of handles we using
    var horizHandlePos, vertHandlePos ;
    if(this.options.handleType == 'full')
    {
      var thickness = ((this.options.handleConfig && this.options.handleConfig.size) ? this.options.handleConfig.size : 4) ;
      var halfThickOffset = (Math.round(thickness / 2)) ;
      var horizHandleSize = (areaWidth - thickness - halfThickOffset) ;
      (horizHandleSize > 1) || (horizHandleSize = 1) ;
      var vertHandleSize = (areaHeight - thickness - halfThickOffset) ;
      (vertHandleSize > 1) || (vertHandleSize = 1) ;
      // N
      this.handleN.style.top = (-1 * halfThickOffset) + px ;
      this.handleN.style.left = halfThickOffset + px ;
      this.handleN.style.width = horizHandleSize + px ;
      // S
      this.handleS.style.bottom = (-1 * halfThickOffset) + px ;
      this.handleS.style.left = halfThickOffset + px ;
      this.handleS.style.width = horizHandleSize + px ;
      // E
      this.handleE.style.right = (-1 * halfThickOffset) + px ;
      this.handleE.style.top = halfThickOffset + px ;
      this.handleE.style.height = vertHandleSize + px ;
      // W
      this.handleW.style.left = (-1 * halfThickOffset) + px ;
      this.handleW.style.top = halfThickOffset + px ;
      this.handleW.style.height = vertHandleSize + px ;
    }
    else // 'square'
    {
      // ARJ: changed from being hard-coded (even static CSS file hard-coded)
      // to being config- (with appropriate defaults) and computation-based.
      var size = ((this.options.handleConfig && this.options.handleConfig.size) ? this.options.handleConfig.size : 6) ;
      var halfSizeOffset = (-1 * Math.round(size / 2)) + px ;
      var horizHandlePos = Math.ceil( (areaWidth - size) / 2 ) ;
      (horizHandlePos > 1) || (horizHandlePos = 1) ;
      var vertHandlePos = Math.ceil( (areaHeight - size) / 2 ) ;
      (vertHandlePos > 1) || (vertHandlePos = 1) ;
      // N
      this.handleN.style.top  = halfSizeOffset ;
      this.handleN.style.left = horizHandlePos + px ;
      // E
      this.handleE.style.top  = vertHandlePos + px ;
      this.handleE.style.right  = halfSizeOffset ;
      // S
      this.handleS.style.bottom = halfSizeOffset ;
      this.handleS.style.left = horizHandlePos + px ;
      // W
      this.handleW.style.top  = vertHandlePos + px ;
      this.handleW.style.left = halfSizeOffset ;
      // NE
      this.handleNE.style.top = halfSizeOffset ;
      this.handleNE.style.right = halfSizeOffset ;
      // SE
      this.handleSE.style.bottom = halfSizeOffset ;
      this.handleSE.style.right = halfSizeOffset ;
      // SW
      this.handleSW.style.bottom = halfSizeOffset ;
      this.handleSW.style.left = halfSizeOffset ;
      // NW
      this.handleNW.style.top = halfSizeOffset ;
      this.handleNW.style.left = halfSizeOffset ;
    }

    // draw the four overlays
    this.north.style.height = params[1] ;

    var eastStyle     = this.east.style;
    eastStyle.top     = params[1];
    eastStyle.height  = params[3];
    eastStyle.left    = params[4];
    eastStyle.width   = params[6];

    var southStyle    = this.south.style;
    southStyle.top    = params[5];
    southStyle.height = params[7];

    var westStyle     = this.west.style;
    westStyle.top     = params[1];
    westStyle.height  = params[3];
    westStyle.width   = params[0];

    // ARJ: if any overlay has a 0-width or 0-height, then it's not being displayed (obviously)
    //      so that means we must ensure any text within the overlay is hidden or the browser will
    //      display it anyway, on top of adjacent elements (since its container has a 0-size axis)
    this.overlays.each( function(ovr)
    {
      if(ovr.style.height == 0 || ovr.style.width == 0)
      {
        ovr.down().hide() ;
      }
      else // ensure not hidden from previous resizing/dragging
      {
        ovr.down().show() ;
      }
    });

    // call the draw method on sub classes
    this.subDrawArea();

    this.forceReRender();
  },

  /**
   * Force the re-rendering of the selArea element which fixes rendering issues in Safari
   * & IE PC, especially evident when re-sizing perfectly vertical using any of the south handles
   *
   * @access private
   * @return void
   */
  forceReRender: function() {
    if( this.isIE || this.isWebKit) {
      var n = document.createTextNode(' ');
      var d,el,fixEL,i;

      if( this.isIE ) { fixEl = this.selArea; }
      else if( this.isWebKit )
      {
        // ARJ: We no longer get this by class name. The getElementsByClassName() has been removed
        // from Prototype because mainstream browsers (FF & IE) have turned this into a native call in their
        // most recent versions. Thus, the call was failing anyway. We could have replaced it with a call to Element.select()
        // but really, there's no need, why not just have ids and get them by id. More efficient and shorter code here anyway.
        fixEl = $(this.img.id + '_imgCrop_marqueeSouth') ;
        /*
          we have to be a bit more forceful for Safari, otherwise the the marquee &
          the south handles still don't move
        */
        d = new Element( 'div' );
        d.style.visibility = 'hidden';

        var classList = ['SE','S','SW'];
        for( i = 0; i < classList.length; i++ )
        {
          // ARJ: Updated to work with square vs full style handles
          el = $(this.selArea).select('.imgCrop_handle_' + this.options.handleType + "_" + classList[i])[0] ;
          if(el) // SE and SW won't be found for full, since they aren't used. Skip those.
          {
            if( el.childNodes.length ) { el.removeChild( el.childNodes[0] ); }
            el.appendChild(d);
          }
        }
      }
      fixEl.appendChild(n);
      fixEl.removeChild(n);
    }
  },

  makeCustomMarqueeBackgroundStyles: function()
  {
    var marqueeConfig = this.options.marqueeConfig ;
    // By default, no custom marque background image. Will use what is in the CSS file and not override with custom background image.
    var backgroundStyles = {
        vert : "",
        horz : "",
        width : "",
        height : ""
    } ;
    // If there are custom settings, get what ones there are to be had.
    if(marqueeConfig)
    {
      if(marqueeConfig.vertMarqueeGif)
      {
        backgroundStyles.vert = "background: transparent url(" + marqueeConfig.vertMarqueeGif + ") repeat-x 0 0 ;" ;
      }
      if(marqueeConfig.horizMarqueeGif)
      {
        backgroundStyles.horz = "background: transparent url(" + marqueeConfig.horizMarqueeGif + ") repeat-x 0 0 ;" ;
      }
      if(marqueeConfig.vertMarqueeWidth)
      {
        backgroundStyles.width = "width: " + marqueeConfig.vertMarqueeWidth + " ; " ;
      }
      if(marqueeConfig.vertMarqueeGif)
      {
        backgroundStyles.height = "height: " + marqueeConfig.horizMarqueeHeight + " ; " ;
      }
    }
    return backgroundStyles ;
  },

  makeHandleElem: function(hndl, cNamePrefix)
  {
    var hndlConf = this.options.handleConfig ;
    var style = "" ;
    // Apply custom style config (if any)
    if(hndlConf)
    {
      // Common and/or simple settings:
      // - border & background:
      style +=
      (
        "border : " + ((hndlConf.border) ? hndlConf.border : "1px solid #333") + " ; " +
        "background : " + ((hndlConf.background) ? hndlConf.background : "#FFF") + " ; "
      ) ;
      // - custom opacity:
      if(hndlConf.opacity)
      {
        var opac= hndlConf.opacity ;
        var ieOpac = Math.round(100.0 * opac) ;
        style += "opacity : " + opac + " ; filter : alpha(opacity=" + ieOpac + ") ; " ;
      }
      // Settings specific to the handle style:
      if(this.options.handleType == "full")
      {
        var hndlSize = ((hndlConf.size) ? hndlConf.size : 4) ;
        if(Prototype.Browser.IE)
        {
          hndlSize += (2 * this.handleBorderWidth) ;
        }

        // dims depend on which handle we're doing
        if(['n', 's'].indexOf(hndl) >= 0)
        {
          style +=
          (
            "width : 100% ;" +
            "height : " + hndlSize + "px ; "
          ) ;
        }
        else if(['e', 'w'].indexOf(hndl) >= 0)
        {
          style +=
          (
            "height : 100% ;" +
            "width : " + hndlSize + "px ; "
          ) ;
        }
      }
      else // "square"
      {
        var hndlSize = ((hndlConf.size) ? hndlConf.size : 6) ;
        if(Prototype.Browser.IE)
        {
          hndlSize += (2 * this.handleBorderWidth) ;
        }
        style +=
        (
          "width  : " + hndlSize + "px ; " +
          "height : " + hndlSize + "px ; "
        ) ;
      }
    }
    // Create actual handle element
    var handleElem = (new Element(
      'div',
      {
        'class': cNamePrefix + 'handle ' + cNamePrefix + 'handle_' + this.options.handleType + ' ' + cNamePrefix + 'handle_' + this.options.handleType + '_' + hndl.toUpperCase(),
        'style': style
      }
    )) ;
    return handleElem ;
  },
  /**
   * Starts the resize
   *
   * @access private
   * @param obj Event
   * @return void
   */
  startResize: function( e ) {
    this.startCoords = this.cloneCoords( this.areaCoords );

    this.resizing = true;
    this.resizeHandle = Event.element( e ).classNames().toString().replace(/([^N|NE|E|SE|S|SW|W|NW])+/, '');
    // dump( 'this.resizeHandle : ' + this.resizeHandle + '\n' );
    Event.stop( e );
  },

  /**
   * Starts the drag
   *
   * @access private
   * @param obj Event
   * @return void
   */
  startDrag: function( e ) {
    this.clickCoords = this.getCurPos( e ) ;

    // ARJ: If the click is on an overlay and dev enabled such clicks to cancel, then do so:
    if(this.options.overlayCancels && this.isWithinOverlay(e))
    {
      this.doCancel() ;
    }
    else if(this.isWithinElement(e, this.img))  // Must be within image at least. Mousedown events outside the image are not relevant (and cause bugs in IE)
    {
      this.selArea.show() ;
      this.setAreaCoords( { x1: this.clickCoords.x, y1: this.clickCoords.y, x2: this.clickCoords.x, y2: this.clickCoords.y }, false, false, null );
      this.dragging = true;
      this.onDrag( e ); // incase the user just clicks once after already making a selection
    }
    // Regardless, stop the event bubbling.
    Event.stop( e ) ;
  },

  /**
   * ARJ: New function: Activates the crop selection drag. Implements the ability to
   *      only initiate the crop selection if the click is within a specific bounding box in the image.
   *
   * @param obj Event
   * @return void
   */
  activateDrag: function( e )
  {
    // Translate the mouse click raw position to a position within the image
    this.clickCoords = this.getCurPos( e ) ;

    // Check if the coordinates are within the activationRegion bounding box.
    if( !(  (this.clickCoords.x < this.options.activationRegion.x1) || (this.clickCoords.x > this.options.activationRegion.x2) ||
            (this.clickCoords.y < this.options.activationRegion.y1) || (this.clickCoords.y > this.options.activationRegion.y2)) )
    {
      this.dragArea.show() ;
      this.active = true ;
      this.startDrag( e ); // incase the user just clicks once after already making a selection
      Event.stop( e );
    }
  },

  /**
   * ARJ: New function: check if an event occurred within one of the overlays.
   *
   * @param obj Event
   * @return boolean
   */
  isWithinOverlay: function(evt)
  {
    var withinOverlay = false ;
    // Get raw event coords (these are absolute coords within the document, regardless of scrolling of page/containers)
    var coords = { x: Event.pointerX(evt), y: Event.pointerY(evt) } ;

    for(var ii=0; ii < this.overlays.length; ii++)
    {
      var overlay = this.overlays[ii] ;
      if(overlay.visible()) // Overlay must be visible for an event to be within it
      {
        var withinOverlay = this.isWithinElement(evt, overlay) ;
        if(withinOverlay)
        {
          break ;
        }
      }
    }
    return withinOverlay ;
  },

  /**
   * ARJ: New function: check if an evt occurred within a given element. Used to test if
   * clicks are within one of the overlays. Also needed to help fix an IE bug where clicks anywhere
   * in the document (due to document-wide mouseup observer) will be processed as resize events
   * even if the click was not within the image. That really sucks for pages where the cropper is
   * but one component; I'm not clear why this is not a problem for other browsers--they should
   * have it too given that the mouseup observer here was registered for the "document" rather than
   * a specific cropper div.
   *
   * Will apply the release fuzziness.
   *
   * NOTE: This used to be provided by Prototype's Position class (method "within"); but they've helpfully deprecated that
   * and did NOT provide a replacement. Great work there.
   *
   * @param obj Event
   * @param testElem DOM Element or Element ID to test if Event is within
   * @returns boolean
   */
  isWithinElement: function(evt, testElem)
  {
    var withinElem = false ;
    // Get raw event coords (these are absolute coords within the document, regardless of scrolling of page/containers)
    var coords = { x: Event.pointerX(evt), y: Event.pointerY(evt) } ;
    // Get helpful version of elem from Prototype
    var elem = $(testElem) ;
    // ARJ: get the element's offset and dimensions in the doc (absolute, within the doc, regardless of scrolling)
    var offset = elem.cumulativeOffset() ;
    var dims = elem.getDimensions() ;
    // Get the elements's position on the screen
    var elemCoords =
    {
      x1: offset.left, x2: (offset.left + dims.width),
      y1: offset.top,  y2: (offset.top + dims.height)
    } ;
    // ARJ: adjust element coords for offset by fuzziness if a mouse up event:
    if(evt.type == "mouseup")
    {
      elemCoords.y1 = ( (elemCoords.y1 - this.options.mouseupFuzziness.top) < 0 ? 0 : (elemCoords.y1 - this.options.mouseupFuzziness.top) ) ;
      elemCoords.x1 = ( (elemCoords.x1 - this.options.mouseupFuzziness.left) < 0 ? 0 : (elemCoords.x1 - this.options.mouseupFuzziness.left) ) ;
      elemCoords.y2 = (elemCoords.y2 + this.options.mouseupFuzziness.bottom) ;
      elemCoords.x2 = (elemCoords.x2 + this.options.mouseupFuzziness.right) ;
    }
    // Test if point is with the element's position on the screen
    if( coords.x >= elemCoords.x1 && coords.x <= elemCoords.x2 &&
        coords.y >= elemCoords.y1 && coords.y <= elemCoords.y2)
    {
      withinElem = true ;
    }
    return withinElem ;
  },

  /**
   * Gets the current cursor position relative to the image
   *
   * @access private
   * @param obj Event
   * @return obj x,y pixels of the cursor
   */
  getCurPos: function( e ) {
    // get the offsets for the wrapper within the document
    // get the offsets for the wrapper within the document
    var el = this.imgWrap, wrapOffsets = Element.cumulativeOffset( el );
    // remove any scrolling that is applied to the wrapper (this may be buggy) - don't count the scroll on the body as that won't affect us
    while( el.nodeName != 'BODY' ) {
      wrapOffsets[1] -= el.scrollTop  || 0;
      wrapOffsets[0] -= el.scrollLeft || 0;
      el = el.parentNode;
    }
    return {
      x: Event.pointerX(e) - wrapOffsets[0],
      y: Event.pointerY(e) - wrapOffsets[1]
    };
  },

  /**
   * Performs the drag for both   resize & inital draw dragging
   *
   * @access private
   * @param obj Event
   * @return void
   */
  onDrag: function( e, a, b, c ) {
    if( this.dragging || this.resizing ) {

      var resizeHandle = null,
          curPos = this.getCurPos( e ),
          newCoords = this.cloneCoords( this.areaCoords ),
          direction = { x: 1, y: 1 };

      if( this.dragging ) {
        if( curPos.x < this.clickCoords.x ) { direction.x = -1; }
        if( curPos.y < this.clickCoords.y ) { direction.y = -1; }

        this.transformCoords( curPos.x, this.clickCoords.x, newCoords, 'x' );
        this.transformCoords( curPos.y, this.clickCoords.y, newCoords, 'y' );
      } else if( this.resizing ) {
        resizeHandle = this.resizeHandle;
        // do x movements first
        if( resizeHandle.match(/E/) ) {
          // if we're moving an east handle
          this.transformCoords( curPos.x, this.startCoords.x1, newCoords, 'x' );
          if( curPos.x < this.startCoords.x1 ) { direction.x = -1; }
        } else if( resizeHandle.match(/W/) ) {
          // if we're moving an west handle
          this.transformCoords( curPos.x, this.startCoords.x2, newCoords, 'x' );
          if( curPos.x < this.startCoords.x2 ) { direction.x = -1; }
        }

        // do y movements second
        if( resizeHandle.match(/N/) ) {
          // if we're moving an north handle
          this.transformCoords( curPos.y, this.startCoords.y2, newCoords, 'y' );
          if( curPos.y < this.startCoords.y2 ) { direction.y = -1; }
        } else if( resizeHandle.match(/S/) ) {
          // if we're moving an south handle
          this.transformCoords( curPos.y, this.startCoords.y1, newCoords, 'y' );
          if( curPos.y < this.startCoords.y1 ) { direction.y = -1; }
        }

      }

      this.setAreaCoords( newCoords, false, e.shiftKey, direction, resizeHandle );
      this.drawArea();
      Event.stop( e ); // stop the default event (selecting images & text) in Safari & IE PC
    }
  },

  /**
   * Applies the appropriate transform to supplied co-ordinates, on the
   * defined axis, depending on the relationship of the supplied values
   *
   * @access private
   * @param int Current value of pointer
   * @param int Base value to compare current pointer val to
   * @param obj Coordinates to apply transformation on x1, x2, y1, y2
   * @param string Axis to apply transformation on 'x' || 'y'
   * @return void
   */
  transformCoords : function( curVal, baseVal, coords, axis ) {
    var newVals = [ curVal, baseVal ];
    if( curVal > baseVal ) { newVals.reverse(); }
    coords[ axis + '1' ] = newVals[0];
    coords[ axis + '2' ] = newVals[1];
  },

  /**
   * Ends the crop & passes the values of the select area on to the appropriate
   * callback function on completion of a crop.
   *
   * ARJ: because this becomes a handler for a document-wide mouseup event,
   * *regardless* of whether some dragging or resizing or activating is being
   * done, clicks outside the image (say within text inputs on forms to edit
   * their contents or clicks on text to copy it) end up being handled by this.
   * But they should not be handled by this if:
   * - the cropper is not active
   * - the click is outside the image area
   * Otherwise, the user's onEndCrop will be called to inappropriately perform
   * updates (or whatever) on the page when really no crop-related work was done.
   *
   * @access private
   * @param evt Event
   * @return void
   */
  endCrop : function(evt)
  {
    // ARJ: The cropper must be active and the click must be within the image
    // for use to actually claim an "endCrop" event occured.
    // NOTE: evt will be null when endCrop called programmatically, say through cropperObj.reset().
    this.dragging = this.resizing = this.moving = false ;
    if(evt && this.active && (this.moving || this.resizing || this.doingKeyPress || this.isWithinElement(evt, this.img)))
    {
      // Looks like responding to a click.
      // Call dev's registered onEndCrop event handler (or empty function if they didn't register one)
      this.options.onEndCrop(
        this.areaCoords,
        {
          width: this.calcW(),
          height: this.calcH()
        }
      ) ;
    }
  },

  /**
   * Abstract method called on the end of initialization
   *
   * @access private
   * @abstract
   * @return void
   */
  subInitialize: function() {},

  /**
   * Abstract method called on the end of drawArea()
   *
   * @access private
   * @abstract
   * @return void
   */
  subDrawArea: function() {}
});

/**
 *  Extend the Cropper.Img class to allow for presentation of a preview image of the resulting crop,
 *  the option for displayOnInit is always overridden to true when displaying a preview image
 *
 *  Usage:
 *    @param obj Image element to attach to
 *    @param obj Optional options:
 *      - see Cropper.Img for base options
 *      - previewWrap obj HTML element that will be used as a container for the preview image
 */
Cropper.ImgWithPreview = Class.create(Cropper.Img, {

  /**
   * Implements the abstract method from Cropper.Img to initialize preview image settings.
   * Will only attach a preview image is the previewWrap element is defined and the minWidth
   * & minHeight options are set.
   *
   * @see Croper.Img.subInitialize
   */
  subInitialize: function() {
    /**
    * Whether or not we've attached a preview image
    * @var boolean
    */
    this.hasPreviewImg = false;
    if( typeof(this.options.previewWrap) != 'undefined' && this.options.minWidth > 0 && this.options.minHeight > 0 ) {
      /**
       * The preview image wrapper element
       * @var obj HTML element
       */
      this.previewWrap = $( this.options.previewWrap );
      /**
       * The preview image element
       * @var obj HTML IMG element
       */
      this.previewImg = this.img.cloneNode( false );
      // set the ID of the preview image to be unique
      this.previewImg.id = 'imgCrop_' + this.previewImg.id;

      // set the displayOnInit option to true so we display the select area at the same time as the thumbnail
      this.options.displayOnInit = true;

      this.hasPreviewImg = true;

      this.previewWrap.addClassName( 'imgCrop_previewWrap' );

      this.previewWrap.setStyle({
        width: this.options.minWidth + 'px',
        height: this.options.minHeight + 'px'
      });

      this.previewWrap.appendChild( this.previewImg );
    }
  },

  /**
   * Implements the abstract method from Cropper.Img to draw the preview image
   *
   * @see Croper.Img.subDrawArea
   */
  subDrawArea: function() {
    if( this.hasPreviewImg ) {
      // get the ratio of the select area to the src image
      var calcWidth = this.calcW(),
          calcHeight = this.calcH();
      // ratios for the dimensions of the preview image
      var dimRatio = {
        x: this.imgW / calcWidth,
        y: this.imgH / calcHeight
      };
      //ratios for the positions within the preview
      var posRatio = {
        x: calcWidth / this.options.minWidth,
        y: calcHeight / this.options.minHeight
      };

      // setting the positions in an obj before apply styles for rendering speed increase
      var calcPos = {
        w: Math.ceil( this.options.minWidth * dimRatio.x ) + 'px',
        h: Math.ceil( this.options.minHeight * dimRatio.y ) + 'px',
        x: '-' + Math.ceil( this.areaCoords.x1 / posRatio.x )  + 'px',
        y: '-' + Math.ceil( this.areaCoords.y1 / posRatio.y ) + 'px'
      };

      var previewStyle = this.previewImg.style;
      previewStyle.width = calcPos.w;
      previewStyle.height= calcPos.h;
      previewStyle.left = calcPos.x;
      previewStyle.top = calcPos.y;
    }
  }

});
