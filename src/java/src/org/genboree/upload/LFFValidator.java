package org.genboree.upload;

import java.io.*;
import java.util.*;
import java.util.regex.*;
import org.genboree.dbaccess.*;

/**
 * This class validates the *.lff file. It will determine whether or not the input file
 * contains any errors found in the data.  The user will have the option of normalizing
 * the data by toggling the "doNormalize" boolean variable.
 *
 * @author                  Andrew Jackson (original), Ming-Te Cheng (Java version)
 * @version                 1.0 
 * @since                   1.4.2
 */
public class LFFValidator {

    //------------------------------------------------------------
    // regular expressions

    /**
     * Dot value regular expression.
     */
    static protected final String DOT_RE        = "^[\\.]";

    /** 
     * Blank line regular expression.
     */
    static protected final String BLANK_RE      = "^\\s*$";

    /**
     * Comment line regular expression.
     */
    static protected final String COMMENT_RE    = "^\\s*#";

    /**
     * Header line regular expression.
     */
    static protected final String HEADER_RE     = "^\\s*\\[";

    /** 
     * Integer value regular expression.
     */
    static protected final String DIGIT_RE      = "^\\d+$";

    /**
     * Number value regular expression.
     */
    static protected final String NUM_SCR_RE    = "^\\-?\\d+(?:\\.\\d+)?(?:e(?:\\+|\\-)?\\d+)?$";

    /**
     * Improper exponent value (starts with "e" instead of "1e") regular expression.
     */
    static protected final String BAD_SCI_RE    = "^e(?:\\+|\\-)\\d+";

    /**
     * Strand value regular expression.
     */
    static protected final String STRAND_RE     = "^[\\+\\-\\.]$";

    /** 
     * Phase value regular expression.
     */
    static protected final String PHASE_RE      = "^[012\\.]$";

    /**
     * Match all value regular expression.
     */
    static protected final String MATCH_ALL_RE  = "^.*$";


    /**
     * Compiled dot value regular expression pattern.
     */
    static protected final Pattern compiledDOT_RE = Pattern.compile( DOT_RE );

    /**
     * Compiled blank line regular expression pattern.
     */
    static protected final Pattern compiledBLANK_RE = Pattern.compile( BLANK_RE );

    /**
     * Compiled comment line regular expression pattern.
     */
    static protected final Pattern compiledCOMMENT_RE = Pattern.compile( COMMENT_RE );

    /**
     * Compiled header line regular expression pattern.
     */
    static protected final Pattern compiledHEADER_RE = Pattern.compile( HEADER_RE );

    /**
     * Compiled integer value regular expression pattern.
     */
    static protected final Pattern compiledDIGIT_RE = Pattern.compile( DIGIT_RE );

    /**
     * Compiled number value regular expression pattern.
     */
    static protected final Pattern compiledNUM_SCR_RE = Pattern.compile( NUM_SCR_RE );

    /**
     * Compiled improper exponent value (starts with "e" instead of "1e") regular expression pattern.
     */
    static protected final Pattern compiledBAD_SCI_RE = Pattern.compile( BAD_SCI_RE );

    /**
     * Compiled strand value regular expression pattern.
     */
    static protected final Pattern compiledSTRAND_RE = Pattern.compile( STRAND_RE );

    /**
     * Compiled phase value regular expression pattern.
     */
    static protected final Pattern compiledPHASE_RE = Pattern.compile( PHASE_RE );

    /**
     * Compiled match all value regular expression pattern.
     */
    static protected final Pattern compiledMATCH_ALL_RE = Pattern.compile( MATCH_ALL_RE );

    //------------------------------------------------------------
    // error and warning variables

    /*
    static protected final int FATAL            = 1;
    static protected final int OK               = 0;
    static protected final int OK_WITH_ERRORS   = 2;
    static protected final int FAILED           = 3;
    static protected final int USAGE_ERROR      = 16;
    static protected final int NEG_ORDER        = 0;
    static protected final int POS_ORDER        = 1;
    */

    /**
     * Array list of collected errors found.
     */
    protected ArrayList errorList;

    /**
     * Array list of collected warnings found.
     */
    protected ArrayList warningList;

    /**
     * Array list of collected reference sequence errors found in specific reference point.
     */
    protected ArrayList referenceSequenceErrorList;

    /**
     * Array list of collected annotation errors found in specific annotation.
     */
    protected ArrayList annotationErrorList;

    /**
     * Array list of collected assembly errors found in specific assembly.
     */
    protected ArrayList assemblyErrorList;

    /**
     * Array list of collected normalization warnings found in specific annotation.
     */
    protected ArrayList normalizationWarningList;

    /**
     * Maximum number of errors allowed.
     */
    protected int maxNumErrs                  = 150;

    /**
     * Maximum number of warning allowed.
     */
    protected int maxNumWarnings              = 150;

    /**
     * Maximum number of errors allowed on e-mail message.
     */
    protected int maxEMailErrs                = 25;

    /**
     * Maximum number of warnings allowed on e-mail message.
     */
    protected int maxEMailWarnings            = 25;

