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
  'availEPs' : {
    'title' : 'Help: Selecting Entry Points',
    'text' : 'Here you can specify which <a href="showHelp.jsp?topic=vgpConfig#selectingEPs" target="_helpWin">entry points</a> should be drawn in ' +
             'the created VGP images.<ul><li>If a database contains a small number of entry points, all entry points ' +
             ' will be listed. Check/uncheck the <span class="widgetRef">Draw</span> checkbox to add/remove a specific entry point.</li>' +
             '<li>If a database contains a large set of entry points, you will be required to add the desired ' +
             'entry points manually. Enter the name of the entry point into the text field and click the ' +
             '<span class="widgetRef">Add</span> button to draw the named entry point. To remove an entry point from drawing, select the ' +
             'entry point name from the list and click <span class="widgetRef">Remove</span>.</li></ul>'
  },
  'epSegs' : {
    'title' : 'Help: Creating Entry Point Segments',
    'text' : 'Here you can specify partial <a href="showHelp.jsp?topic=vgpConfig#epSegments" target="_helpWin">segments</a> of entry points ' +
             'to be drawn. This can be useful if you want to focus in on a part of an entry point. Note that this section is optional, no options ' +
             'in this section need to be changed. If no segments are added, VGP will draw entry points as normal.<ul><li>To specify segments for an entry point, ' +
             'first select it by clicking on it in the <span class="widgetRef">Available Entry Points</span> list</li><li>If you define multiple segments from  ' +
             'the same entry point, each will be treated as individual entry points. Segments will be drawn in a separate Chromosome View and individualy in the ' +
             'Genome View</li><li>It is highly recommended that if any segments are specified that the <span class="widgetRef">Y-Axis scale</span>, ' +
             'on the <span class="widgetRef">Specify Images</span> tab, be set to <span class="widgetRef">Individual Scales for Each Entry Point</span></li></ul>'
  },
  'imageTypes' : {
    'title' : 'Help: Image Types',
    'text' : 'Here you can select which <a href="showHelp.jsp?topic=vgpConfig#specifyingImages" target="_helpWin">image types</a> to create, as well as ' +
             'specify settings for the image. Note that only one type of image can be created in a VGP run, either a ' + 
             '<a href="showHelp.jsp?topic=vgpConfig#genomeView" target="_helpWin">Genome View</a> or ' +
             '<a href="showHelp.jsp?topic=vgpConfig#chromView" target="_helpWin">Chromosome Views</a>.' +
             '<ul><li><span class="widgetRef">Draw chromosome labels</span> enables/disables text labels drawn at the top of ' +
             'the image to identify each chromosome in the Genome View</li><li><span class="widgetRef">Margin</span> controls the space between ' +
             'each chromose figure in the Genome View</li></ul>All required text options are marked with a \' * \'. ' +
             'If a text option is not required, it can be blank.'
  },
  'imgLabels' : {
    'title' : 'Help: Image Labels Settings',
    'text' : 'Here you can specify what <a href="showHelp.jsp?topic=vgpConfig#imgLabels" target="_helpWin">labels</a> should appear on your images.' +
             '<ul><li>Leading and trailing whitespace will be removed from any text input options, if specified. Multiple lines ' +
             'are supported.</li><li>A <span class="widgetRef">Track-based legend</span> shows the display name and key ' +
             'representing the drawing style for each annotation track in the image.</li><li>A ' +
             '<span class="widgetRef">Column-based legend</span> shows the column title and positions for each column in the image.' +
             '</li><li>If both legends are drawn in the same primary position, a secondary position is required.</li></ul>' +
             'All required text options are marked with a \' * \'. If a text option is not required, it can be blank.'
  },
  'colDefined' : {
    'title' : 'Help: Current Columns List',
    'text' : 'Use the interface below to define one or more columns in which VGP will draw annotation tracks. ' +
             '<a href="showHelp.jsp?topic=vgpConfig#dataColumns" target="_helpWin">Data columns</a> that have been ' +
             'added will be displayed in the list below.<ul><li>To view the options for a defined column, select it ' +
             'from the list below. The options above will display the current settings for the selected column.</li>' +
             '<li>To change the drawing order of a column, drag the column up or down the list until you find the desired ' +
             'drawing location, relative to the other columns. Dragging a column higher (up) in the list will draw it further ' +
             'to the left. Dragging a column lower (down) in the list will draw it futher to the right.</li> '+
             '<li>A column with a gray background indicates it contains a track that is marked as the ' +
             '<a href="showHelp.jsp?topic=vgpConfig#refTrack" target="_helpWin">reference track</a></li></ul>'
  },
  'colSettings' : {
    'title' : 'Help: Column Definition',
    'text' : 'Here you can specify the available options for <a href="showHelp.jsp?topic=vgpConfig#dataColumns" target="_helpWin">data columns</a>. ' +
             '<ul><li>The <span class="widgetRef">Column title</span> text, if set, will be drawn at the top of ' +
             'each column in the figures.</li><li>The <span class="widgetRef">Column label</span>, if enabled, ' +
             'will display a text label at the bottom of each data column, signifying the columns numeric order in ' +
             'the figure of the entry point.</li><li>Leading and trailing whitespace will be trimmed. Multiple lines ' +
             'are supported</li><li>To add a column, specify the options and click <span class="widgetRef">Add Column</span>. ' +
             'The new column will be drawn as the right-most data column, by default.</li><li>To update a column, select it ' +
             'from the list and change the settings. Click <span class="widgetRef">Update Column</span> to save the changes.</li> ' +
             '<li>To remove a column, select it from the list and click <span class="widgetRef">Remove Column</span> to remove ' +
             'the column and any associated tracks.</li></ul>All required text options are marked with a \' * \'. ' +
             'If a text option is not required, it can be blank.'
  },
  'trackDefined' : {
    'title' : 'Help: List of Tracks in Selected Column',
    'text' : '<a href="showHelp.jsp?topic=vgpConfig#annotTracks" target="_helpWin">Annotation tracks</a> that have been added to the selected column '+
             'will be displayed in the list below.<ul><li>A specific track can only be added to a column once.</li>' +
             '<li>To view the tracks that have been added to a column, select the desired column from the ' +
             '<span class="widgetRef">Column</span> drop-down.</li><li>To view the options for an added track, select it from the list below. The options ' +
             'above will display the current settings for the selected track.</li>' +
             '<li>To change the layering of a track, drag the track up or down the list. Tracks with a higher layer number will ' +
             'be drawn on top of tracks with a lower layer number.</li></ul>'
  },
  'trackSettings' : {
    'title' : 'Help: Track Settings',
    'text' : 'Here you can specify the available options for <a href="showHelp.jsp?topic=vgpConfig#annotTracks" target="_helpWin">annotation tracks</a>. Certain drawing styles have ' +
             'style-specific options, see the <a href="showHelp.jsp?topic=vgpConfig#annotTrackStyles" target="_helpWin">drawing style help</a> for information about those options.' +
             '<ul><li>To add a track, select a column from the <span class="widgetRef">Column</span> drop-down and a track from the ' +
             '<span class="widgetRef">Available tracks</span> drop-down. Set the options for the track and click ' +
             '<span class="widgetRef">Add Track</span>. The track will be added to the selected column and layered on top of ' +
             'all other tracks, by default.</li><li>To update a track, select it and change the settings. Click ' +
             '<span class="widgetRef">Update Track</span> to save those changes.</li><li>Marking a track as a ' +
             '<span class="widgetRef">Reference Track</span> will ensure the track and column are drawn centered in the entry point figure. ' +
             'This option is usually specified for a track with the <span class="widgetRef">Cytoband</span> drawing style so the bands ' +
             'can be drawn correctly.</li><li>If annotation has a color set in Genboree, check the ' +
             '<span class="widgetRef">Override track color for individual annotations</span> box to draw the annotation in that color.</li></ul>' +
             'All required text options are marked with a \' * \'. If a text option is not required, it can be blank.'
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
