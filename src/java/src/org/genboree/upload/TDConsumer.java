package org.genboree.upload;

import java.util.*;
import org.genboree.util.Util;

public interface TDConsumer
{
    public void consume( TDReceiver receiver, String[] data );
    public void setMeta( String[] meta );
}

