/*
 overlibmws_hide.js plug-in module - Copyright Foteos Macrides 2003-2004
   For hiding elements.
   Initial: November 13, 2003 - Last Revised: February 24, 2004
 See the Change History and Command Reference for overlibmws via:

	http://www.macridesweb.com/oltest/

 License agreement for the standard overLIB applies.  Access license via:
	http://www.bosrup.com/web/overlib/license.html
*/

// PRE-INIT
OLloaded=0;
registerCommands('hideselectboxes,hidebyid,hidebyidall,hidebyidns4');

/////////
// DEFAULT CONFIGURATION
if(typeof ol_hideselectboxes=='undefined')var ol_hideselectboxes=0;
if(typeof ol_hidebyid=='undefined')var ol_hidebyid='';
if(typeof ol_hidebyidall=='undefined')var ol_hidebyidall='';
if(typeof ol_hidebyidns4=='undefined')var ol_hidebyidns4='';
// END CONFIGURATION
/////////

// INIT
var o3_hideselectboxes=0;
var o3_hidebyid='';
var o3_hidebyidall='';
var o3_hidebyidns4='';
var OLselNum,OLselectOK=(OLop7||((OLselNum=navigator.userAgent.match(/Gecko\/(\d{8})/i))&&
parseInt(OLselNum[1])>=20030624))?1:0;

// For setting runtime variables to default values.
function setHideVar(){
o3_hideselectboxes=ol_hideselectboxes;
o3_hidebyid=ol_hidebyid;
o3_hidebyidall=ol_hidebyidall;
o3_hidebyidns4=ol_hidebyidns4;
}

// For commandline parser.
function parseHideExtras(pf,i,ar){
var k=i;
if(k<ar.length){
if(ar[k]==HIDESELECTBOXES){eval(pf+'hideselectboxes=('+pf+'hideselectboxes==0)?1:0');return k;}
if(ar[k]==-HIDESELECTBOXES){eval(pf+'hideselectboxes=0');return k;}
if(ar[k]==HIDEBYID){eval(pf+"hidebyid='"+escSglQuote(ar[++k])+"'");return k;}
if(ar[k]==HIDEBYIDALL){eval(pf+"hidebyidall='"+escSglQuote(ar[++k])+"'");return k;}
if(ar[k]==HIDEBYIDNS4){eval(pf+"hidebyidns4='"+escSglQuote(ar[++k])+"'");return k;}}
return -1;
}

////////
// HIDE SUPPORT FUNCTIONS
////////
// handle the commands with id parameters
function OLchkHide(hide){
if(OLiframePI&&OLie55)return;
var theID,theObj,i;
if(o3_hidebyid&&typeof o3_hidebyid=='string'&&!(o3_hideselectboxes&&OLns6)&&!OLop7&&!OLns4){
theID=o3_hidebyid.replace(/[ ]/ig,'').split(',');
for(i=0;i<theID.length;i++){
theObj=(OLie4?o3_frame.document.all[theID[i]]:
OLns6?o3_frame.document.getElementById(theID[i]):null);
if(theObj!='undefined'&&theObj)theObj.style.visibility=(hide?'hidden':'visible');}}
if(o3_hidebyidall&&typeof o3_hidebyidall=='string'){
theID=o3_hidebyidall.replace(/[ ]/ig,'').split(',');
for(i=0;i<theID.length;i++){
theObj=(OLie4?o3_frame.document.all[theID[i]]:
OLns6?o3_frame.document.getElementById(theID[i]):
OLns4?o3_frame.document.eval(theID[i]):null);
if(theObj!='undefined'&&theObj){theObj=(
OLns4)?theObj:theObj.style;
theObj.visibility=(hide?'hidden':'visible');}}}
if(o3_hidebyidns4&&OLns4&&typeof o3_hidebyid=='string'){
theID=o3_hidebyidns4.replace(/[ ]/ig,'').split(',');
for(i=0;i<theID.length;i++){
theObj=o3_frame.document.eval(theID[i]);
if(theObj!='undefined'&&theObj)theObj.visibility=(hide?'hidden':'visible');}}
}

// handle the HIDESELECTBOXES command
function OLselectBoxes(hide,all){
if((OLiframePI&&OLie55)||OLselectOK||OLns4)return;
if(!this.sel)this.sel=o3_frame.document.getElementsByTagName("select");
var px=over.offsetLeft,py=over.offsetTop,pw=over.offsetWidth,ph=over.offsetHeight;
var bx=px,by=py,bw=pw,bh=ph;
if((OLshadowPI)&&bkdrop&&o3_shadow){bx=bkdrop.offsetLeft;by=bkdrop.offsetTop;
bw=bkdrop.offsetWidth;bh=bkdrop.offsetHeight;}
var sx,sy,sw,sh,i,sel=this.sel,selp;
for(i=0;i<sel.length;i++){
sx=0;sy=0;
if(sel[i].offsetParent){
selp=sel[i];while(selp.offsetParent&&selp.offsetParent.tagName.toLowerCase()!='body'){
selp=selp.offsetParent;sx+=selp.offsetLeft;sy+=selp.offsetTop;}
sx+=sel[i].offsetLeft;sy+=sel[i].offsetTop;sw=sel[i].offsetWidth;sh=sel[i].offsetHeight;
if(!OLie4&&sel[i].size<2)continue;
else if(hide){
if((px+pw>sx&&px<sx+sw&&py+ph>sy&&py<sy+sh)||(bx+bw>sx&&bx<sx+sw&&by+bh>sy&&by<sy+sh)){
if(sel[i].style.visibility!="hidden")sel[i].style.visibility="hidden";}
}else{
if(all||(px+pw<sx||px>sx+sw||py+ph<sy||py>sy+sh)&&(bx+bw<sx||bx>sx+sw||by+bh<sy||by>sy+sh)){
if(sel[i].style.visibility!="visible")sel[i].style.visibility="visible";}}}}
}

// Utility call sets
function OLhideUtil(a1,a2,a3,a4,a5,a6){
if(a4==null){OLchkHide(a1);if(o3_hideselectboxes)OLselectBoxes(a2,a3);
}else{OLchkHide(a1);OLchkHide(a2);
if(o3_hideselectboxes){OLselectBoxes(a3,a4);OLselectBoxes(a5,a6);}}
}

////////
// PLUGIN REGISTRATIONS
////////
registerRunTimeFunction(setHideVar);
registerCmdLineFunction(parseHideExtras);

OLhidePI=1;
OLloaded=1;
