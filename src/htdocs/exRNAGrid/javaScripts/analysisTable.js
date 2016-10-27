// Renders the study-analysis panel 
function makePanelWithAnalysisTable(buttonId)
{
  var button = Ext.get(buttonId);
  var extElement = 'gvTree';
  var thisPanel = Ext.get(extElement);
  // Destroy existing content in the panel
  thisPanel.destroy();

  if (button.hasCls("clicked")) {
    // When button is already clicked, then reset buttons
    // and display welcome text
    button.removeCls("clicked");
    button.addCls("unclicked") ;
    welcomeText();
  } else {
    // Remove any clicked classes
    var buttons = Ext.DomQuery.select(".button-link") ;
    for(var ii=0; ii<buttons.length; ii++)
    {
      var extObj = Ext.get(buttons[ii]);
      extObj.removeCls("clicked");
      extObj.addCls("unclicked");
    }
    button.addCls("clicked") ;
    button.removeCls("unclicked");
    
    // Store for the analysis grid
    var studyAnalysisStore = new Ext.data.SimpleStore(
      {
        fields:
        [
          { name : 'analysisID' },        
          { name : 'studyTitle' },
          { name : 'expType' },
          { name : 'piName' },
          { name : 'fundingSource' },
          { name : 'grantName' },
          { name : 'organization' }
        ]
      }) ;
  
    // Analysis grid definition
    var studyAnalysisGrid = new Ext.grid.GridPanel(
      {
        id: 'studyAnGrid',
        viewConfig: { forceFit: true },
        autoScroll: true,
        height: 250,
        store: studyAnalysisStore,
        columns:
        [
          {
            id: 'analysisID',
            text: 'Analysis Accession ID',
            tip: "<b>Value</b><br>Analysis Document Accession ID. Click to open the grid for this Analysis Document. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'analysisID',
            width: 200,
            sortable: true
          },        
          {
            id: 'studyTitle',
            text: 'Study Title',
            tip: "<b>Study Title</b><br>Name of the Study. Click arrow on right corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'studyTitle',
            width: 250,
            sortable: true
          },
          {
            id: 'expType',
            text: 'Experiment Type',
            tip: "<b>Value</b><br>Type of experiment. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'expType',
            width: 150,
            sortable: true
          },  
          {
            id: 'piName',
            text: 'PI Name',
            tip: "<b>Value</b><br>Name of the PI. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'piName',
            width: 150,
            sortable: true
          },
          {
            id: 'fundingSource',
            text: 'Funding Source',
            tip: "<b>Value</b><br>Funding Source. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'fundingSource',
            width: 150,
            sortable: true
          },
          {
            id: 'grantName',
            text: 'Grant Name/Number',
            tip: "<b>Value</b><br>Grant Name/Number. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'grantName',
            width: 150,
            sortable: true
          },
          {
            id: 'organization',
            text: 'Organization',
            tip: "<b>Value</b><br>Organization. Use the arrow on the corner to sort this column.",
            renderer: function(value, md, rec, ri, ci, store, view){
              var retVal = "<span data-qtip='"+value+"'>"+value+"</span>" ;
              return retVal ;
            },
            dataIndex: 'organization',
            width: 150,
            sortable: true
          }
        ],
        stripeRows: true
      }) ;
    
    // Panel for the studyAnalysis grid
    // NOTE: All grids as well as welcome text are rendered into the same div with id "mainDivPanel"
    // and same Ext.Panel with id "gvTree"
    studyAnalysistree = new Ext.Panel({
      border: true,
      cls: 'mainPanel',
      bodyCls: 'colPanel',
      title: 'Grid for exRNA Profiling Studies',
      id: extElement,
      width: 910,
      height: 300,
      useArrows: true,
      autoScroll: true,
      enableDD: true,
      draggable: false,
      rootVisible: false,
      items: [studyAnalysisGrid],
      renderTo: 'mainDivPanel'
    });      
     
    // Define the property-value pair for the study-analysis grid
    // Static data for now, should come from a transformation across collections
    var gridValues = [];
    
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-AKRIC1AKGBMexo-AN")>EXR-AKRIC1AKGBMexo-AN</a></b>','AK-exosome RNA','Small RNA-seq','Anna Krichevsky','NIH Common Fund','1U19CA179563-01','BWH']) ;
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-DGALA1GUTPLASM-AN")>EXR-DGALA1GUTPLASM-AN</a></b>','The Complex Exogenous RNA Spectra in Human Plasma: An Interface with Human Gut Biota?','Small RNA-seq','David Galas','NIH Common Fund','1U01HL126496-01','Pacific Northwest Diabetes Research Institute']) ;
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-KJENS1ADPD0000-AN")>EXR-KJENS1ADPD0000-AN</a></b>','Profiles of Extracellular miRNA in Cerebrospinal Fluid and Serum from Patients with Alzheimers and Parkinsons Diseases Correlate with Disease Status and Features of Pathology','Small RNA-seq','Kendall Jensen','Michael J Fox Foundation for Parkinsons Research','Non-ERCC Funded Study','Translational Genomics Research Institute']) ;
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-LLAUR1M4TD4M0N-AN")>EXR-LLAUR1M4TD4M0N-AN</a></b>','Sept2014_ExRNA','Small RNA-seq','Louise Laurent','NIH Common Fund','1UH2TR000906-01','University of California-San Diego']) ;
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-RCOFF1CRCDLD00-AN")>EXR-RCOFF1CRCDLD00-AN</a></b>','RNAseq analysis of colorectal cancer cells: KRAS regulation of secreted RNAs','Small RNA-seq','Robert Coffey','Common Fund/NIH: U19 CA179514-02 (Coffey)','1U19CA179514-01','Vanderbilt University School of Medicine']) ;
    gridValues.push(['&nbsp;<b><a href=javascript:makeAnPanel("EXR-RCOFF1KCVSLE00-AN")>EXR-RCOFF1KCVSLE00-AN</a></b>','High-Density Lipoproteins - small RNA Signatures in Systemic Erythematosus Lupus','Small RNA-seq','Robert Coffey','Common Fund/NIH: U19 CA179514-02 (Coffey)','1U19CA179514-01','Vanderbilt University School of Medicine']) ;
  
    var anStor = Ext.getCmp('studyAnGrid').store ;
    anStor.loadData(gridValues) ;
  }  
}