    /**
     * Maximum e-mail message size allowed.
     */
    protected int maxEMailSize                = 30000;

    /**
     * Gets the maximum number of errors allowed.
     * @return The maximum number of errors allowed.
     */
    public int getMaxNumErrors() { return maxNumErrs; }

    /**
     * Sets the maximum number of errors to be allowed.
     * @param maxNumErrs The maximum number of errors to be sllowed.
     */
    public void setMaxNumErrors( int maxNumErrs ) { this.maxNumErrs = maxNumErrs; }

    /**
     * Gets the list of errors found.
     * @return The list of errors found.
     */
    public ArrayList getErrorList() { return errorList; }

    /**
     * Gets the number of errors found.
     * @return The number of errors found.
     */
    public int getNumErrors() { return errorList.size(); }

    /**
     * Check if there are too many errors found.
     * @return There are too many errors found.
     */
    public boolean tooManyErrors() { return getNumErrors() >= getMaxNumErrors(); }

    /**
     * Adds error message to error list.
     * @param error The error message.
     * @throws ErrorsOverflowException If there are too many errors found.
     */
    public void addError( String error ) throws ErrorsOverflowException
    {
	if ( errorList == null )
	    errorList = new ArrayList();

	if ( tooManyErrors() == false )
	    errorList.add( stringBuffer.toString() );
	else
	    throw new ErrorsOverflowException();
    }

    /**
     * Lists specified number of errors found from error list.
     * @param maxErrorsToReport    The maximum number of errors to report.
     * @return                     The errors found as a string.
     */
    public String getErrorListAsString( int maxErrorsToReport )
    {	
	stringBuffer.setLength( 0 );	

	for ( int i = 0; i < maxErrorsToReport; i++ )
	    stringBuffer.append( (String) errorList.get( i ) + "\n" );

	return stringBuffer.toString();
    }
    
    /**
     * Lists the errors found from error list.
     * @return The errors found as a string.
     */
    public String getErrorListAsString()
    {
	return getNumErrors() < maxNumErrs ? getErrorListAsString( errorList.size() ) : getErrorListAsString( maxNumErrs );
    }

    /**
     * Gets the maximum number of warnings allowed.
     * @return The maximum number of warnings allowed.
     */
    public int getMaxNumWarnings() { return maxNumWarnings; }

    /**
     * Sets the maximum number of warnings to be allowed.
     * @param maxNumWarnings The maximum number of warnings to be allowed.
     */
    public void setMaxNumWarnings( int maxNumWarnings ) { this.maxNumWarnings = maxNumWarnings; }

    /**
     * Gets the list of warnings found.
     * @return The list of warnings found.
     */
    public ArrayList getWarningList() { return warningList; }

    /**
     * Gets the number of warnings found.
     * @return The number of warnings found.
     */
    public int getNumWarnings() { return warningList.size(); }

    /**
     * Check if there are too many warnings found.
     * @return There are too many warnings found.
     */
    public boolean tooManyWarnings() { return getNumWarnings() >= getMaxNumWarnings(); }

    /**
     * Adds warning message to warning list.
     * @param warning The warning message.
     * @throws WarningsOverflowException If there are too many warnings found.
     */
    public void addWarning( String warning ) throws WarningsOverflowException
    {
	if ( warningList == null )
	    warningList = new ArrayList();

	if ( tooManyWarnings() == false )
	    warningList.add( stringBuffer.toString() );
	else
	    throw new WarningsOverflowException();
    }

    /** 
     * Lists specified number of warnings found from warning list.
     * @param maxWarningsToReport    The maximum number of warnings to report.
     * @return                       The warnings found as a string.
     */
    public String getWarningListAsString( int maxWarningsToReport )
    {
	//StringBuffer stringBuffer = new StringBuffer();
	stringBuffer.setLength( 0 );

	for ( int i = 0; i < maxWarningsToReport; i++ )
	    stringBuffer.append( (String) warningList.get( i ) + "\n" );

	return stringBuffer.toString();
    }
    
    /**
     * Lists the warnings found from warning list.
     * @return The warnings found as a string.
     */
    public String getWarningListAsString()
    {
	return getNumWarnings() < maxNumWarnings ? getWarningListAsString( warningList.size() ) : getWarningListAsString( maxNumWarnings );
    }

    /**
     * Sets the maximum number of errors to be allowed on e-mail message.
     * @param maxEMailErrs The maximum number of e-mail errors to be allowed.
     */
    public void setMaxEMailErrors( int maxEMailErrs ) { this.maxEMailErrs = maxEMailErrs; }

    /**
     * Sets the maximum number of warnings to be allowed on e-mail message.
     * @param maxEMailWarnings The maximum number of e-mail warnings to be allowed.
     */
    public void setMaxEMailWarnings( int maxEMailWarnings ) { this.maxEMailWarnings = maxEMailWarnings; }

