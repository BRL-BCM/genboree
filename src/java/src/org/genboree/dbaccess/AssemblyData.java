package org.genboree.dbaccess;

import org.genboree.upload.*;

/**
 * User: tong Date: Aug 10, 2005 Time: 1:08:20 PM
 */
public class AssemblyData implements RefSeqParams{

    private String id;

    private String name;
    private long start;
    private long end;
      private String className;
    private long tstart;
    private long tend;

    public AssemblyData(String[] data) {
        init(data);

    }

    private void init(String[] data) {
        if (data != null && data.length > 6) {
            id = data[ASSEM_ID];
            className = data[ASSEM_CLASS];
            name = data[ASSEM_NAME];
            try {
                start = Long.parseLong(data[ASSEM_START]);
                end = Long.parseLong(data[ASSEM_END]);
                tstart = Long.parseLong(data[ASSEM_TSTART]);
                tend = Long.parseLong(data[ASSEM_TEND]);

            } catch (NumberFormatException e) {
                return;
            }
        }
    }


   public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getClassName() {
        return className;
    }

    public void setClassName(String className) {
        this.className = className;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public long getStart() {
        return start;
    }

    public void setStart(long start) {
        this.start = start;
    }

    public long getEnd() {
        return end;
    }

    public void setEnd(long end) {
        this.end = end;
    }


    public long getTstart() {
        return tstart;
    }

    public void setTstart(long tstart) {
        this.tstart = tstart;
    }

    public long getTend() {
        return tend;
    }

    public void setTend(long tend) {
        this.tend = tend;
    }





}
