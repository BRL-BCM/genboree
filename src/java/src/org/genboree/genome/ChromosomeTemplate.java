package org.genboree.genome;

import java.io.*;
import java.util.*;
import java.sql.*;

import org.genboree.dbaccess.*;

public class ChromosomeTemplate
{
	protected int chromosomeTemplate_id;
	public int getChromosomeTemplateId() { return chromosomeTemplate_id; }
	public void setChromosomeTemplateId( int chromosomeTemplate_id ) { this.chromosomeTemplate_id = chromosomeTemplate_id; }
	protected String chromosomeTemplate_data;
	public String getChromosomeTemplateData() { return chromosomeTemplate_data; }
	public void setChromosomeTemplateData( String chromosomeTemplate_data ) { this.chromosomeTemplate_data = chromosomeTemplate_data; }
	protected int chromosomeTemplate_length;
	public int getChromosomeTemplateLength() { return chromosomeTemplate_length; }
	public void setChromosomeTemplateLength( int chromosomeTemplate_length ) { this.chromosomeTemplate_length = chromosomeTemplate_length; }
	protected int chromosomeTemplate_box_size;
	public int getChromosomeTemplateBoxSize() { return chromosomeTemplate_box_size; }
	public void setChromosomeTemplateBoxSize( int chromosomeTemplate_box_size ) { this.chromosomeTemplate_box_size = chromosomeTemplate_box_size; }
	protected String chromosomeTemplate_symbol_id;
	public String getChromosomeTemplateSymbolId() { return chromosomeTemplate_symbol_id; }
	public void setChromosomeTemplateSymbolId( String chromosomeTemplate_symbol_id ) { this.chromosomeTemplate_symbol_id = chromosomeTemplate_symbol_id; }
	protected String chromosomeTemplate_chrom_name;
	public String getChromosomeTemplateChromName() { return chromosomeTemplate_chrom_name; }
	public void setChromosomeTemplateChromName( String chromosomeTemplate_chrom_name ) { this.chromosomeTemplate_chrom_name = chromosomeTemplate_chrom_name; }
	protected String chromosomeTemplate_standard_name;
	public String getChromosomeTemplateStandardName() { return chromosomeTemplate_standard_name; }
	public void setChromosomeTemplateStandardName( String chromosomeTemplate_standard_name ) { this.chromosomeTemplate_standard_name = chromosomeTemplate_standard_name; }
	protected int FK_genomeTemplate_id;
	public int getFKGenomeTemplateId() { return FK_genomeTemplate_id; }
	public void setFKGenomeTemplateId( int FK_genomeTemplate_id ) { this.FK_genomeTemplate_id = FK_genomeTemplate_id; }

	public ChromosomeTemplate() {}

