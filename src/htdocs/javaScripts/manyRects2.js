function containsPoint(rect, ptX, ptY)
{
  var inRect = false ;
  // Exclude points outside of bounds as there is no way they are in the rect
  if(ptX >= rect[0] && ptX <= rect[2] && ptY >= rect[1] && ptY <= rect[3])
  {
    inRect = true ;
  }
  return inRect ;
}
