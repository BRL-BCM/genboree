



// Uses extjs library
//

// Declare a namespace...this is global in whole page from now on
Ext.namespace('Ext.genboree');

// Put page-specific stuff in this namespace.
// We will coordinate certain variables and behaviors through this namespace.
// Can refer to this namespace within .js file that follow this one or on the
// page itself.
//
// NOTE: this namespace requires two global javascript variables be defined on
// the JSP/html page:
// (a) tooFewForMenuBtn
// (b) tooManyForMenuBtn
Ext.genboree = function()
{

  var annoRecords = [] ; // Array of objects with uploadId and fid properties. Filled in by JSP.
  var lastRecordClicked = null ; // Keeps track of what record last had its Edit button clicked (actually the little menu arrow)
  var delayExec = null ; // Stores a Prototype PeriodicExecutor object so can delay adding the Edit buttons when there are lots
    
  // Namespace Functions:
  // Return a hash of named-functions for adding a new record or getting the whole reocrd array
  return  {
            addRecord: function(uploadId, fid) // add a record to annoRecords
            {
              annoRecords.push(
                                {
                                  uploadId: uploadId,
                                  fid: fid
                                }
                             );
              return ;
            },
            getRecords: function() // get annoRecords Array
            {
              return annoRecords ;
            },
            setLastRec: function(recNum) // set last record clicked for later referral
            {
              return lastRecordClicked = recNum ;
            },
            getLastRec: function() // get the last record clicked
            {
              return lastRecordClicked ;
            },
            setDelayExec: function(pe) // set the PeriodicalExecution object for later referral
            {
              return delayExec = pe ;
            },
            getDelayExec: function() // get the PeriodiclExecution object
            {
              return delayExec ;
            },
            init: function()
            {
               // For the page initialization mask
              
               var loading = Ext.get('genboree-loading'); // Name of page loading div
                var mask = Ext.get('genboree-loading-mask'); // Name of page loading mask div
                if (mask) {
                mask.setOpacity(0.5);
                mask.shift(
                            {
                              remove: true,
                              duration: 0.1,
                              opacity: 0.3,
                              callback:   function()
                                          {
                                            loading.fadeOut( { duration: 0.1, remove: true} );
                                          }
                            });
                            
                       }     
              }
            
          };
}();

// Register initialization of namespace once page fully loads.

Ext.onReady(Ext.genboree.init, Ext.genboree, true);

// Register a periodical executor (from Prototype) with the page.
// This allows the page mask above to be displayed if needed.
//
// NOTE: this namespace requires two global javascript variables be defined on
// the JSP/html page:
// (a) tooFewForMenuBtn
// (b) tooManyForMenuBtn

Ext.onReady(
  function(){
     
      //  addEditButtons();     
        if ($("rearrange_list_1")) {    
            //var recs = Ext.genboree.getRecords() ;        
            Ext.genboree.setDelayExec(new PeriodicalExecuter(addEditButtons, 0.1)) ;
                 
        } 
      
  }
);


// Add Edit buttons to each <div> we set aside on the page
function addEditButtons()
{
 
  // Make sure this setup function is only run ONCE. Turn off PeriodicalExecutor.
   var pe = Ext.genboree.getDelayExec() ;
   pe.stop() ;
    // Remove mask now that we are set up.
    var bt = Ext.Element.get(document.body) ;
    
   // if(bt.isMasked())
    {
     // bt.unmask() ;
      
      
    }
}



// --------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------
var trgWinHdl = null ;
function newWin(trgWinUrl, trgWinName) // This will do the actual popping up when the link is clicked
{
  if(!trgWinName)
  {
    trgWinName = '_newWin' ;
  }
  if(!trgWinHdl || trgWinHdl.closed)
  {
    trgWinHdl = window.open(trgWinUrl, trgWinName, '');
  }
  else
  {
    // winHandle not null AND not closed
    trgWinHdl.location = trgWinUrl;
  }

  if(trgWinHdl && window.focus)
  {
    trgWinHdl.focus() ;
  }
  return false ;
}


