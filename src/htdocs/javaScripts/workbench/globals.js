/**
 * ------------------------------------------------------------------
 * GLOBALS
 * ------------------------------------------------------------------
 * Some of the following global variables are assigned by a script on the original jsp
 * page in order to pass important session variables to the JavaScript side.
 */
/*
 * The following var will be populated by tool forms/dialogs and
 * should be merged with wbHash when form is submitted. Tool specific code should
 * avoid modifying wbHash directly.
 */
var wbFormContext = new Hash();
var wbFormSettings = new Hash();

/** Other important globals. */
var wbHash = new Hash( { inputs:[], outputs:[], context:new Hash(), settings:new Hash() } ) ;
var userLogin = "" ;
var serverName = "" ;
var context = null ;
var clientContext = null ;
var wbToolSatisfactionHash = new Hash() ;
var wbDialogWindow = null ;
var wbHelpWindow = null ; // For NON-MODEL help dialog when also showing settings dialog
var wbRulesHash = null ;
var toolActivated = new Hash() ; // Hash for checking if a tool is activated or not
var successDialogHeader = null ;
var wbAcceptOkCallback = function() { return null ; } ; // invoked on jobAccepted dialog "ok"
var wbAcceptCloseCallback = function() { return null ; } ; // invoked on jobAccepted dialog "X"
var helpWindowToolId = null ;
var wbGlobalSettings = new Hash() ; // For tool specific settings. The keys should be unset immediately after use since it will affect the next tool being launched.
/** In case this wasn't already defined: **/
Ext.BLANK_IMAGE_URL = "/javaScripts/ext-2.2/resources/images/default/s.gif"
/**
 * This constant defines whether or not any node in the tree can be put into
 * the "active dataset" or only the leaves of the tree.
 */
var DRAG_ONLY_LEAVES = false ;

/**
 * Shortcuts (namespace used frequently...here are short versions)
 */
var Tree = Ext.tree ;

/**
 * Setup Workbench namespace, the vars within it, and functions to help
 * subsequent .js files decide if their dependencies have been parsed & executed yet
 * by the browser.
 *
 * Namespace is specifically for stuff restricted to workbench-related
 * javascript and not for coordination with tool UIs and such. Usually stuff used in
 * several files that are split for organizational purposes.
 */
Ext.onReady( function()
{
  Ext.namespace('Workbench', 'Workbench.wbMainTreeLoader') ;
  Ext.namespace('Workbench.mainTree', 'Workbench.inputsTree', 'Workbench.outputsTree') ;
  Ext.namespace('Workbench.wrapPanel', 'Workbench.toolbar', 'Workbench.store') ;
  Ext.namespace('Workbench.globalsLoaded', 'Workbench.panelsLoaded', 'Workbench.toolbarsLoaded', 'Workbench.ajaxLoaded') ;

  // We make "loader" helper functions available right away:
  Workbench.allLoaded = function()
  {
    return  Workbench.globalsLoaded &&
            Workbench.panelsLoaded &&
            Workbench.toolbarsLoaded &&
            Workbench.ajaxLoaded ;
  } ;

  // When there are order-dependencies between files, we use the "*Loaded" vars
  // of Workbench to help us ensure things get done in order.
  // Now that we have a "Workbench" namespace and are done with the globals.js,
  // we set Workbench.globalsLoaded to true since everything needs the globals & namespace available.
  // Other .js will do the same.
  Workbench.globalsLoaded = true ;
}) ;
