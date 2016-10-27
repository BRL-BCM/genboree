package org.genboree.genome;

import java.io.*;
import java.util.*;
import java.sql.*;

import org.genboree.dbaccess.*;

public class GenomeTemplate
{
	protected int genomeTemplate_id;
	public int getGenomeTemplateId() { return genomeTemplate_id; }
	public void setGenomeTemplateId( int genomeTemplate_id ) { this.genomeTemplate_id = genomeTemplate_id; }
	protected String genomeTemplate_name;
	public String getGenomeTemplateName() { return genomeTemplate_name; }
	public void setGenomeTemplateName( String genomeTemplate_name ) { this.genomeTemplate_name = genomeTemplate_name; }
	protected String genomeTemplate_species;
	public String getGenomeTemplateSpecies() { return genomeTemplate_species; }
	public void setGenomeTemplateSpecies( String genomeTemplate_species ) { this.genomeTemplate_species = genomeTemplate_species; }
	protected String genomeTemplate_version;
	public String getGenomeTemplateVersion() { return genomeTemplate_version; }
	public void setGenomeTemplateVersion( String genomeTemplate_version ) { this.genomeTemplate_version = genomeTemplate_version; }
	protected String genomeTemplate_source;
	public String getGenomeTemplateSource() { return genomeTemplate_source; }
	public void setGenomeTemplateSource( String genomeTemplate_source ) { this.genomeTemplate_source = genomeTemplate_source; }
	protected String genomeTemplate_release_date;
	public String getGenomeTemplateReleaseDate() { return genomeTemplate_release_date; }
	public void setGenomeTemplateReleaseDate( String genomeTemplate_release_date ) { this.genomeTemplate_release_date = genomeTemplate_release_date; }
	protected String genomeTemplate_type;
	public String getGenomeTemplateType() { return genomeTemplate_type; }
	public void setGenomeTemplateType( String genomeTemplate_type ) { this.genomeTemplate_type = genomeTemplate_type; }
	protected int genomeTemplate_scale;
	public int getGenomeTemplateScale() { return genomeTemplate_scale; }
	public void setGenomeTemplateScale( int genomeTemplate_scale ) { this.genomeTemplate_scale = genomeTemplate_scale; }
	protected String genomeTemplate_description;
	public String getGenomeTemplateDescription() { return genomeTemplate_description; }
	public void setGenomeTemplateDescription( String genomeTemplate_description ) { this.genomeTemplate_description = genomeTemplate_description; }
	protected String genomeTemplate_vgp;
	public String getGenomeTemplateVgp() { return genomeTemplate_vgp; }
	public void setGenomeTemplateVgp( String genomeTemplate_vgp ) { this.genomeTemplate_vgp = genomeTemplate_vgp; }

	public GenomeTemplate() {}

