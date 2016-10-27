require 'brl/genboree/dbUtil'

# ------------------------------------------------------------------
# PUBLICATION RELATED TABLES - DBUtil Extension Methods for dealing with Publication-related tables
# ------------------------------------------------------------------
module BRL ; module Genboree
class DBUtil
  # --------
  # Table: publications
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_PUBLICATION_BY_ID = 'update publications set pmid = ?, type = ?, title = ?, authorList = ?, journal = ?, meeting = ?, date = ?, volume = ?, issue = ?, startPage = ?, endPage = ?, abstract = ?, meshHeaders = ?, url = ?, state = ?, language = ? where id = ?'
  UPDATE_WHOLE_PUBLICATION_BY_PMID = 'update publications set id = ?, type = ?, title = ?, authorList = ?, journal = ?, meeting = ?, date = ?, volume = ?, issue = ?, startPage = ?, endPage = ?, abstract = ?, meshHeaders = ?, url = ?, state = ?, language = ? where pmid = ?'
  SELECT_PUBLICATION_BY_YEAR_JOURNAL = "select * from publications where YEAR(date) = ? and journal = ?"
  SELECT_PUBLICATION_BY_YEAR = "select * from publications where YEAR(date) = ?"
  SELECT_PUBLICATION_BY_JOURNAL_VOLUME_ISSUE = "select * from publications where journal = ? and volume = ?"
  SELECT_ATTR_VALUE_BY_PUBLICATION_ID="select publicationAttrNames.name, publicationAttrValues.value from publicationAttrNames, publicationAttrValues, publication2attributes where" +
                                      " publication2attributes.publication_id = ? and publication2attributes.publicationAttrName_id = publicationAttrNames.id and publication2attributes.publicationAttrValue_id" +
                                      " = publicationAttrValues.id"
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Get all Publications records
  # [+returns+] Array of 0+ publications record rows
  def selectAllPublications()
    return selectAll(:userDB, 'publications', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Count all Publications records
  # [+returns+] 1 row with count
  def countPublications()
    return countRecords(:userDB, 'publications', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication record by its id
  # [+id+]      The ID of the publication record to return
  # [+returns+] Array of 0 or 1 studies record rows
  def selectPublicationsById(id)
    return selectByFieldAndValue(:userDB, 'publications', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications records using a list of ids
  # [+ids+]     Array of publication IDs
  # [+returns+] Array of 0+ publications records
  def selectPublicationsByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'publications', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication record by its pmid
  # [+pmid+]    The PMID of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByPMID(pmid)
    return selectByFieldAndValue(:userDB, 'publications', 'pmid', pmid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications records using a list of pmids
  # [+pmids+]   Array of publication IDs
  # [+returns+] Array of 0+ publications records
  def selectPublicationsByPMIds(pmids)
    return selectByFieldWithMultipleValues(:userDB, 'publications', 'pmid', pmids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication record by its title
  # [+title+]   The title of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByTitle(title)
    return selectByFieldAndValue(:userDB, 'publications', 'title', title, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication record by its journal
  # [+journal+] The journal of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByJournal(journal)
    return selectByFieldAndValue(:userDB, 'publications', 'journal', journal, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication record by its meeting
  # [+meeting+] The meeting of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByMeeting(meeting)
    return selectByFieldAndValue(:userDB, 'publications', 'meeting', meeting, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications using a keyword in the authorList (e.g. an author last name)
  # [+author+]  The authorList keyword (author) with which to select publications
  # [+returns+] Array of 0+ publications records
  def selectPublicationsByAuthorsKeyword(author)
    return selectByFieldAndKeyword(:userDB, 'publications', 'authorList', author, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications whose authorList match ALL or ANY of a list of keywords (e.g. some author last names, etc)
  # [+authors+]   Array of authorList keywords (authors)
  # [+booleanOp+] Flag indicating if ALL or ANY of the keywords (authors) must be matched in the authorList field
  # [+returns+]   Array of 0+ publications records
  def selectPublicationsByAuthorsKeywords(authors, booleanOp=:and)
    return selectByFieldWithMultipleKeywords(:userDB, 'publications', 'authorList', authors, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications using a keyword in meshHeader (e.g. some author last names, etc)
  # [+author+] The meshHeader keyword (author) with which to select publications
  # [+returns+] Array of 0+ publications records
  def selectPublicationsByMeshHeaderKeyword(author)
    return selectByFieldAndKeyword(:userDB, 'publications', 'meshHeaders', author, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications whose mesHeader match ALL or ANY of a list of keywords (e.g. some author last names, etc)
  # [+authors+]   Array of meshHeader keywords (authors)
  # [+booleanOp+] Flag indicating if ALL or ANY of the keywords (authors) must be matched in the mesHeader field
  # [+returns+]   Array of 0+ publications records
  def selectPublicationsByMeshHeaderKeywords(authors, booleanOp=:and)
    return selectByFieldWithMultipleKeywords(:userDB, 'publications', 'meshHeaders', authors, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications using a keyword in abstract (e.g. some author last names, etc)
  # [+author+]  The abstract keyword (author) with which to select publications
  # [+returns+] Array of 0+ publications records
  def selectPublicationsByAbstractKeyword(author)
    return selectByFieldAndKeyword(:userDB, 'publications', 'abstract', author, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications whose abstract match ALL or ANY of a list of keywords (e.g. some author last names, etc)
  # [+authors+]   Array of abstract keywords (authors)
  # [+booleanOp+] Flag indicating if ALL or ANY of the keywords (authors) must be matched in the abstract field
  # [+returns+]   Array of 0+ publications records
  def selectPublicationsByAbstractKeywords(authors, booleanOp=:and)
    return selectByFieldWithMultipleKeywords(:userDB, 'publications', 'abstract', authors, booleanOp, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Update ALL the fields of a Publication record identified by its id
  # [+id+]            Publications.id of the record to update
  # [+pmid+]          The pubmed id for the updated record
  # [+type+]          A String identifying the 'type' (kind) of Publication for the updated record
  # [+title+]         A String with the title of the Publication in the updated record
  # [+authorList+]    A String with a list of the authors for the updated record
  # [+journal+]       A String with the name of the journal for the updated record
  # [+meeting+]       A String with the meeting for the updated record
  # [+date+]          The date for the updated record
  # [+volume+]        A String with the volume for the updated record
  # [+issue+]         A String with the issue for the updated record
  # [+startPage+]     Start page for the updated record
  # [+endPage+]       End page for the updated record
  # [+abstract+]      A String with the abstract for the updated record
  # [+meshHeader+]    A String with the Mesh Header for the updated record
  # [+url+]           A String with the URL for the updated record
  # [+state+]         [optional; default=0] for future use
  # [+langauge+]      A String metioning the language (default English) for the updated record
  # [+returns+]       Number of rows updated.
  def updatePublicationById(id, pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language)
    retval = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_PUBLICATION_BY_ID)
      stmt.execute(pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language, id)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_PUBLICATION_BY_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update ALL the fields of a Publication record identified by its pmid
  # [+id+]            Publications.id of the record to update
  # [+pmid+]          The pubmed id for the updated record
  # [+type+]          A String identifying the 'type' (kind) of Publication for the updated record
  # [+title+]         A String with the title of the Publication in the updated record
  # [+authorList+]    A String with a list of the authors for the updated record
  # [+journal+]       A String with the name of the journal for the updated record
  # [+meeting+]       A String with the meeting for the updated record
  # [+date+]          The date for the updated record
  # [+volume+]        A String with the volume for the updated record
  # [+issue+]         A String with the issue for the updated record
  # [+startPage+]     Start page for the updated record
  # [+endPage+]       End page for the updated record
  # [+abstract+]      A String with the abstract for the updated record
  # [+meshHeader+]    A String with the Mesh Header for the updated record
  # [+url+]           A String with the URL for the updated record
  # [+state+]         [optional; default=0] for future use
  # [+langauge+]      A String metioning the language (default English) for the updated record
  # [+returns+]       Number of rows updated.
  def updatePublicationByPMID(id, pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language)
    retval = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(UPDATE_WHOLE_PUBLICATION_BY_PMID)
      stmt.execute(id, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language, pmid)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, UPDATE_WHOLE_PUBLICATION_BY_PMID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get Publication records by their year
  # [+year+]    The year of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByYear(year)
    retval = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_PUBLICATION_BY_YEAR)
      stmt.execute(year)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_PUBLICATION_BY_YEAR)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get Publication records by their year and name of journal
  # [+year+]    The year of the publication records to return
  # [+journal+] Journal of the publication record to return
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationsByYearAndJournal(year, journal)
    retval = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_PUBLICATION_BY_YEAR_JOURNAL)
      stmt.execute(year, journal)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_PUBLICATION_BY_YEAR_JOURNAL)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get Publication records by their year and name of journal and issue (optional)
  # [+year+]    The year of the publication records to return
  # [+journal+] Journal of the publication record to return
  # [+issue+]   Issue of the publication record to return (optional)
  # [+returns+] Array of 0 or 1 publications record rows
  def selectPublicationByJournalAndVolumeAndOrIssue(journal, volume, issue=nil)
    retVal = nil
    begin
      sql = SELECT_PUBLICATION_BY_JOURNAL_VOLUME_ISSUE.dup
      sql += ' and issue = ?' if(!issue.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      stmt.execute(sql)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get attribute name and attribute value by publication_id
  # [+id+]      Publication id
  # [+returns+] Attribute name and value
  def selectAttrAndValueByPublicationId(id)
    retval = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_ATTR_VALUE_BY_PUBLICATION_ID)
      stmt.execute(id)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_ATTR_VALUE_BY_PUBLICATION_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Insert a new Publication record
  # [+pmid+]          The pubmed id for the record to be inserted
  # [+type+]          A String identifying the 'type' (kind) of Publication for the record to be inserted
  # [+title+]         A String with the title of the Publication record to be inserted
  # [+authorList+]    A String with a list of the authors to be inserted
  # [+journal+]       A String with the name of the journal to be inserted
  # [+meeting+]       A String with the meeting to be inserted
  # [+date+]          The date for the record to be inserted
  # [+volume+]        A String with the volume to be inserted
  # [+issue+]         A String with the issue to be inserted
  # [+startPage+]     Start page to be inserted
  # [+endPage+]       End page to be inserted
  # [+abstract+]      A String with the abstract to be inserted
  # [+meshHeader+]    A String with the Mesh Header to be inserted
  # [+url+]           A String with the URL to be inserted
  # [+state+]         [optional; default=0] for future use
  # [+langauge+]      A String metioning the language (default English) to be inserted
  # [+returns+]       Number of rows inserted
  def insertPublication(pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language)
    data = [pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state, language ]
    return insertPublications(data, 1)
  end

  # Insert multiple Publication records using column data.
  # [+data+]        An Array of values to use for pmid, type, title, authorList, journal, meeting, date, volume, issue, startPage, endPage, abstract, meshHeaders, url, state(optional) and language.
  #                 The Array may be 2-D (i.e. N rows of 15 (optional 16) columns or simply a flat array with appropriate values)
  #                 See the +insertPublication()+ method for the fields needed for each record.
  # [+numPublications+]  Number of publications to insert using values in +data+.
  #                      - This is required because the data array may be flat and yet
  #                        have the dynamic field values for many Publications.
  # [+returns+]     Number of rows inserted
  def insertPublications(data, numPublications)
    return insertRecords(:userDB, 'publications', data, true, numPublications, 16, false, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Publication record using its id.
  # [+id+]      The publications.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationById(id)
    return deleteByFieldAndValue(:userDB, 'publications', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Publication records using their ids.
  # [+ids+]     Array of publications.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationsByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'publications', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a Publication record using its pmid.
  # [+pmid+]    The publications.pmid of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationByPMID(pmid)
    return deleteByFieldAndValue(:userDB, 'publications', 'pmid', pmid, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete Publication records using their pmids.
  # [+pmids+]   Array of publications.pmid of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationsByPMIDs(pmids)
    return deleteByFieldWithMultipleValues(:userDB, 'publications', 'pmid', pmids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publications by matching an AVP by ids; get all publications possessing the attribute and its value
  # indicated by +publicationAttrNameId+ whose value is +publicationAttrValueId+.
  # [+publicationAttrNameId+]   publicationAttrNames.id for the publication attribute to consider
  # [+publicationAttrValueId+]  publicationAttrValues.id for the publication attribute value to match
  # [+returns+]                 Array of 0+ publication records
  def selectPublicationsByAttributeNameAndValueIds(publicationAttrNameId, publicationAttrValueId)
    retVal = nil
    begin
      connectToDataDb()                                     # Lazy connect to data database
      stmt = @dataDbh.prepare(SELECT_PUBLICATION_BY_ATTRNAMEVALUE_ID)
      stmt.execute(studyAttrNameId, studyAttrValueId)
      retVal = stmt.fetch_all()
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_PUBLICATION_BY_ATTRNAMEVALUE_ID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Get Publications by matching an AVP by text; get all publications possessing the attribute and its value
  # named in +publicationAttrNameText+ whose value is +publicationAttrValueText+.
  # [+publicationAttrNameText+]   Publication attribute name to consider
  # [+publicationAttrValueText+]  Publication attribute value to match
  # [+returns+]                   Array of 0+ publication records
  def selectPublicationsByAttributeNameAndValueTexts(publicationAttrNameText, publicationAttrValueText)
    return selectEntitiesByAttributeNameAndValueTexts(:userDB, 'publications', publicationAttrNameText, publicationAttrValueText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: publicationAttrNames
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_PUBLICATION_ATTRNAME = 'update publicationAttrNames set name = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################

  # Count all PublicationAttrNames records
  # [+returns+] 1 row with count
  def countPublicationAttrNames()
    return countRecords(:userDB, 'publicationAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all PublicationAttrNames records
  # [+returns+] Array of 0+ publicationAttrNames records
  def selectAllPublicationAttrNames()
    return selectAll(:userDB, 'publicationAttrNames', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrNames record by its id
  # [+id+]      The ID of the publicationAttrName record to return
  # [+returns+] Array of 0 or 1 publicationAttrNames records
  def selectPublicationAttrNameById(id)
    return selectByFieldAndValue(:userDB, 'publicationAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrNames records using a list of ids
  # [+ids+]     Array of publicationAttrNames IDs
  # [+returns+] Array of 0+ publicationAttrNames records
  def selectPublicationAttrNamesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'publicationAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrName record by its name
  # [+name+]    The unique name of the publicationAttrName record to return
  # [+returns+] Array of 0 or 1 publicationAttrNames records
  def selectPublicationAttrNameByName(name)
    return selectByFieldAndValue(:userDB, 'publicationAttrNames', 'name', name, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrNames using a list of names
  # [+names+]   Array of unique publicationAttrNames names
  # [+returns+] Array of 0+ publicationAttrNames records
  def selectPublicationAttrNamesByNames(names)
    return selectByFieldWithMultipleValues(:userDB, 'publicationAttrNames', 'name', names,  "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new PublicationAttrNames record
  # [+name+]    Unique publicationAttrNames name
  # [+state+]   [optional; default=0] for future use
  # [+returns+] Number of rows inserted
  def insertPublicationAttrName(name, state=0)
    data = [ name, state ]
    return insertPublicationAttrNames(data, 1)
  end

  # Insert multiple PublicationAttrNames records using column data.
  # If an existing attribute is inserted, it will be skipped, leaving the existing record
  # [+data+]        An Array of values to use for name and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numPublicationAttrNames+]  Number of publication attribute names to insert using values in +data+.
  #                              - This is required because the data array may be flat and yet
  #                                have the dynamic field values for many PublicationAttrNames.
  # [+returns+]     Number of rows inserted
  def insertPublicationAttrNames(data, numPublicationAttrNames)
    return insertRecords(:userDB, 'publicationAttrNames', data, true, numPublicationAttrNames, 2, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a PublicationAttrName record using its id.
  # [+id+]      The publicationAttrNames.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrNameById(id)
    return deleteByFieldAndValue(:userDB, 'publicationAttrNames', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete PublicationAttrName records using their ids.
  # [+ids+]     Array of publicationAttrNames.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrNamesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'publicationAttrNames', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # --------
  # Table: publicationAttrValues
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  UPDATE_WHOLE_PUBLICATION_ATTRVALUE = 'update publicationAttrValues set value = ?, sha1 = ?, state = ? where id = ?'
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all PublicationAttrValues records
  # [+returns+] 1 row with count
  def countPublicationAttrValues()
    return countRecords(:userDB, 'publicationAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all PublicationAttrValues records
  # [+returns+] Array of 0+ publicationAttrValues records
  def selectAllPublicationAttrValues()
    return selectAll(:userDB, 'publicationAttrValues', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrValues record by its id
  # [+id+]      The ID of the publicationAttrValues record to return
  # [+returns+] Array of 0 or 1 publicationAttrValues records
  def selectPublicationAttrValueById(id)
    return selectByFieldAndValue(:userDB, 'publicationAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrValues records using a list of ids
  # [+ids+]     Array of publicationAttrValues IDs
  # [+returns+] Array of 0+ publicationAttrValues records
  def selectPublicationAttrValuesByIds(ids)
    return selectByFieldWithMultipleValues(:userDB, 'publicationAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrValues record by the sha1 digest of the value
  # [+sha1+]    The sha1 of the publicationAttrValue record to return
  # [+returns+] Array of 0 or 1 publicationAttrValue records
  def selectPublicationAttrValueBySha1(sha1)
    return selectByFieldAndValue(:userDB, 'publicationAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrValues records using a list of sha1 digests
  # [+sha1s+]   Array of sha1 digests of the publicationAttrValue records to return
  # [+returns+] Array of 0+ publicationAttrNames records
  def selectPublicationAttrValueBySha1s(sha1s)
    return selectByFieldWithMultipleValues(:userDB, 'publicationAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get PublicationAttrValues record by the exact value
  # [+value+]   The value of the publicationAttrValue record to return
  # [+returns+] Array of 0 or 1 publicationAttrValue records
  def selectPublicationAttrValueByValue(value)
    return selectPublicationAttrValueBySha1(SHA1.hexdigest(value.to_s))
  end

  # Get PublicationAttrValues records using a list of the exact values
  # [+values+]  Array of values of the publicationAttrValue records to return
  # [+returns+] Array of 0+ publicationAttrNames records
  def selectPublicationAttrValueByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return selectPublicationAttrValueBySha1s(sha1s)
  end

  # Select the value record for a particular attribute of a publication, using the attribute id.
  # "what's the value of the ___ attribute for this publication?"
  #
  # [+publicationId+]   The id of the publication.
  # [+attrNameId+]      The id of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectPublicationAttrValueByPublicationIdAndAttributeNameId(publicationId, attrNameId)
    return selectValueByEntityAndAttributeNameId(:userDB, 'publications', publicationId, attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select the value record for a particular attribute of a publication, using the attribute name (text).
  # "what's the value of the ___ attribute for this publication?"
  #
  # [+publicationId+]   The id of the publication.
  # [+attrNameText+]    The name of the attribute we want the value for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0-1 attribute value record
  def selectPublicationAttrValueByPublicationAndAttributeNameText(publicationId, attrNameText)
    return selectValueByEntityAndAttributeNameText(:userDB, 'publications', publicationId, attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all publications), using attribute id.
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameId+]    The ids of the attribute we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectPublicationAttrValuesByAttributeNameId(attrNameId)
    return selectValuesByAttributeNameId(:userDB, 'publications', attrNameId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a particular attribute (i.e. across all publications), using attribute name (text).
  # "what are the current values associated with the _____ attribute?"
  #
  # [+attrNameText+]    The name of the attribute we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectPublicationAttrValuesByAttributeNameText(attrNameText)
    return selectValuesByAttributeNameText(:userDB, 'publications', attrNameText, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all publications), using attribute ids.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameIds+]   Array of ids of the attributes we want the values for.
  # [+returns+]       Array of 0+ attribute value record
  def selectPublicationAttrValuesByAttributeNameIds(attrNameIds)
    return selectValuesByAttributeNameIds(:userDB, 'publications', attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all the value records associated with a specific set of attributes (i.e. across all publications), using attribute names.
  # "what are the current values associated with these attributes?"
  #
  # [+attrNameTexts+]   Array of texts of the attributes we want the values for.
  # [+returns+]         Array of 0+ attribute value record
  def selectPublicationAttrValuesByAttributeNameTexts(attrNameTexts)
    return selectValuesByAttributeNameTexts(:userDB, 'publications', attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular publication, using attribute ids
  # "what are the current values associated with these attributes for this publication, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+publicationId+]   The id of the publication to get attribute->value map info for
  # [+attrNameIds+]     Array of ids of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectPublicationAttrValueMapByEntityAndAttributeIds(publicationId, attrNameIds)
    return selectAttributeValueMapByEntityAndAttributeIds(:userDB, 'publications', publicationId, attrNameIds, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select an attribute->value "map" for the given attributes of particular publication, using attribute names
  # "what are the current values associated with these attributes for this publication, given as a map?"
  #
  # The "map" is a result set table with 4 columns, used to map _both_ by id and text
  # (you use the column names in your code, right? for self-documenting code and protection against reordering?):
  #
  #   attrName_id     -> Id of the attribute.
  #   attrName_text   -> Name of the attribute.
  #   attrValue_id    -> Id of the attribute value associated with the attribute, for this publication.
  #   attrValue_text  -> Value of the attribute value associated with the attribute, for this publication.
  #
  # [+publicationId+]   The id of the publication to get attribute->value map info for
  # [+attrNameTexts+]   Array of names of the attributes we want the values for.
  # [+errMsg+]          Prefix to use when an error is raised and logged vis logDbError.
  #                     Typically to provide context info of the call (eg name of method calling this one, etc)
  # [+returns+]         Array of 0+ records with the 4 columns mentioned above.
  def selectPublicationAttrValueMapByEntityAndAttributeTexts(publicationId, attrNameTexts)
    return selectAttributeValueMapByEntityAndAttributeTexts(:userDB, 'publications', publicationId, attrNameTexts, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new PublicationAttrValues record
  # [+value+]    Unique publicationAttrValues value
  # [+state+]    [optional; default=0] for future use
  # [+returns+]  Number of rows inserted
  def insertPublicationAttrValue(value, state=0)
    data = [value, state ] # insertBioSampleAttrValues() will compute SHA1 for us
    return insertPublicationAttrValues(data, 1)
  end

  # Insert multiple PublicationAttrValues records using field data.
  # If an existing attribute value is inserted, it will be skipped, leaving the existing record
  #
  # NOTE: Your data Array just needs to have values for the value AND the state,
  # just like you provide to +insertPublicationAttrValue+ (except here values for state are required within +data+)
  # ...the digests of the values will be automatically computed.
  #
  # [+data+]        An Array of values to use for value and state columns
  #                 The Array may be 2-D (i.e. N rows of 2 columns or simply a flat array with appropriate values)
  # [+numPublicationAttrValues+]  Number of publication attribute values to insert using values in +data+.
  #                               - This is required because the data array may be flat and yet
  #                                 have the dynamic field values for many PublicationAttrValues.
  # [+returns+]     Number of rows inserted
  def insertPublicationAttrValues(data, numPublicationAttrValues)
    # Make a [flattened] copy of data
    dataCopy = data.flatten
    # Insert the SHA1 digests
    ii = 1
    while(ii < dataCopy.size)
      dataCopy[ii,0] = SHA1.hexdigest(dataCopy[ii-1].to_s)
      ii += 3
    end
    return insertRecords(:userDB, 'publicationAttrValues', dataCopy, true, numPublicationAttrValues, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a PublicationAttrValues record using its id.
  # [+id+]      The publicationAttrValues.id of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValueById(id)
    return deleteByFieldAndValue(:userDB, 'publicationAttrValues', 'id', id, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete PublicationAttrValues records using their ids.
  # [+ids+]     Array of publicationAttrValues.id of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValuesByIds(ids)
    return deleteByFieldWithMultipleValues(:userDB, 'publicationAttrValues', 'id', ids, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a PublicationAttrValues record using the sha1 digest of the value.
  # [+sha1+]    The publicationAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValueBySha1(sha1)
    return deleteByFieldAndValue(:userDB, 'publicationAttrValues', 'sha1', sha1, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete PublicationAttrValues records using their sha1 digests.
  # [+ids+]     Array of publicationAttrValues.sha1 of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValuesBySha1s(sha1s)
    return deleteByFieldWithMultipleValues(:userDB, 'publicationAttrValues', 'sha1', sha1s, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Delete a PublicationAttrValues record using the exact value.
  # [+sha1+]    The publicationAttrValues.sha1 digest of the record to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValueByValue(value)
    return deletePublicationAttrValueByValue(SHA1.hexdigest(value.to_s))
  end

  # Delete PublicationAttrValues records using their exact values
  # [+values+]  Array of publicationAttrValues values of the records to delete.
  # [+returns+] Number of rows deleted
  def deletePublicationAttrValuesByValues(values)
    sha1s = values.map {|xx| SHA1.hexdigest(xx.to_s) }
    return deletePublicationAttrValuesBySha1s(sha1s)
  end

  # --------
  # Table: publication2attributes
  # --------
  #:stopdoc:
  # ############################################################################
  # CONSTANTS
  # ############################################################################
  SELECT_PUBLICATION2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'select * from publication2attributes where publicationAttrName_id = ? and publicationAttrValue_id = ?'
  DELETE_PUBLICATION2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID = 'delete from publication2attributes where publication_id = ? '
  #:startdoc:

  # ############################################################################
  # METHODS
  # ############################################################################
  # Count all Publication2Attributes records
  # [+returns+] 1 row with count
  def countPublication2Attributes()
    return countRecords(:userDB, 'publication2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get all Publication2Attributes records
  # [+returns+] Array of 0+ publication2attributes records
  def selectAllPublication2Attributes()
    return selectAll(:userDB, 'publication2attributes', "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Get Publication2Attributes records by study_id ; i.e. get all the AVP mappings (an ID triple) for a publication
  # [+publicationId+] The publication_id for the Publication2Attributes records to return
  # [+returns+] Array of 0+ publication2attributes records
  def selectPublication2AttributesByPublicationId(publicationId)
    return selectByFieldAndValue(:userDB, 'publication2attributes', 'publication_id', publicationId, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Insert a new Publication2Attributes record ; i.e. set a new AVP for a study.
  # Note: this does NOT update any existing triple involving the publication_id and the publicationAttrName_id;
  # in that case there would be MULTIPLE values associated with that attribute for that publication.
  # [+publicationId+]           publication_id for whom to associate an AVP
  # [+publicationAttrNameId+]   publicationAttrName_id for the attribute
  # [+publicationAttrValueId+]  publicationAttrValue_id for the attribute value
  # [+returns+]                 Number of rows inserted
  def insertPublication2Attribute(publicationId, publicationAttrNameId, publicationAttrValueId)
    data = [ publicationId, publicationAttrNameId, publicationAttrValueId ]
    return insertPublication2Attributes(data, 1)
  end

  # Insert multiple Publication2Attributes records using field data.
  # If a duplicate publication2attributes record is inserted, it will be skipped
  # [+data+]        An Array of values to use for publication_id, publicationAttrName_id, and publicationAttrValue_id columns
  #                 The Array may be 2-D (i.e. N rows of 3 columns or simply a flat array with appropriate values)
  # [+numPublication2Attributes+]  Number of publication2attributes to insert using values in +data+.
  #                                - This is required because the data array may be flat and yet
  #                                  have the dynamic field values for many Publication2Attributes.
  # [+returns+]     Number of rows inserted
  def insertPublication2Attributes(data, numPublication2Attributes)
    return insertRecords(:userDB, 'publication2attributes', data, false, numPublication2Attributes, 3, true, "ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():")
  end

  # Select all Publication2Attributes records having a specific AVP ;
  # i.e. that have a particular attribute with a particular value
  # [+publicationAttrNameId+]   publicationAttrName_id for tha attribute
  # [+publicationAttrValueId+]  publicationAttrValue_id for the attribute value
  # [+returns+]                 Array of 0+ publication2attributes records
  def selectPublication2AttributesByAttrNameIdAndAttrValueId(publicationAttrNameId, publicationAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      stmt = @dataDbh.prepare(SELECT_PUBLICATION2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
      stmt.execute(publicationAttrNameId, publicationAttrValueId)
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, SELECT_PUBLICATION2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end

  # Update the value associated with a particular publication's attribute.
  # All triples associating the publication to an attribute will have their value replaced.
  # [+publicationId+]           ID of the publication whose AVP we are updating
  # [+publicationAttrNameId+]   ID of publicationAttrName whose value to update
  # [+publicationAttrValueId+]  ID of the publicationAttrValue to associate with the attribute for a particular publication
  def updatePublication2AttributeForPublicationAndAttrName(publicationId, publicationAttrNameId, publicationAttrValueId)
    retVal = nil
    begin
      connectToDataDb()
      # Safe way: delete then insert
      rowsDeleted = deletePublication2AttributesByPublicationIdAndAttrNameId(publicationId, publicationAttrNameId)
      retval = insertPublication2Attribute(publicationId, publicationAttrNameId, publicationAttrValueId)
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, "<no SQL to report>")
    end
    return retVal
  end

  # Delete Publication2Attributes records for a given publication, or for a publication and attribute name,
  # or for a publication and attribute name and a specific attribute value. This can
  # be used to remove all AVPs for a publication, or to remove the association of a particular
  # attribute with the publication, or to remove the association only if a particular value is involved.
  # [+publicationId+]           publication_id for which to delete some AVP info
  # [+publicationAttrNameId+]   [optional] publicationAttrName_id to disassociate with the publication
  # [+publicationAttrValueId+]  [optional] publicationAttrValue_id to further restrict which AVPs are disassociate with the publication
  # [+returns+]                 Number of rows deleted
  def deletePublication2AttributesByPublicationIdAndAttrNameId(publicationId, publicationAttrNameId=nil, publicationAttrValueId=nil)
    retVal = nil
    begin
      sql = DELETE_PUBLICATION2ATTRIBUTE_BY_ATTRNAMEID_AND_ATTRVALUEID.dup
      sql += ' and publicationAttrName_id = ?' unless(publicationAttrNameId.nil?)
      sql += ' and publicationAttrValue_id = ?' unless(publicationAttrValueId.nil?)
      connectToDataDb()
      stmt = @dataDbh.prepare(sql)
      if(publicationAttrNameId.nil?)
        stmt.execute(publicationId)
      elsif(publicationAttrValueId.nil?)
        stmt.execute(publicationId, publicationAttrNameId)
      else
        stmt.execute(publicationId, publicationAttrNameId, publicationAttrValueId)
      end
      retVal = stmt.rows
    rescue => @err
      DBUtil.logDbError("ERROR: [#{File.basename($0)}] #{self.class}##{__method__}():", @err, sql, publicationId, publicationAttrNameId, publicationAttrValueId)
    ensure
      stmt.finish() unless(stmt.nil?)
    end
    return retVal
  end
end # class DBUtil
end ; end # module BRL ; module Genboree