    /**
     * Sets the maximum size of e-mail message allowed.
     * @param maxEMailSize The maximum size of e-mail message allowed.
     */
    public void setMaxEMailSize( int maxEMailSize ) { this.maxEMailSize = maxEMailSize; }

    //------------------------------------------------------------
    // for reference: lff fields:
    // classID, tName, typeId, subtype, refName, rStart, rEnd, orientation, phase, scoreField, tStart, tEnd

    /** 
     * Index number referring to the location of "class" column under the [annotations] portion of the *.lff file.
     */
    static protected final int CLASSID          = 0;

    /** 
     * Index number referring to the location of "name" column  under the [annotations] portion of the *.lff file.
     */
    static protected final int TNAME            = 1;

    /** 
     * Index number referring to the location of "type" column under the [annotations] portion of the *.lff file.
     */    
    static protected final int TYPEID           = 2;

    /** 
     * Index number referring to the location of "subtype" column under the [annotations] portion of the *.lff file.
     */
    static protected final int SUBTYPE          = 3;

    /** 
     * Index number referring to the location of "ref" column under the [annotations] portion of the *.lff file.
     */
    static protected final int REFNAME          = 4;

    /** 
     * Index number referring to the location of "start" column under the [annotations] portion of the *.lff file.
     */
    static protected final int RSTART           = 5;

    /** 
     * Index number referring to the location of "stop" column under the [annotations] portion of the *.lff file.
     */
    static protected final int REND             = 6;

    /** 
     * Index number referring to the location of "strand" column under the [annotations] portion of the *.lff file.
     */
    static protected final int STRAND           = 7;

    /** 
     * Index number referring to the location of "phase" column under the [annotations] portion of the *.lff file.
     */
    static protected final int PHASE            = 8;

    /** 
     * Index number referring to the location of "score" column under the [annotations] portion of the *.lff file.
     */
    static protected final int SCORE            = 9;

    /** 
     * Index number referring to the location of "tstart" column under the [annotations] portion of the *.lff file.
     */
    static protected final int TSTART           = 10;

    /** 
     * Index number referring to the location of "tend" column under the [annotations] portion of the *.lff file.
     */
    static protected final int TEND             = 11;

    //------------------------------------------------------------
    // hashtable of valid entrypoints (refseqs)

    /**
     * Hash table containing all the valid reference sequences.
     */
    protected Hashtable validRefSeqs;

    //------------------------------------------------------------
    // normalization toggle

    /**
     * Toggle value of whether the *.lff file validator should normalize the data.
     */
    protected boolean doNormalize         = true;

    /**
     * Sets toggle value of normalizing data.
     * @param doNormalize Toggle value of normalizing data (true/false).
     */
    public void setDoNormalize( boolean doNormalize ) { this.doNormalize = doNormalize; }

    //------------------------------------------------------------
    // all-purpose string buffer

    /**
     * All-purpose string buffer.
     */
    protected StringBuffer stringBuffer   = new StringBuffer( 200 );

    //------------------------------------------------------------
    // helper methods

    /**
     * Validates a reference sequence (entry point) record, provided as an array list.
     * @param fields                     Array list of fields containing the reference sequence (entry point) record.
     * @return                           Errors are found in reference sequence (entry point) record.
     * @throws ErrorsOverflowException   If there are too many errors found.
     */
    public boolean validateRefSeq( ArrayList fields ) throws ErrorsOverflowException
    {
	//	StringBuffer errorMessage = new StringBuffer();	
	stringBuffer.setLength( 0 );
	
	referenceSequenceErrorList = new ArrayList();
	ArrayList strippedFields = new ArrayList();
	
	// trim trailing/leading whitespace.
	for ( int i = 0; i < fields.size(); i++ )
	    strippedFields.add( ( (String) fields.get( i ) ).trim() );

	// check if it has the correct number of fields.  If not, might as well stop now.
	if ( !( strippedFields.size() == 3 ) )
	    {
		stringBuffer.setLength( 0 );
		stringBuffer.append( "Not an LFF [reference] record. It only has " );
		stringBuffer.append( strippedFields.size() );
		stringBuffer.append( " field(s) but should have 3." );
		referenceSequenceErrorList.add( stringBuffer.toString() );
	    }
	else
	    {
		// check if the 2nd column contains chromosome.
		if ( !( ( (String) strippedFields.get( 1 ) ).toLowerCase().equals( "chromosome" ) ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "2nd column must be the keyword 'Chromosome', which means 'Top Level Ref Sequence Entrypoint'" );
			referenceSequenceErrorList.add( stringBuffer.toString() );
		    }
		
		// check that the 3rd column looks like a positive integer.
		if ( !( compiledDIGIT_RE.matcher( (String) strippedFields.get( 2 ) ).find() &&
			Integer.parseInt( (String) strippedFields.get( 2 ) ) > 0 ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "3rd column must be an integer that is the RefSeq length." );
			referenceSequenceErrorList.add( stringBuffer.toString() );
		    }
	    }

	if ( referenceSequenceErrorList.size() > 0 )
	    {
		stringBuffer.setLength( 0 );

		for ( int i = 0; i < referenceSequenceErrorList.size(); i++ )
		    {
			stringBuffer.append( "\n - " );
			stringBuffer.append( (String) referenceSequenceErrorList.get( i ) );
		    }

		addError( stringBuffer.toString() );
	    }

	return referenceSequenceErrorList.isEmpty() ? true : false;
    }

