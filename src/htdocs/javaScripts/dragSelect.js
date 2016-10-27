mouseDrag = false;
oldObjId= null; 

function mouseHover(obj)
{
 if(mouseDrag && oldObjId!=obj.id)
  {
    oldObjId=obj.id;
    swapState(obj);
    
  }
}

function clearSelections()
{
  var cellsArray = document.getElementsByClassName('exptClass2');
  for(i=0;i<=cellsArray.length-1;i++)
  {
    if(cellsArray[i].className.match(/\-selected$/))
    {
      unselectObj(cellsArray[i]);
    }
  }
  document.getElementById('ucscButton').disabled=true;
}

function startDrag(obj)
{
  mouseDrag = true;
  oldObjId=obj.id;
  document.getElementById('ucscButton').disabled=false;
  swapState(obj);
}

function stopDrag(obj)
{
  mouseDrag = false;
  oldObjId=null;
}


function unselectObj(obj1)
{
  obj1.className = obj1.className.replace(/\-selected$/,"");
  document.getElementById('display').value=document.getElementById('display').value.replace(getTextEntry(obj1),"");
  document.getElementById('display').value=document.getElementById('display').value.replace(/^,/,"");
  document.getElementById('display').value=document.getElementById('display').value.replace(/,$/,"");
  document.getElementById('display').value=document.getElementById('display').value.replace(/,,/,",");
}

function getTextEntry(obj2)
{
  arr = obj2.id.replace(/^td\-/,"").split(/\-/);
  remcId=arr[0];
  sampleId=arr[1];
  exptId=arr[2];
  return(trackHash["td-"+remcId+"-"+sampleId+"-"+exptId]);
}
function swapState(obj)
{
   
  if(obj.className.match(/\-selected$/))
  {
    unselectObj(obj);
  }
  else
  {
    obj.className += "-selected";   
    if(document.getElementById('display').value == "")
    {
      document.getElementById('display').value+=getTextEntry(obj);
    }
    else
    {
      document.getElementById('display').value+=","+getTextEntry(obj);
    }
  }
}
