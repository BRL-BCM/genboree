package org.genboree.dbaccess;

import java.sql.*;
import java.util.*;
import org.genboree.util.Util;

public class Ftype
{
    protected String id;
    public String getId() { return id; }
    public void setId( String id )
    {
        if( id == null ) id = "#";
        this.id = id;
    }
    protected String type;
    public String getType() { return type; }
    public void setType( String type ) { this.type = type; }
    protected String subtype;
    public String getSubtype() { return subtype; }
    public void setSubtype( String subtype ) { this.subtype = subtype; }
    protected String order;
    public String getOrder() { return order; }
    public void setOrder( String order ) { this.order = order; }
    protected String ftypestyle_id;
    public String getFtypestyle_id() { return ftypestyle_id; }
    public void setFtypestyle_id( String ftypestyle_id ) { this.ftypestyle_id = ftypestyle_id; }
    protected String fcategory_id;
    public String getFcategory_id() { return fcategory_id; }
    public void setFcategory_id( String fcategory_id ) { this.fcategory_id = fcategory_id; }

    protected String fcategory_name;
    public String getFcategory_name() { return fcategory_name; }
    public void setFcategory_name( String fcategory_name ) { this.fcategory_name = fcategory_name; }

    protected Gdatabase gdb = null;
    public Gdatabase getGdatabase() { return gdb; }
    public void setGdatabase( Gdatabase gdb )
    {
        this.gdb = gdb;
    }

    public String getScreenName()
    {
        String rc = "";
        if( !Util.isEmpty(getFcategory_name()) ) rc = rc + "/" + getFcategory_name();
        if( !Util.isEmpty(getType()) ) rc = rc + "/" + getType();
        if( !Util.isEmpty(getSubtype()) ) rc = rc + "/" + getSubtype();
        if( rc.length() > 0 ) rc = rc.substring(1);
        return rc;
    }

    public void clear()
    {
        id = "#";
        type = subtype = order = ftypestyle_id = fcategory_id = "";
        gdb = null;
    }

    public Ftype()
    {
        clear();
    }

}