    /**
     * Validates an annotation record, provided as an array list.
     * @param fields                      Array list of fields containing the annotation record.
     * @return                            Errors are found in annotation record.
     * @throws ErrorsOverflowException    If there are too many errors found.
     */
    public boolean validateAnnotation( ArrayList fields ) throws ErrorsOverflowException
    {
	stringBuffer.setLength( 0 );

	annotationErrorList = new ArrayList();
	ArrayList strippedFields = new ArrayList();

	// trim trailing/leading whitespace.
	for ( int i = 0; i < fields.size(); i++ )
	    strippedFields.add( ( (String) fields.get( i ) ).trim() );

	// check if it has the correct number of fields.  If not, might as well stop now.
	if ( !( strippedFields.size() == 10 || strippedFields.size() == 12 ) )
	    {
		stringBuffer.setLength( 0 );
		stringBuffer.append( "This LFF record has " );
		stringBuffer.append( strippedFields.size() ) ;
		stringBuffer.append( " fields." );
		annotationErrorList.add( stringBuffer.toString() );
		stringBuffer.setLength( 0 );
		stringBuffer.append( "LFF records are <TAB> delimited and have either 10 or 12 fields." );
		annotationErrorList.add( stringBuffer.toString() );
		stringBuffer.setLength( 0 );
		stringBuffer.append( "Space characters are not tabs." );
		annotationErrorList.add( stringBuffer.toString() );
	    }
	else
	    {
		// we have a hashtable of valid refseqs, check against it.
		if ( !( validRefSeqs == null ) )
		    {
			// assuming that the names are case-sensitive 
			Integer length = (Integer) validRefSeqs.get( (String) strippedFields.get( REFNAME ) );
			
			if ( length == null )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "referring to unknown reference sequence entrypoint '" );
				stringBuffer.append( (String) strippedFields.get( REFNAME ) );
				stringBuffer.append( "'" );
				annotationErrorList.add( stringBuffer.toString() );
			    }
			else
			    {	  							    					
				// found correct refseq, but is coords ok?
				if ( ( compiledDIGIT_RE.matcher( (String) strippedFields.get( REND ) ).find() ) &&
				     ( Integer.parseInt( (String) strippedFields.get( REND ) ) > length.intValue() ) )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "end of annotation " );
					stringBuffer.append( (String) strippedFields.get( REND ) );
					stringBuffer.append( " is beyond end of reference sequence " );
					stringBuffer.append( length.intValue() );
					stringBuffer.append( "." );
					annotationErrorList.add( stringBuffer.toString() );
					
				    }
				
