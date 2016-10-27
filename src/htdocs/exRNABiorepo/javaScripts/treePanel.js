//dispalys the table content on an Ext.Window
function simplePanel(table)
{
 var pan = new Ext.panel.Panel({
        border: true,
        cls: 'mainPanel',
        bodyCls: 'colPanel',
        title: 'Grid showing available Biospecimens',
        html: table,
        autoHeight: true,
        autoWidth: true,
        renderTo: 'panel'
});
}
