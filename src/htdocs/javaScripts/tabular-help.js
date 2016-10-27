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
 */

var tabularHelp = new Array() ;
tabularHelp[0] =
{
  title: "Help: Annotation Groups",
  text: "An <b><em>annotation group</em></b> is formed from annotations with identical <b>names</b> " + 
        "from the same track and entry point.  A typical example of an annotation group is a gene " + 
        "with more than one exon. " +
        "When an <b><em>annotation group</em></b> is formed, you can decide between two different " +
        "display modes to handle the display of data for that group, <b>terse</b> and <b>verbose</b>. " +
        "<ul><li>In both modes, the following rules will apply to aggregate data for the " +
        "annotation group:<br><table><tr><td><b>start</b></td><td>The smallest coordinate of the group " +
        "will be displayed</td></tr><tr><td><b>stop</b></td><td>The largest coordinate of the group " +
        "will be displayed</td></tr><tr><td><b>score</b></td><td>The average score will be displayed</td>" +
        "</tr><tr><td><b>strand</b></td><td>The value displayed will be determined by majority " +
        "vote</td></tr></table><br>All other columns depend on the display mode.  In <b>verbose</b> " +
        "mode, all of the distinct values will be displayed separated by commas.  In <b>terse</b> " + 
        "mode, only columns where all annotations in the group have identical values will be displayed; " + 
        "otherwise the special keyword <em>&quot;{varies}&quot;</em> will be displayed.</li></ul>" +
        "Please refer to " + 
        "<a class='helpNav' href='showHelp.jsp?topic=layoutSetup#groupingData' target='_helpWin'>" +
        "Grouping of Annotation Data</a> for more details." 
} ;
tabularHelp[1] =
{
  title: "Help: Layouts",
  text: "A layout is a user-defined format of a tabular view of data that allows you to specify " +
        "column content and order, sorting, and grouping of data. " +
        "<ul><li>If you select a Group for which you have write permissions, you will be able to " +
        "create and save your own layouts for future use, or for use with other data tracks.</li>" +
        "<li> If you select a Group for which you are an administrator, you will be able to delete " +
        "previous layouts.</li>" +
        "<li>If you don't have write permissions for a Group, you can still choose a layout from the " +
        "drop-down menu, or make a temporary layout.</li></ul>" + 
        "Please refer to " +
        "<a class='helpNav' href='showHelp.jsp?topic=layoutSetup' target='_helpWin'>Tabular View and Layout Design</a> " +
        "for more details."
} ;
tabularHelp[2] = 
{
  title: "Help: Layout Setup",
  text: "<ul><li>In order to display an attribute as a column in the layout, " +
        "please check the <b>first checkbox</b>.</li>" +
        "<li>In order to sort the data by an attribute from the list, " + 
        "please check the <b>second checkbox</b>.</li>" +
        "<li>Use the 'Displayed Items' list to arrange the columns in the order " +
        "that they will be displayed from left to right, and the 'Sorting Order' " +
        "list to define the order in which the data will be sorted.</li>" +
        "<li>If a track or layout change results in a layout that has User-Defined " +
        "attributes that do not exist for the selected tracks, those attributes will " +
        "appear grayed out in the list, and you will " +
        "no longer be able to select them, only deselect.  Also, if you deselect both " +
        "of the checkboxes for these attributes, they will disappear from the list. " +
        "You will still be able arrange these attributes in the &quot;Order of " +
        "Columns&quot; or &quot;Sorting Order&quot; lists, but be aware that these " + 
        "attributes will not be used in the sort, and empty columns will be displayed " +
        "for these attributes in the generated table.</li></ul>" +
        "Please refer to " +
        "<a class='helpNav' href='showHelp.jsp?topic=layoutSetup#usingLayouts' target='_helpWin'>" +
        "7.2.2 Using Layouts</a> " +
        "for more details."
}

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
    width: 350,
    minHeight: 100,
    minWidth: 150,
    modal: false,
    proxyDrag: true
  }) ;
  Ext.Msg.getDialog().setPagePosition(Ext.get(button).getX() + 25, Ext.get(button).getY() + 25) ;

  return false ;
}
