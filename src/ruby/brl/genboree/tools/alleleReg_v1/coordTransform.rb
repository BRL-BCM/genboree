def zeroToOne type,startc,endc
 if(type == "s")
     return startc=startc+1,endc=endc
 elsif(type == "d")
     return startc=startc+1,endc=endc
 elsif(type == "i")
     return startc = startc,endc=endc+1
 else
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Unknown type of instance to convert from zero to one coordinate system")
 end
end

def oneTozero type,startc,endc
 if(type == "s")
      return startc=startc-1, endc=endc
 elsif(type == "d")
      return startc=startc-1, endc=endc;
 elsif(type == "i")
      return start=start, endc=endc - 1
 else
     raise BRL::Genboree::GenboreeError.new(:'Internal Server Error',"Unknown type of instance to convert from one to zero coordinate system")
 end
end