// Welcome Text for the Atlas Entry Page
function welcomeText() {
  var message = '\
    <div class="clickAbove">Click the buttons in the panel above to view the different types of exRNA Atlas Grids.</div> \
      <div class="welcomeText"> \
        The Extracellular RNA (exRNA) Atlas<sup style="color: red">BETA</sup> includes reference exRNA Profiles and the results of their \
        integrative and comparative analyses. \
        <br>The current release of the Atlas displays preliminary data generated by various Extracellular RNA Communications Consortium (ERCC) funded groups and analyzed using the exceRpt small RNA-seq pipeline.  \
        There are 3 grids available in this version of the exRNA Atlas, as described below. \
        <div class="gridType"> \
          <h2>Grid for exRNA Profiling Studies</h2> \
          <p> \
          This grid displays a summary of various "studies" deposited to the Data Coordination Center (DCC), along with details \
          of submitters, their organization, their grant details and links to view RNA Profiles of biosamples submitted as part of the study. \
          The RNA Profile grid summarizes the counts of reads mapped to various RNA libraries against which raw reads were mapped by the \
          exceRpt small RNA-seq data analysis pipeline. This grid view also shows histograms of the read counts to enable quicker visualization \
          of reads mapped to different RNA libraries. \
          </p> \
        </div> \
        <div class="gridType"> \
          <h2>Biofluids vs Experiment Types</h2> \
          <p> \
          This grid shows the number of biosamples from a biofluid-experiment type combination. Upon clicking each cell, users \
          can view the list of biosamples, some metadata about each biosample and a histogram view of reads from each biosample mapped to various small RNA libraries. \
          </p> \
        </div> \
        <div class="gridType"> \
          <h2>Biofluids vs Diseases</h2> \
          <p> \
          This grid shows the number of biosamples obtained and profiled from a biofluid-disease combination. Upon clicking each cell, users \
          can view the list of biosamples, some metadata about each biosample and a histogram view of reads from each biosample mapped to various small RNA libraries. \
          </p> \
        </div> \
      </div> \
      <div class="usefulLinks"> \
        <h2>Links to various ERCC resources</h2> \
        <ul class="list-unstyled"> \
          <li><a href="http://exrna.org" target="_blank">exRNA Portal</a></li> \
          <li><a href="http://genboree.org" target="_blank">Genboree Workbench</a></li> \
          <li><a href="http://genboree.org/theCommons/projects/exrna-mads/wiki" target="_blank">ERCC Data and Metadata Standards</a></li> \
          <li><a href="http://genboree.org/theCommons/projects/exrna-tools-may2014/wiki" target="_blank">exRNA Data Analysis Tools</a></li> \
          <li><a href="http://commonfund.nih.gov/exrna/" target="_blank">NIH Common Fund - ERCC</a></li> \
        </ul> \
      </div> \
    </div> ';

  // Panel for rendering welcome text
  // NOTE: All grids as well as welcome text are rendered into the same div with id "mainDivPanel"
  // and same Ext.Panel with id "gvTree"
  welcomeMsg = new Ext.Panel({
    border: false,
    cls: 'welPanelText',
    bodyCls: 'colPanel',
    title: '',
    id: 'gvTree',
    width: 890,
    height: 700,
    useArrows: true,
    autoScroll: true,
    enableDD: true,
    draggable: false,
    rootVisible: false,
    html: message,
    renderTo: 'mainDivPanel'
  }); 
}