	public static GenomeTemplate[] fetchAll( DBAgent db ) throws SQLException {
		Vector v = new Vector();
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT genomeTemplate_id, genomeTemplate_name, genomeTemplate_species, "+
			"genomeTemplate_version, genomeTemplate_source, genomeTemplate_release_date, "+
			"genomeTemplate_type, genomeTemplate_scale, genomeTemplate_description, "+
			"genomeTemplate_vgp FROM genomeTemplate";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				GenomeTemplate p = new GenomeTemplate();
				p.setGenomeTemplateId( rs.getInt(1) );
				p.setGenomeTemplateName( rs.getString(2) );
				p.setGenomeTemplateSpecies( rs.getString(3) );
				p.setGenomeTemplateVersion( rs.getString(4) );
				p.setGenomeTemplateSource( rs.getString(5) );
				p.setGenomeTemplateReleaseDate( rs.getString(6) );
				p.setGenomeTemplateType( rs.getString(7) );
				p.setGenomeTemplateScale( rs.getInt(8) );
				p.setGenomeTemplateDescription( rs.getString(9) );
				p.setGenomeTemplateVgp( rs.getString(10) );
				v.addElement( p );
			}
			pstmt.close();
		} catch( Exception ex )
		{
			db.reportError( ex, "GenomeTemplate.fetchAll()" );
		}
		GenomeTemplate[] rc = new GenomeTemplate[ v.size() ];
		v.copyInto( rc );
		return rc;
	}

	protected ChromosomeTemplate[] chrTemps = null;

	public boolean fetch( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT genomeTemplate_id, genomeTemplate_name, genomeTemplate_species, "+
			"genomeTemplate_version, genomeTemplate_source, genomeTemplate_release_date, "+
			"genomeTemplate_type, genomeTemplate_scale, genomeTemplate_description, "+
			"genomeTemplate_vgp FROM genomeTemplate WHERE genomeTemplate_id="+getGenomeTemplateId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{

				setGenomeTemplateId( rs.getInt(1) );
				setGenomeTemplateName( rs.getString(2) );
				setGenomeTemplateSpecies( rs.getString(3) );
				setGenomeTemplateVersion( rs.getString(4) );
				setGenomeTemplateSource( rs.getString(5) );
				setGenomeTemplateReleaseDate( rs.getString(6) );
				setGenomeTemplateType( rs.getString(7) );
				setGenomeTemplateScale( rs.getInt(8) );
				setGenomeTemplateDescription( rs.getString(9) );
				setGenomeTemplateVgp( rs.getString(10) );
				rc = true;
			}
			pstmt.close();
			if( rc ) chrTemps = ChromosomeTemplate.fetchAll( db, getGenomeTemplateId() );
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "GenomeTemplate.fetch()" );
		}
		return false;
	}

	public ArrayList getChromosomeTemplates()
	{
	    int len = (chrTemps==null) ? 0 : chrTemps.length;
	    ArrayList rc = new ArrayList( len );
	    if( chrTemps != null )
	    for( int i=0; i<len; i++ )
	    {
	        rc.add( chrTemps[i] );
	    }
	    return rc;
	}

	public long getMaxTemplateLength()
	{
	    if( chrTemps == null ) return 0L;
	    long rc = 0L;
	    for( int i=0; i<chrTemps.length; i++ )
	    {
	        long sz = chrTemps[i].getChromosomeTemplateLength();
	        if( sz > rc ) rc = sz;
	    }
	    return rc;
	}

	public boolean insert( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection(null, false);
		if( conn != null ) try
		{
			String qs = "INSERT INTO genomeTemplate (genomeTemplate_name, genomeTemplate_species, "+
			"genomeTemplate_version, genomeTemplate_source, genomeTemplate_release_date, "+
			"genomeTemplate_type, genomeTemplate_scale, genomeTemplate_description, "+
			"genomeTemplate_vgp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getGenomeTemplateName() );
			pstmt.setString( 2, getGenomeTemplateSpecies() );
			pstmt.setString( 3, getGenomeTemplateVersion() );
			pstmt.setString( 4, getGenomeTemplateSource() );
			pstmt.setString( 5, getGenomeTemplateReleaseDate() );
			pstmt.setString( 6, getGenomeTemplateType() );
			pstmt.setInt( 7, getGenomeTemplateScale() );
			pstmt.setString( 8, getGenomeTemplateDescription() );
			pstmt.setString( 9, getGenomeTemplateVgp() );
			boolean rc = (pstmt.executeUpdate() > 0);
			if( rc ) setGenomeTemplateId( db.getLastInsertId(conn) );
			pstmt.close();
			conn.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "GenomeTemplate.insert()" );
		}
		return false;
	}

	public boolean update( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE genomeTemplate SET genomeTemplate_name=?, genomeTemplate_species=?, genomeTemplate_version=?, genomeTemplate_source=?, genomeTemplate_release_date=?, genomeTemplate_type=?, genomeTemplate_scale=?, genomeTemplate_description=?, genomeTemplate_vgp=? "+
				"WHERE genomeTemplate_id="+getGenomeTemplateId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getGenomeTemplateName() );
			pstmt.setString( 2, getGenomeTemplateSpecies() );
			pstmt.setString( 3, getGenomeTemplateVersion() );
			pstmt.setString( 4, getGenomeTemplateSource() );
			pstmt.setString( 5, getGenomeTemplateReleaseDate() );
			pstmt.setString( 6, getGenomeTemplateType() );
			pstmt.setInt( 7, getGenomeTemplateScale() );
			pstmt.setString( 8, getGenomeTemplateDescription() );
			pstmt.setString( 9, getGenomeTemplateVgp() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "GenomeTemplate.update()" );
		}
		return false;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM genomeTemplate WHERE genomeTemplate_id="+getGenomeTemplateId();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "GenomeTemplate.delete()" );
		}
		return false;
	}
}
