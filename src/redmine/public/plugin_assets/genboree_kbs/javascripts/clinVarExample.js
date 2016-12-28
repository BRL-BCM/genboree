//var clinVarEx = {
//  name: "<b>rcvID</b>",
//  value: "<b>RCV000037626</b>",
//  iconCls:'task-folder',
//  expanded: true,
//  children:
//  [
//    {
//      name: "rsID",
//      domain: 'regexp',
//      value: "rs397507505",
//      domainOpts: { "pattern" : "^rs\\d+$" },
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "assertion",
//      domain: 'enum',
//      value: "benign",
//      domainOpts: { "values" : [ "pathogenic", "likely pathogenic", "vus", "benign" ,"likely benign" ] },
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "method",
//      value: "clinical testing",
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "chr",
//      value: "chr12",
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "start",
//      value : 112888156,
//      domain: 'posInt',
//      domainOpts: { "min" : 0 },
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "end",
//      value : 112888156,
//      domain: 'posInt',
//      domainOpts: { "min" : 0 },
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "status",
//      value: "current",
//      leaf: true,
//      iconCls: 'task'
//    },
//    {
//      name: "submitter",
//      value: "Partners Healthcare/ Harvard Medical School",
//      leaf: true,
//      iconCls: 'task'
//    }
//  ]
//} ;
var clinVarEx = { "name": "<b>rcvID</b>", "value": "<b>RCV000037626</b>", "iconCls":"task-folder", "expanded": true, "children": [ {"name": "rsID", "domain": "regexp", "value": "rs397507505", "domainOpts": {  "pattern" : "^rsd+$" }, "leaf": true, "iconCls": "task" }, { "name": "assertion", "domain": "enum", "value": "benign",  "domainOpts": { "values" : [ "pathogenic", "likely pathogenic", "vus", "benign" ,"likely benign" ] }, "leaf": true, "iconCls": "task" }]} ;