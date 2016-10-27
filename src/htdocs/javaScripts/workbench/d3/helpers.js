/*
 Notes:
    * Adds transform attribute if there isn't any
*/

function getTransMatrix(svg, gEl)
{
  var mmStr ;
  if(gEl == null || gEl == undefined)
  {
    var gEl = svg.select("g")[0][0] ; 
  }
  mmStr = gEl.getAttribute("transform") ;
  var transM = [] ;
  if(mmStr == null || mmStr == undefined || !mmStr.match(/\S+/)) // Shim in default matrix
  {
    transM = [1,0,0,1,0,0] ;
    gEl.setAttributeNS(null, "transform", "matrix(1 0 0 1 0 0)");
  }
  else
  {
    transM = mmStr.split('(')[1].split(')')[0].split(' ') ;
    for(var ii=0; ii<6; ii++)
    {
      transM[ii] = parseFloat(transM[ii]) ;
    }
  }
  return transM ;
}

function getGElement(svg, gid)
{
  var gEl ;
  if(gid == null || gid == undefined)
  {
    gEl = svg.select("g") ; // This gets the first one
  }
  else
  {
    gEl = svg.select("g#"+gid) ;
  }
  gEl = gEl[0][0] ;    
  return gEl ;
}

function pan(dx, dy, gid)
{
  var gEl ;
  var svg = d3.select("svg") ;
  gEl = getGElement(svg, gid) ;
  var transMatrix = getTransMatrix(svg, gEl) ;
  transMatrix[4] += dx;
  transMatrix[5] += dy;
  var newMatrix = "matrix(" +  transMatrix.join(' ') + ")";
  gEl.setAttributeNS(null, "transform", newMatrix);
}

function zoom(scale, gid)
{
  
  var height = 300 ;
  var width = 500 ;
  var svg = d3.select("svg") ;
  var gEl = getGElement(svg, gid) ;
  var transMatrix = getTransMatrix(svg, gEl) ;
  for (var i=0; i<transMatrix.length; i++)
  {
    transMatrix[i] *= scale;
  }
  transMatrix[4] += (1-scale)*width/2;
  transMatrix[5] += (1-scale)*height/2;
  var newMatrix = "matrix(" +  transMatrix.join(' ') + ")";
  gEl.setAttributeNS(null, "transform", newMatrix);
} 