// RNA Profile Grid in a small pop-up window
function makeAnPanel(anDoc) {
  // Store for the analysis grid
  var analysisStore = new Ext.data.SimpleStore(
    {
      fields:
      [
        { name : 'property' },
        { name : 'value' }
      ]
    }) ;

  // Analysis grid definition
  var analysisGrid = new Ext.grid.GridPanel(
    {
      id: 'anGrid',
      width: 890,
      viewConfig: { forceFit: true },
      autoScroll: true,
      store: analysisStore,
      columns:
      [
        {
          id: 'property',
          text: 'Property',
          tip: "<b>Property</b><br>Description of the property being defined. Click arrow on right corner to sort this column.",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'property',
          width: 350,
          sortable: true
        },
        {
          id: 'value',
          text: 'Value',
          tip: "<b>Value</b><br>The value associated with each of the property on the left. Use the arrow on the corner to sort this column.",
          listeners: {
              render: function(c) {
                Ext.create('Ext.tip.ToolTip', {
                  target: c.getEl(),
                  html: c.tip
                });
              }
          },
          dataIndex: 'value',
          width: 250,
          sortable: true
        }
      ],
      stripeRows: true
    }) ;

 
  //First get the session default variables
  Ext.onReady(function(){
    smallGridWindow = new Ext.Window({
      cls: 'mainPanel',
      bodyCls: 'colPanel',
      id: 'anView',
      title: 'RNA PROFILE GRID',
      modal: true,
      stateful: false,
      width: 605,
      height: 250,
      bodyStyle: 'padding: 4px;',
      layout: 'fit',
      region: 'center',
      items: [analysisGrid]
    });
    smallGridWindow.show();
    smallGridWindow.hide();
    smallGridWindow.center();
    smallGridWindow.show();
    
    fillAnalysisGrid(anDoc);
  });
}


