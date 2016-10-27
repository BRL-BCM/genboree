/**
 * This file contains all of the help messages for the tabular layout tool, as
 * well as a method for popping up a draggable, closable, single instance
 * dialog box.  This dialog box will be automatically moved to the location of
 * the button click and filled in with the new help text, everytime that the
 * method is called.  Each help string is stored in an object that contains the
 * title for the dialog box, and the help string.  There is a global array of
 * these objects that can be referred to by any .jsp that includes this file.
 *
 * Dependencies:
 *   - ExtJS 2.2
 *     Since the popup dialog is an ExtJS dialog, that must be included by
 *     whatever file includes this .js file.
 * Author: Steven G. Davis (SGD), BNI
 * Modifying Author: Michael F Smith (MFS), BNI
 */

var helpMessages = {
  'allEpSpecs' : {
    'title' : 'Help: Specify Properties for All Entry Points',
    'text' : 'Any properties specified in this section will be applied to all entry points in the image. If you would like to ' +
             'change properties for an individual entry point, select it from <span class="widgetRef">Available Entry Points</span> ' +
             'and then change the desired property in <span class="widgetRef">Entry Point Details</span>.<ul><li>If an entry point break ' +
             'is added, the specified <span class="widgetRef">Axis break style</span> will be used to draw the break.</li></ul>'
  },
  'availEps' : {
    'title' : 'Help: Selecting Entry Points',
    'text' : 'Here you can specify which entry points should be drawn in ' +
    //'text' : 'Here you can specify which <a href="showHelp.jsp?topic=vgpConfig#selectingEPs" target="_helpWin">entry points</a> should be drawn in ' +
             'the created VGP images.<ul><li>If a database contains a small number of entry points, all entry points ' +
             ' will be listed. Check/uncheck the <span class="widgetRef">Draw</span> checkbox to add/remove a specific entry point.</li>' +
             '<li>If a database contains a large set of entry points, you will be required to add the desired ' +
             'entry points manually. Enter the name of the entry point into the text field and click the ' +
             '<span class="widgetRef">Add</span> button to draw the named entry point. To remove an entry point from drawing, select the ' +
             'entry point name from the list and click <span class="widgetRef">Remove</span>.</li></ul>'
  },
  'epSpecs' : {
    'title' : 'Help: Specify Properties for Individual Entry Points',
    'text' : 'Here you can specify proprties that will be applied to only a single entry point.<ul><li>To specify properties for an entry point ' +
             'first select the desired entry point from the <span class="widgetRef">Available Entry Points</span> list.</li>' +
             '<li><span class="widgetRef">Entry point scaling</span> can be added so that either a whole entry point or specific regions can be ' +
             'scaled (zoomed in or out). This can be useful for areas in an entry point that have either dense or sparse annotation.</li>' +
             '<li>Sections of an entry point can be hidden from the image by changing the <span class="widgetRef">Visibility</span> ' +
             'option. Any regions that are hidden from view will be drawn with the specified <span class="widgetRef">Axis break style</span></li></ul>'
  },
  'ideoSpecs' : {
    'title' : 'Help: Specify Ideogram Properties',
    'text' : 'Here you set properties that will adjust how the resulting ideogram and image are drawn. ' +
             '<ul><li>Change the <span class="widgetRef">Ideogram radius</span> to make the ideogram larger or smaller. Note that ' +
             'the size of the created image is dependant on the radius specified.</li><li>If you are drawing a microbial genome, check the ' +
             '<span class="widgetRef">Create a microbial ideogram</span> to make the resulting ideogram a closed circle.</li></ul>'
  },
  'tickSpecs' : {
    'title' : 'Help: Specify Tick Mark Properties',
    'text' : 'Tick marks convey spatial orientation in the ideogram and help viewers better understand the scope of your image. Here you can ' +
             'add, update and delete tick marks in your image.<ul><li>Groups of tick marks are created by defining the interval between each ' +
             'tick mark using the <span class="widgetRef">Tick mark spacing</span> input. Circos will draw a tick mark at every specified interval.</li>' +
             '<li>A tick mark group can be hidden from the image by unchecking the <span class="widgetRef">Show tick mark</span> option.</li>' + 
             '<li>A text label can be added to each tick mark group to display the position of the tick mark. The <span class="widgetRef">Show tick label</span> ' +
             'option controls the display of tick mark labels.</li><li>Grid lines can be extended from any tick mark group. Grid lines are drawn at the same ' +
             'specified interval as the tick marks and are drawn from the specified grid start to grid end and underneath any data tracks they overlap.</li></ul>' 
  },
  'ticksDef' : {
    'title' : 'Help: Currently Added Tick Marks',
    'text' : 'Tick mark groups that have been defined will appear in the list below.<ul><li>To view the options for a defined tick mark group, select it ' +
             'from the list below. The options above will display the current settings for the selected group.</li><li>If you are updating a tick group, ' +
             'be sure to press the <span class="widgetRef">Update Tick Mark</span> button to save your changes.</li></ul>'
  },
  'ruleSpecs' : {
    'title' : 'Help: Annotation Filtering Rules',
    'text' : 'Here you can add annotation filtering rules that will alter the drawing of you data track. Rules can be useful if you would like to limit the ' +
             'data set that is drawn or differentiate data points that have specific values.<ul><li>To add a rule, press the <span class="widgetRef">\' + \'' +
             '</span> button and specify the rule properties.</li><li>To remove a rule, simply press the <span class="widgetRef">\' - \'</span> button for ' +
             'the rule you wish to remove.</li><li>If you are adding or removing rules for a yet-to-be added track, the rules will be committed when the ' +
             '<span class="widgetRef">Add Track</span> button is pressed.</li><li>If you are adding or removing rules for an already added track, they ' +
             'rules will be committed when the <span class="widgetRef">Update Track</span> button is pressed.</li></ul>'
  },
  'trackSpecs' : {
    'title' : 'Help: Specify Track Properties',
    'text' : 'Here you can add and specify annotation tracks that you would like to appear in the image. Different track types have type-specific ' +
             'properties that can be specified, see the track type help for more information.<ul><li>The <span class="widgetRef">Inner radius</span> ' +
             'specifies the starting radial position for the annotation track.</li><li>The <span class="widgetRef">Outer radius</span> specifies the ' +
             'ending radial position for the annotation track.</li><li>Data for the annotation track will be drawn in between the inner and outer ' +
             'radii.</li><li>The specified radii must be greater than zero. A value greater than 1 indicates a radial position outside the circle.' +
             '</li><li>To add a track, select a track from the <span class="widgetRef">Available tracks</span> drop-down. Set the options for the ' +
             'track and press the <span class="widgetRef">Add Track</span> button. The track will be added and layered on top of all other tracks, ' +
             'by default.</li><li>To update a track, select it and change the settings. Press the <span class="widgetRef">Update Track</span> ' +
             'button to save those changes.</li></ul>'
  },
  'tracksDef' : {
    'title' : 'Help: List of Currently Added Annotation Tracks',
    'text' : 'Annotation tracks that have been added to the image will be displayed in the list below.<ul><li>To view the options for an added ' +
             'track, select it from the list below. The options above will display the current settings for the selected track.</li>' +
             '<li>To change the layering of a track, drag the track up or down the list. Tracks with a higher layer number will ' +
             'be drawn on top of tracks with a lower layer number.</li><li>'
  }
} ;

/**
 * Display a popup dialog with the specified title and help string.  The title
 * will default to "Help" if it was not passed to the function.
 * @param button
 *   The button that was pressed to generate this dialog (for position).
 * @param text
 *   The help text to display in the main body of the dialog.
 * @param title
 *   (optional) The title of the help dialog.  Defaults to "Help".
 */
function displayHelpPopup(button, text, title)
{
  if (!title) title = "Help" ;

  Ext.Msg.show(
  {
    title: title,
    msg : text,
    height: 120,
    width: 385,
    minHeight: 100,
    minWidth: 150,
    modal: false,
    proxyDrag: true
  }) ;
  Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;

  return false ;
}
