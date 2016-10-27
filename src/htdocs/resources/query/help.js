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
  'queryProps' : {
    'title' : 'Help: Query Properties',
    'text' : 'Here you can specify the properties for the query that will be created.' +
      '<ul><li>Every query requires a name that is unique in the database it is saved. ' +
      'The <span class="widgetRef">Query Name</span> textfield will be highlighted red if ' +
      'the name is not available</li><li>Use the <span class="widgetRef">Query Template</span> ' +
      'select to model your query after the attributes of a template resource. A template ' +
      'is not required.</li><li>Share the query by checking the <span class="widgetRef">Share this query</span> ' +
      'checkbox if you would like all users to access your query</li>' +
      '<li>Note that you can only save queries to a group that you have write permissions for</li></ul>'
  },
  'defineQuery' : {
    'title' : 'Help: Query Construction',
    'text' : 'Here you can construct the query by specifying each clause and creating complex relationships ' +
      'with nests.<ul><li>Use the nest, unnest, add and delete buttons to modify the clauses of the query</li>' + 
      '<li>If the value of the clause is a string, you can make the match case sensitive by checking the ' +
      '<span class="widgetRef">Case Sensitive</span> checkbox</li><li>Use the AND & OR buttons to specify the ' +
      'boolean relationship between clauses. Note that any nest level can only contain one boolean relationship</li>' +
      '<li>Use the <span class="widgetRef">Append Clause</span> link to add a clause to the end of any nest level</li></ul>'
  },
  'applyQuery' : {
    'title' : 'Help: Apply Query',
    'text' : 'Here you can apply a created query to a specific resource in a <span class="widgetRef">Group</span> and ' +
      '<span class="widgetRef">Database</span><ul><li>If applying a query to <span class="widgetRef">Annotation in a Track</span> ' +
      'you will also have to specify the track name</li></ul>'
  },
  'queryMode' : {
    'title' : 'Help: Query Mode',
    'text' : 'Select the query management mode.<ul><li>Select <span class="widgetRef">Create a New Query</span> to specify a new query</li>' +
      '<li>Select <span class="widgetRef">Edit an Existing Query</span> and select the group, database and query name to edit an existing query</li>' +
      '<li>Note that you can only edit queries for a group that you have write permissions to</li></ul>'
  },
  'listQueries' : {
    'title' : 'Help: Available Queries',
    'text' : 'Select the <span class="widgetRef">Group</span> and <span class="widgetRef">Database</span> to see available queries that can be applied.'
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
    cls : 'helpMsg',
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
