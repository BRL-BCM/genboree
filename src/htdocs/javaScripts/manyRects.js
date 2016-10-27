function Rect(x1, y1, x2, y2)
{
  this.x1 = (x1 < x2 ? x1 : x2) ;
  this.y1 = (y1 < y2 ? y1 : y2) ;
  this.x2 = (x2 > x1 ? x2 : x1) ;
  this.y2 = (y2 > y1 ? y2 : y1) ;

  this.containsPoint = containsPoint ;
  function containsPoint(ptX, ptY)
  {
    var inRect = false ;
    // Exclude points outside of bounds as there is no way they are in the rect
    if(ptX >= this.x1 && ptX <= this.x2 && ptY >= this.y1 && ptY <= this.y2)
    {
      inRect = true ;
    }

    return inRect ;
  }
}