	public static ChromosomeTemplate[] fetchAll( DBAgent db, int genomeTemplateId ) throws SQLException {
		Vector v = new Vector();
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT chromosomeTemplate_id, chromosomeTemplate_data, "+
			"chromosomeTemplate_length, chromosomeTemplate_box_size, "+
			"chromosomeTemplate_symbol_id, chromosomeTemplate_chrom_name, "+
			"chromosomeTemplate_standard_name, FK_genomeTemplate_id "+
			"FROM chromosomeTemplate WHERE FK_genomeTemplate_id="+genomeTemplateId+" "+
			"ORDER BY chromosomeTemplate_chrom_name";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			while( rs.next() )
			{
				ChromosomeTemplate p = new ChromosomeTemplate();
				p.setChromosomeTemplateId( rs.getInt(1) );
				p.setChromosomeTemplateData( rs.getString(2) );
				p.setChromosomeTemplateLength( rs.getInt(3) );
				p.setChromosomeTemplateBoxSize( rs.getInt(4) );
				p.setChromosomeTemplateSymbolId( rs.getString(5) );
				p.setChromosomeTemplateChromName( rs.getString(6) );
				p.setChromosomeTemplateStandardName( rs.getString(7) );
				p.setFKGenomeTemplateId( rs.getInt(8) );
				v.addElement( p );
			}
			pstmt.close();
		} catch( Exception ex )
		{
			db.reportError( ex, "ChromosomeTemplate.fetchAll()" );
		}
		ChromosomeTemplate[] rc = new ChromosomeTemplate[ v.size() ];
		v.copyInto( rc );
		return rc;
	}

	public boolean fetch( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "SELECT chromosomeTemplate_id, chromosomeTemplate_data, "+
			"chromosomeTemplate_length, chromosomeTemplate_box_size, "+
			"chromosomeTemplate_symbol_id, chromosomeTemplate_chrom_name, "+
			"chromosomeTemplate_standard_name, FK_genomeTemplate_id "+
			"FROM chromosomeTemplate WHERE chromosomeTemplate_id="+getChromosomeTemplateId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			ResultSet rs = pstmt.executeQuery();
			boolean rc = false;
			if( rs.next() )
			{
				setChromosomeTemplateId( rs.getInt(1) );
				setChromosomeTemplateData( rs.getString(2) );
				setChromosomeTemplateLength( rs.getInt(3) );
				setChromosomeTemplateBoxSize( rs.getInt(4) );
				setChromosomeTemplateSymbolId( rs.getString(5) );
				setChromosomeTemplateChromName( rs.getString(6) );
				setChromosomeTemplateStandardName( rs.getString(7) );
				setFKGenomeTemplateId( rs.getInt(8) );
				rc = true;
			}
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "ChromosomeTemplate.fetch()" );
		}
		return false;
	}

	public boolean insert( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection(null, false);
		if( conn != null ) try
		{
			String qs = "INSERT INTO chromosomeTemplate (chromosomeTemplate_data, "+
			"chromosomeTemplate_length, chromosomeTemplate_box_size, "+
			"chromosomeTemplate_symbol_id, chromosomeTemplate_chrom_name, "+
			"chromosomeTemplate_standard_name, FK_genomeTemplate_id) "+
			"VALUES (?, ?, ?, ?, ?, ?, ?)";
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getChromosomeTemplateData() );
			pstmt.setInt( 2, getChromosomeTemplateLength() );
			pstmt.setInt( 3, getChromosomeTemplateBoxSize() );
			pstmt.setString( 4, getChromosomeTemplateSymbolId() );
			pstmt.setString( 5, getChromosomeTemplateChromName() );
			pstmt.setString( 6, getChromosomeTemplateStandardName() );
			pstmt.setInt( 7, getFKGenomeTemplateId() );
			boolean rc = (pstmt.executeUpdate() > 0);
			if( rc ) setChromosomeTemplateId( db.getLastInsertId(conn) );
			pstmt.close();
			conn.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "ChromosomeTemplate.insert()" );
		}
		return false;
	}

	public boolean update( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "UPDATE chromosomeTemplate SET chromosomeTemplate_data=?, chromosomeTemplate_length=?, chromosomeTemplate_box_size=?, chromosomeTemplate_symbol_id=?, chromosomeTemplate_chrom_name=?, chromosomeTemplate_standard_name=?, FK_genomeTemplate_id=? "+
				"WHERE chromosomeTemplate_id="+getChromosomeTemplateId();
			PreparedStatement pstmt = conn.prepareStatement( qs );
			pstmt.setString( 1, getChromosomeTemplateData() );
			pstmt.setInt( 2, getChromosomeTemplateLength() );
			pstmt.setInt( 3, getChromosomeTemplateBoxSize() );
			pstmt.setString( 4, getChromosomeTemplateSymbolId() );
			pstmt.setString( 5, getChromosomeTemplateChromName() );
			pstmt.setString( 6, getChromosomeTemplateStandardName() );
			pstmt.setInt( 7, getFKGenomeTemplateId() );
			boolean rc = (pstmt.executeUpdate() > 0);
			pstmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "ChromosomeTemplate.update()" );
		}
		return false;
	}

	public boolean delete( DBAgent db ) throws SQLException {
		Connection conn = db.getConnection();
		if( conn != null ) try
		{
			String qs = "DELETE FROM chromosomeTemplate WHERE chromosomeTemplate_id="+getChromosomeTemplateId();
			Statement stmt = conn.createStatement();
			boolean rc = (stmt.executeUpdate(qs) > 0);
			stmt.close();
			return rc;
		} catch( Exception ex )
		{
			db.reportError( ex, "ChromosomeTemplate.delete()" );
		}
		return false;
	}
}
