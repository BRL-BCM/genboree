package org.genboree.editor;

import org.apache.commons.validator.routines.LongValidator;

import java.sql.ResultSet;
import java.sql.PreparedStatement;
import java.sql.Connection;


/**
 * User: tong Date: Nov 17, 2005 Time: 8:44:43 AM
 */
public class Chromosome {
    int id;

    long start;

     public long getStart() {
         return start;
     }

     public void setStart(long start) {
         this.start = start;
     }

     public long getStop() {
         return stop;
     }

     public void setStop(long stop) {
         this.stop = stop;
     }

     long stop; 
     
    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getRefname() {
        return refname;
    }

    public void setRefname(String refname) {
        this.refname = refname;
    }

    public long getLength() {
        return length;
    }

    public void setLength(long length) {
        this.length = length;
    }

    String refname;
    long length;


    public Chromosome(String name) {
        this.refname = name;
    }
	
	
	public Chromosome(int  id) {
		   this.id = id;
	   }
     	
	      public Chromosome() {
		  
	   }
     
	  public static boolean validateChromosomeStart (String fstart  ) {
             boolean success = true;
              Long chrStart = LongValidator.getInstance().validate(fstart);
              if ( chrStart == null)   
             success = false; 
              else {
                  if (chrStart.longValue()<1) 
                  success = false; 
                  
              }
              return success; 
          }    
             
             
                public static boolean validateChromosomeStop (String fstop , long max ) {
             boolean success = true;
             Long chrStop = LongValidator.getInstance().validate(fstop); 
             if (chrStop  == null)   
             success = false;  
             else 
             {
                
              if (chrStop.longValue() > max)    
                success = false; 
             }
                    
                    
              return success; 
          }        
     

	
	public static Chromosome  findChromosome (Connection con , String chrName ) {
		Chromosome chromosome  = null; 
		String sql = "select rid, rlength  from fref where refname = ? "; 
		try {
			PreparedStatement stms = con.prepareStatement(sql); 
			stms.setString(1, chrName); 
			ResultSet rs = stms.executeQuery(); 
			if (rs.next()) {
				chromosome = new Chromosome (rs.getInt(1));
				chromosome.setLength(rs.getLong(2));
				chromosome.setRefname(chrName);
			} 
		}
		catch (Exception e ) {
			e.printStackTrace ();
		}
	
		 return chromosome ; 

	}
	
	
	
	
}