				if ( ( compiledDIGIT_RE.matcher( (String) strippedFields.get( RSTART ) ).find() ) &&
				     ( Integer.parseInt( (String) strippedFields.get( RSTART ) ) > length.intValue() ) )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "start of annotation " );
					stringBuffer.append( (String) strippedFields.get( RSTART ) );
					stringBuffer.append( " is beyond end of reference sequence " );
					stringBuffer.append( length.intValue() );
					stringBuffer.append( "." );
					annotationErrorList.add( stringBuffer.toString() );
				    }
			    }
		    }
		    

		// check that the name column is not too long.
		if ( ( (String) strippedFields.get( TNAME ) ).length() > 200 )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the name '" );
			stringBuffer.append( (String) strippedFields.get( TNAME ) );
			stringBuffer.append( "' is too long." );
			annotationErrorList.add( stringBuffer.toString() );
		    }

		// check the strand column.
		if ( !( compiledSTRAND_RE.matcher( (String) strippedFields.get( STRAND ) ).find() ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the strand column contains '" );
			stringBuffer.append( (String) strippedFields.get( STRAND ) );
			stringBuffer.append( "' and not +, -, or ." );
			annotationErrorList.add( stringBuffer.toString() );			
		    }

		// check the phase column.
		if ( !( compiledPHASE_RE.matcher( (String) strippedFields.get( PHASE ) ).find() ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the phase column contains '" );
			stringBuffer.append( (String) strippedFields.get( PHASE ) );
			stringBuffer.append( "' and not 0, 1, 2, or ." );
			annotationErrorList.add( stringBuffer.toString() );
		    }
		

		// check start coordinates
		if ( !( compiledDIGIT_RE.matcher( (String) strippedFields.get( RSTART ) ).find() ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the start column contains '" );
			stringBuffer.append( (String) strippedFields.get( RSTART ) );
			stringBuffer.append( "' and not a positive integer." );
			annotationErrorList.add( stringBuffer.toString() );

			stringBuffer.setLength( 0 );
			stringBuffer.append( "reference sequence coordinates should start at 1." );
			annotationErrorList.add( stringBuffer.toString() );

			stringBuffer.setLength( 0 );
			stringBuffer.append( "bases at negative or fractional cooordinates are not supported." );
			annotationErrorList.add( stringBuffer.toString() );
		    }

		// check end coordinates
		if ( !( compiledDIGIT_RE.matcher( (String) strippedFields.get( REND ) ).find() ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the end column contains '" );
			stringBuffer.append( (String) strippedFields.get( REND ) );
			stringBuffer.append( "' and not a positive integer." );
			annotationErrorList.add( stringBuffer.toString() );

			stringBuffer.setLength( 0 );
			stringBuffer.append( "reference sequence coordinates should start at 1." );
			annotationErrorList.add( stringBuffer.toString() );			

			stringBuffer.setLength( 0 );
			stringBuffer.append( "bases at negative or fractional coordinates are not supported." );
			annotationErrorList.add( stringBuffer.toString() );
		    }

		// check the score
		if ( !( compiledNUM_SCR_RE.matcher( (String) strippedFields.get( SCORE ) ).find() ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "the score column contains '" );
			stringBuffer.append( (String) strippedFields.get( SCORE ) );
			stringBuffer.append( "' and not an integer or real number or ." );
			annotationErrorList.add( stringBuffer.toString() );

		    }

		// check tstart/tend coordinates
		if ( strippedFields.size() == 12 )
		    {
			if ( !( ( (String) strippedFields.get( TSTART ) ).equals( "." ) ||
				( compiledDIGIT_RE.matcher( (String) strippedFields.get( TSTART ) ).find() &&
				  Integer.parseInt( (String) strippedFields.get( TSTART ) ) >= 0 
				  )
				) 
			     )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "the tstart column contains '" );
				stringBuffer.append( (String) strippedFields.get( TSTART ) );
				stringBuffer.append( "' and not a positive integer." );
				annotationErrorList.add( stringBuffer.toString() );

				stringBuffer.setLength( 0 );
				stringBuffer.append( "reference sequence coordinates should start at 1." );
				annotationErrorList.add( stringBuffer.toString() );

				stringBuffer.setLength( 0 );
				stringBuffer.append( "bases at negative or fractional coordinates are not supported." );
				annotationErrorList.add( stringBuffer.toString() );
			    }

			if ( !( ( (String) strippedFields.get( TEND ) ).equals( "." ) ||
				( compiledDIGIT_RE.matcher( (String) strippedFields.get( TEND ) ).find() &&
				  Integer.parseInt( (String) strippedFields.get( TEND ) ) >= 0 
				  )
				) 
			     )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "the tend column contains '" );
				stringBuffer.append( (String) strippedFields.get( TEND ) );
				stringBuffer.append( "' and not a positive integer." );
				annotationErrorList.add( stringBuffer.toString() );

				stringBuffer.setLength( 0 );
				stringBuffer.append( "reference sequence coordinates should start at 1." );
				annotationErrorList.add( stringBuffer.toString() );

				stringBuffer.setLength( 0 );
				stringBuffer.append( "bases at negative or fractional coordinates are not supported." );
				annotationErrorList.add( stringBuffer.toString() );
			    }
		    }		



		// check if any fields are emtpy that shouldn't be.
		boolean anyEmpty = false;
		for ( int i = 0; i < strippedFields.size(); i++ )
		    {
			if ( compiledBLANK_RE.matcher( (String) strippedFields.get( i ) ).find() )
			    {
				anyEmpty = true;
				break;
			    }
			else if ( ( (String) strippedFields.get( i ) ).equals( "." ) && i != STRAND && i != PHASE )
			    strippedFields.set( i, null );			    
		    }	       
		if ( anyEmpty == true )
		    annotationErrorList.add( new String( "some of the fields are empty and this is not allowed." ) );
	    }

	if ( annotationErrorList.size() > 0 )
	    {
		stringBuffer.setLength( 0 );

		for ( int i = 0; i < annotationErrorList.size(); i++ )
		    stringBuffer.append( "\n - " + (String) annotationErrorList.get( i ) );
		    
		addError( stringBuffer.toString() );	   		
	    }

	return annotationErrorList.isEmpty() ? true : false;
    }

    /**
     * Normalizes an annotation record, provided as an array list.
     * @param fields                       Array list of fields containing the annotation record to be normalized.
     * @return                             Array list of fields containing the normalized annotation record.
     * @throws WarningsOverflowException   If there are too many warnings found.
     */
    public ArrayList normalizeAnnotation( ArrayList fields ) throws WarningsOverflowException
    {
	stringBuffer.setLength( 0 );
	
	ArrayList strippedFields = fields;
	normalizationWarningList = new ArrayList();
	    
	if ( strippedFields.size() == 10 || strippedFields.size() == 12 )
	    {
		if ( validRefSeqs != null )
		    {
			Integer length  = (Integer) validRefSeqs.get( (String) strippedFields.get( REFNAME ) );

			// find end of reference sequence
			if ( length != null )
			    {				
				// found correct refseq, but is coords ok?
				if ( ( compiledDIGIT_RE.matcher( (String) strippedFields.get( REND ) ).find() ) &&
				     ( Integer.parseInt( (String) strippedFields.get( REND ) ) > length.intValue() ) )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "end of annotation " );
					stringBuffer.append( (String) strippedFields.get( REND ) );
					stringBuffer.append( " is beyond end of reference sequence " );
					stringBuffer.append( length.intValue() );
					stringBuffer.append( "." );
					normalizationWarningList.add( stringBuffer.toString() );
						
					stringBuffer.setLength( 0 );
					stringBuffer.append( "annotation was truncated." );
					normalizationWarningList.add( stringBuffer.toString() );

					strippedFields.set( REND, length.toString() );
				    }
				if ( ( compiledDIGIT_RE.matcher( (String) strippedFields.get( RSTART ) ).find() ) &&
				     ( Integer.parseInt( (String) strippedFields.get( RSTART ) ) > length.intValue() ) )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "start of annotation " );
					stringBuffer.append( (String) strippedFields.get( RSTART ) );
					stringBuffer.append( " is beyond end of reference sequence " );
					stringBuffer.append( length.intValue() );
					stringBuffer.append( "." );
					normalizationWarningList.add( stringBuffer.toString() );

					stringBuffer.setLength( 0 );
					stringBuffer.append( "annotation was truncated." );
					normalizationWarningList.add( stringBuffer.toString() );

					strippedFields.set( RSTART, length.toString() );
				    }
			    }   
		    }

		// fix score column if it starts with just 'e'...which means 1e, presumably
		if ( compiledBAD_SCI_RE.matcher( (String) strippedFields.get( SCORE ) ).find() )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "score value starts with e. Replaced with 1e." );
			normalizationWarningList.add( stringBuffer.toString() );

			strippedFields.set( SCORE, new String( "1" + strippedFields.get( SCORE ) ) );				
		    }
		
		// fix score column if it is just '.'
		if ( ( (String) strippedFields.get( SCORE ) ).equals( "." ) )
		    {
			stringBuffer.setLength( 0 );
			stringBuffer.append( "score value with '.'.  Replaced with 0." );
			normalizationWarningList.add( stringBuffer.toString() );

			strippedFields.set( SCORE, new String( "0" ) );		
		    }

		// convert 0 coordinates to 1
		if ( compiledDIGIT_RE.matcher( (String) strippedFields.get( RSTART ) ).find() )
		    {
			if ( Integer.parseInt( (String) strippedFields.get( RSTART ) ) == 0 )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "start value set from 0 to 1." );
				normalizationWarningList.add( stringBuffer.toString() );

				strippedFields.set( RSTART, new String( "1" ) );
			    }
		    }
		if ( compiledDIGIT_RE.matcher( (String) strippedFields.get( REND ) ).find() )
		    {
			if ( Integer.parseInt( (String) strippedFields.get( REND ) ) == 0 )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "end value set from 0 to 1." );
				normalizationWarningList.add( stringBuffer.toString() );

				strippedFields.set( REND, new String( "1" ) );
			    }
		    }
			
		// normalize start < end
		if ( compiledDIGIT_RE.matcher( (String) strippedFields.get( RSTART ) ).find() &&
		     compiledDIGIT_RE.matcher( (String) strippedFields.get( REND ) ).find() )
		    {
			if ( Integer.parseInt( (String) strippedFields.get( RSTART ) ) >
			     Integer.parseInt( (String) strippedFields.get( REND ) ) )
			    {
				stringBuffer.setLength( 0 );
				stringBuffer.append( "start value greater than end value. Normalized to start < end." );
				normalizationWarningList.add( stringBuffer.toString() );
			    }
				

			int minimum = Math.min( Integer.parseInt( (String) strippedFields.get( RSTART ) ),
						Integer.parseInt( (String) strippedFields.get( REND ) )
						);
			int maximum = Math.max( Integer.parseInt( (String) strippedFields.get( RSTART ) ),
						Integer.parseInt( (String) strippedFields.get( REND ) )
						);

			strippedFields.set( RSTART, Integer.toString( minimum ) );
			strippedFields.set( REND, Integer.toString( maximum ) );
		    }
			
		if ( strippedFields.size() == 12 )
		    {
			if ( ( (String) strippedFields.get( TSTART ) ).equals( "." ) ||
			     ( compiledDIGIT_RE.matcher( (String) strippedFields.get( TSTART ) ).find() &&
			       Integer.parseInt( (String) strippedFields.get( TSTART ) ) >= 0 
			       )
			     )
			    {
				if ( ( (String) strippedFields.get( TSTART ) ).equals( "." ) == false &&
				     ( Integer.parseInt( (String) strippedFields.get( TSTART ) ) == 0 ) 
				     )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "tstart value set from 0 to 1." );
					normalizationWarningList.add( stringBuffer.toString() );

					strippedFields.set( TSTART, new String( "1" ) );			    
				    }
			    }

			if ( ( (String) strippedFields.get( TEND ) ).equals( "." ) ||
			     ( compiledDIGIT_RE.matcher( (String) strippedFields.get( TEND ) ).find() &&
			       Integer.parseInt( (String) strippedFields.get( TEND ) ) >= 0 
			       )
			     )
			    {
				if ( ( (String) strippedFields.get( TEND ) ).equals( "." ) == false &&
				     ( Integer.parseInt( (String) strippedFields.get( TEND ) ) == 0 )
				     )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "tend value set from 0 to 1." );
					normalizationWarningList.add( stringBuffer.toString() );

					strippedFields.set( TEND, new String( "1" ) );
				    }
			    }

			// normalize tstart < tend
			if ( ( compiledDIGIT_RE.matcher( (String) strippedFields.get( TSTART ) ).find() &&
			       Integer.parseInt( (String) strippedFields.get( TSTART ) ) >= 0 
			       ) &&
			     ( compiledDIGIT_RE.matcher( (String) strippedFields.get( TEND ) ).find() &&
			       Integer.parseInt( (String) strippedFields.get( TEND ) ) >= 0 
			       ) )
			    {
				if ( Integer.parseInt( (String) strippedFields.get( TSTART ) ) >
				     Integer.parseInt( (String) strippedFields.get( TEND ) ) )
				    {
					stringBuffer.setLength( 0 );
					stringBuffer.append( "tstart value greater than tend value. Normalized to tstart < tend." );
					normalizationWarningList.add( stringBuffer.toString() );

				    }

				int minimum = Math.min( Integer.parseInt( (String) strippedFields.get( TSTART ) ),
							Integer.parseInt( (String) strippedFields.get( TEND ) )
							);
				int maximum = Math.max( Integer.parseInt( (String) strippedFields.get( TSTART ) ),
							Integer.parseInt( (String) strippedFields.get( TEND ) )
							);					

				strippedFields.set( TSTART,Integer.toString( minimum ) );
				strippedFields.set( TEND, Integer.toString( maximum ) );
			    }
		    }			     					
	    }

	if ( normalizationWarningList.size() > 0 )
	    {
		stringBuffer.setLength( 0 );

		for ( int i = 0; i < normalizationWarningList.size(); i++ )
		    stringBuffer.append( "\n - " + (String) normalizationWarningList.get( i ) );

		addWarning( stringBuffer.toString() );
	    }	            

	return strippedFields;
    }


    //------------------------------------------------------------
    // methods

    /**
     * Constructs LFFValidator class without a specific hash table containing valid reference sequence names (default constructor).
     */
    public LFFValidator() { }

    /**
     * Constructs LFFValidator class with a specific hash table containing valid reference sequence names.
     */
    public LFFValidator( Hashtable validRefSeqNames ) {
	this.validRefSeqs = validRefSeqNames;
    }	

    /**
     * Validates whole LFF file.  The file may contain a reference sequence section, an assembly section (currently ignored),
     * and/or an annotation section.
     * @param inFile                         Input *.lff file to be validated.
     * @return                               The number of errors found in *.lff file.
     */
    public int validateLFFFile( File inFile )
    {
	// we will collect the warnings and errors in the file here:
	errorList = new ArrayList();
	warningList = new ArrayList();


	try {

	    // loop over each line of the file.
	    int lineNumber = 0;
	    BufferedReader bIn = new BufferedReader( new FileReader( inFile ) );
	    StringBuffer sBuffer = new StringBuffer( 200 );
	    String [] fieldsStringArray = null;
	    ArrayList fields = new ArrayList();
	    while ( ( ( sBuffer.append( bIn.readLine() ) ).toString() ).equals( "null" ) == false )
		{		    
		    lineNumber++;

		    // skip blank lines, comment lines, [header] lines.
		    if ( !( compiledBLANK_RE.matcher( sBuffer.toString() ).find() ||
			    compiledCOMMENT_RE.matcher( sBuffer.toString() ).find() ||
			    compiledHEADER_RE.matcher( sBuffer.toString() ).find() ) 
			 )
			{			
			    fields.clear();

			    fieldsStringArray = sBuffer.toString().split( "\t" );			   

			    for ( int i = 0; i < fieldsStringArray.length; i++ )
				{						    
				    if ( fieldsStringArray[i].length() != 0 )
					fields.add( fieldsStringArray[i] );
				}

			    // now parse the record according to its type:
			    
			    // SECTION = [reference_points] ?
			    if ( fields.size() == 3 )
				{				    
				    //----------------------------------------------------------------------------------------------
				    // check for errors
				    // is the reference record ok? In this version, the return value
				    // is either true or false.
				    boolean isRefValid = this.validateRefSeq( fields );
				    
				    if ( !( isRefValid == true ) ) // then we found some errors in the line.
					{
					    
					    // convert the list of errors into a string by concatenating them after
					    // after the "title".  Then add this line's error string to the list
					    // of errors in the file.   					
					    stringBuffer.setLength( 0 );
					    stringBuffer.append( "(ERROR) Line #" );
					    stringBuffer.append( lineNumber );
					    stringBuffer.append( ":" );
					    stringBuffer.append( " bad reference sequence record. Details:" );		    
					    stringBuffer.append( (String) errorList.get( errorList.size() - 1 ) );
					    
					    errorList.set( errorList.size() - 1, stringBuffer.toString() );
					}

				    //----------------------------------------------------------------------------------------------	    
				}
			    
			    // SECTION = [assembly] ?
			    else if ( fields.size() == 7 )
				{

				}

			    // SECTION = [annotations] ?
			    else if ( fields.size() == 10 || fields.size() == 12 )
				{							   			
				    //----------------------------------------------------------------------------------------------
				    // try normalization	    
				    // is the reference record ok? In this version, the return value
				    // is either true or false.
				    if ( doNormalize == true )
					{
					    try
						{
						    int oldWarningListSize = warningList.size();
						    fields = this.normalizeAnnotation( fields );				    
						    
						    // convert the list of warnings into a string by concatenating them after
						    // after the "title".  Then add this line's error string to the list
						    // of errors in the file. 
						    if ( oldWarningListSize < warningList.size() )
							{
							    stringBuffer.setLength( 0 );
							    stringBuffer.append( "(WARNING) Line #" + lineNumber + ": Details: " );
							    
							    stringBuffer.append( (String) warningList.get( warningList.size() - 1 ) );
							    
							    warningList.set( warningList.size() - 1, stringBuffer.toString() );
							}
						}
					    catch ( WarningsOverflowException ex )
						{
						    stringBuffer.setLength( 0 );
						    
						    if ( getNumWarnings() > 0 )
							{
							    stringBuffer.append( (String) warningList.get( warningList.size() - 1 ) );
							    stringBuffer.append( "\nTOO MANY WARNINGS FOUND, VALIDATION TERMINATED." );
							    warningList.set( warningList.size() - 1, stringBuffer.toString() );
							}
						    else
							System.out.println( "TOO MANY WARNINGS FOUND, VALIDATION TERMINATED." );

						    doNormalize = false;
						}				
					}

				    //----------------------------------------------------------------------------------------------
				    // check for errors
				    boolean isAnnoValid = this.validateAnnotation( fields );
				    
				    if ( !( isAnnoValid == true ) ) // then we found some errors in the line.
					{	
					    stringBuffer.setLength( 0 );
					    stringBuffer.append( "(ERROR) Line #" + lineNumber + ":" + " bad annotation record. Details: " );
					    stringBuffer.append( (String) errorList.get( errorList.size() - 1 ) );
					    errorList.set( errorList.size() - 1, stringBuffer.toString() );
					}
				    
				    //----------------------------------------------------------------------------------------------    			       
				}
			    
			    // SECTION = ?????? ERROR!!!!
			    else
				{
				    // make an error string for this ill-formed record, add it to the error list, and move
				    // on to the next line.
				    stringBuffer.setLength( 0 );
				    stringBuffer.append( "(ERROR) Line #" );
				    stringBuffer.append( lineNumber );
				    stringBuffer.append( ":  bad LFF record. Details:" );
				    stringBuffer.append( "\n - incorrect number of columns. " );
				    stringBuffer.append( "You have " );
				    stringBuffer.append( fields.size() );
				    stringBuffer.append( " field(s). Should be 3, 7, 10 or 12 depending on the section." );

				    addError( stringBuffer.toString() );
				}			    
			}

		    sBuffer.setLength( 0 );

		}
	    bIn.close();
	}
	catch ( ErrorsOverflowException ex )
	    {
		stringBuffer.setLength( 0 );
		
		if ( getNumErrors() > 0 )
		    {
			stringBuffer.append( (String) errorList.get( errorList.size() - 1 ) );
			stringBuffer.append( "\nTOO MANY ERRORS FOUND, VALIDATION TERMINATED." );
			errorList.set( errorList.size() - 1, stringBuffer.toString() );
		    }
		else
		    System.out.println( "TOO MANY ERRORS FOUND, VALIDATION TERMINATED." );
	    }
	catch ( Exception ex ) {
	    ex.printStackTrace();
	}

	
        return getNumErrors();
    }
    
    /**
     * Outputs error list and number of errors found in *.lff file (will also output warning list and number of warnings found if normalization was declared 'true').
     * @return List of errors and number of errors found (and list of warning warnings and number of warnings found if normalization was declared 'true').
     */
    public String toString()
    {
	StringBuffer outputBuffer = new StringBuffer();
	
	if ( doNormalize == true || ( doNormalize == false && getNumWarnings() > 0 ) )
	    outputBuffer.append( new String( getWarningListAsString() ) );
	
	outputBuffer.append( new String( getErrorListAsString() ) );

	if ( doNormalize == true || ( doNormalize == false && getNumWarnings() > 0 ) )
	    outputBuffer.append( new String( "Number of warnings found: " + getNumWarnings() + "\n" ) );
	
	outputBuffer.append( new String( "Number of errors found: " + getNumErrors() + "\n" ) );

	return outputBuffer.toString();
    }
}
