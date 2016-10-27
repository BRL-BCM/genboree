<HTML>
<head>
<title>Genboree - Upload Format</title>
<link rel="stylesheet" href="/styles/jsp.css<%=jsVersion%>" type="text/css">
<meta HTTP-EQUIV='Content-Type' CONTENT='text/html; charset=iso-8859-1'>
</head>
<BODY>

<table cellpadding=0 cellspacing=0 border=0 bgcolor=white width="840">
<tbody>
  <tr><td width=10></td>
  <td height=10></td>
  <td width=10></td>
  <td width=10 class="bkgd"></td></tr>
  <tr><td></td><td>
  
      <table border=0 cellpadding=0 cellspacing=0 width="100%"><tr>
        <td width="484"><a href="login.jsp"><img
          src="/images/genboree.jpg" width="484" height="72" border="0"
          alt="Genboree"></a></td>
        <td align="center"><a href="http://hgsc.bcm.tmc.edu"><img
          src="/images/hgsc50.gif" width="93" height="50"
          alt="HGSC" border="0"></a></td>
        <td align="right" width="70"><a href="http://brl.bcm.tmc.edu"><img
          src="/images/brl50.gif" width="70" height="50"
          alt="Bioinformatics Research Laboratory" border="0"></a></td>
       </tr></table>

  </td>
  <td width=10></td>
  <td class="shadow"></td></tr>
  <tr><td></td><td>

	<br><h3 align="center">Genboree Upload Data Format</h3>

<p>
Genboree back end is based on bioperl module and LDAS program written by Lincoln Stein. In order for Genboree to correctly parse
and interpret your data you have to properly format the data. The accepted format is the one proposed by LDAS project.
The following is an excerpt from LDAS <a href="http://www.biodas.org/servers/LDAS.html">documentation</a> that talks about the correct
ways of formatting the input data:
</p>
<h4><a name="creating the load files">Creating the Load Files</a></h4>
<p>The LDAS database is loaded from tab-delimited files containing
annotation and assembly information.  There are actually three types
of tables that can be loaded:</p>
<ol>
<li><strong><a name="item_reference_point_information">reference point information</a></strong><br>

This type of information, which is needed both for reference servers
and annotation servers, lists the names and lengths of all the
landmarks that will be used to describe the positions of annotations.
Landmarks are typically sequence accession numbers, such as a Genbank
accession number, contig names, supercontig names, or the names of
chromosomes.  LDAS needs the name and length (in bp) of each reference
point that is referred to by the assembly and annotation tables.
<p></p>
<li><strong><a name="item_assembly_information">assembly information</a></strong><br>

This type of information, which is needed for reference servers only,
describes how the genome is assembled from smaller fragments.  LDAS
does not assume or require that the genome be finished, but if there
is any assembly information at all, it should be represented here.
<p></p>
<li><strong><a name="item_annotation_information">annotation information</a></strong><br>

This type of information, which is needed for annotation servers only,
describes a series of annotations, each of which is represented as a
start and end position relative to one of the reference points.
<p></p></ol>
<p>In practice, you can use a different file for each of the reference
point, assembly, and annotation tables, put all the information into
different sections of a single file, or distribute the information
arbitrarily among multiple files.</p>
<p>Load files are plain, tab-delimited text files, such as can be
produced by a text editor or a spreadsheet program.  The files must
have the extension .das.</p>
<p>The different types of information are proceeded by a short bracketed
identifier.  Here is an excerpt from the ``test.das'' file that is
included with this distribution:</p>
<pre>
 [references]
 #id    class           length
 Chr1     Chromosome   10000
 Link_1   Link          6000
 Link_2   Link          5000
 Cont_1a  Contig        5000
 Cont_1b  Contig        5000
 Cont_2a  Contig        9000
 Cont_2b  Contig        8000</pre>
<pre>
 [assembly]
 #id    start   end     class   name    start   end
 Chr1   1       5000    Link    Link_1  1001    6000
 Chr1   5001    10000   Link    Link_2  2001    7000
 Link_1 1001    3500    Contig  Cont_1a 1       2500
 Link_1 3501    5000    Contig  Cont_1b 4500    2001
 Link_1 5001    6000    Contig  Cont_1a 5000    4001
 Link_2 2001    4500    Contig  Cont_2a 1001    3500
 Link_2 4501    7000    Contig  Cont_2b 8000    5501</pre>
<pre>
 [annotations]
 #class name    type       subtype      ref        start stop strand    phase   score   tstart  tend
 Gene   abc-1   exon       curated      Cont_2a    5050 5100     +      .       .
 Gene   abc-1   CDS        curated      Cont_2a    5060 5100     +      0       .
 Gene   abc-1   exon       curated      Cont_2a    5200 5280     +      .       .
 Gene   abc-1   CDS        curated      Cont_2a    5200 5280     +      2       .
 Gene   abc-1   exon       curated      Cont_2a    5300 5380     +      .       .
 Gene   abc-1   CDS        curated      Cont_2a    5300 5360     +      2       .
 EST    yk123.1 similarity ESTWise      Cont_2a    5025 5100     .      .       99      1       76
 EST    yk123.1 similarity ESTWise      Cont_2a    5200 5280     .      .       99      77      157
 .      .       repeat     alu  Cont_2a    5050 5150     .      .       80</pre>
<p>As shown in the example, the file is divided into multiple sections,
each containing a bracketed [section] identifier.  There can be
multiple sections in a single load file, or you can create a file that
contains a single section only.  Blank lines, and lines that begin
with the # sign, are ignored.  All columns must be separated by tabs,
not spaces.</p>
<dl>
<dt><strong><a name="item_The_%5Breferences%5D_section">The [references] section</a></strong><br><br>
<dd>
A section that begins with b&lt;[references]&gt; is a listing of the
reference sequences for the database.  The references section has
three columns:
<pre>
 Column 1 Reference name
          The name of the reference sequence.</pre>
<pre>
 Column 2 Reference source
          A one-word description of the reference sequence.
          The source description is used in the LDAS
          configuration file to identify reference sequence entries.</pre>
<pre>
 Column 3 Reference length
          The length of the reference sequence, in base pairs.
          This information is necessary even for annotation
          servers so as to be able to handle coordinate translations
          involving the reverse strand.</pre>
<p>It is recommended that you use the ``name.version'' identifier for
reference sequences, if you can.  LDAS recognizes this format and
automatically converts it into version information for the DAS
protocol.</p>
<p></p>
<dt><strong><a name="item_The_%5Bassembly%5D_section">The [assembly] section</a></strong><br><br>
<dd>
A section that begins with b&lt;[assembly]&gt; is a listing of the genome
assembly.  Annotation servers do b&lt;not&gt; need to provide this
information, but reference servers do.  The format is a 7-column
list.  Each line contains information about where a particular segment
of the assembly comes from:
<pre>
 Column 1:  Reference name
          The name of a reference sequence which is made out of
          an assembly of smaller pieces.</pre>
<pre>
 Columns 2 &amp; 3:  Start and stop positions in reference sequence coordinates
          Two integer indicating the start of a section of the
          assembly of the reference sequence indicated in the
          first column.  The start position should always be less
          than the stop.</pre>
<pre>
 Columns 4 &amp; 5:  Source and name of the target sequence
          A source and name for the smaller sequence that is &quot;assembled
          into&quot; the reference sequence.</pre>
<pre>
 Columns 6 &amp; 7:  Start and stop positions in target sequence coordinates
          Two integers indicating the position of the assembly in
          the frame of reference of the smaller sequence indicated by
          columns 4 &amp; 5. Unlike the endpoints given in reference
          sequence coordinates, the target start position will be
          greater than the stop position if the local assembly was
          built up from the reverse complement of the target sequence.</pre>
<p>The following picture illustrates how this works:</p>
<pre>
     2001   4500 4501             7000
      |         ||                 |  
   --------------------------------------&gt;  Link_2</pre>
<pre>
   ...-----------....&gt; Cont_2a
      |         |
     1001      3500</pre>
<pre>
  Cont_2b &lt;......------------------......... 
                 |                |
               8000              5501</pre>
<p>Positions 2001 to 4500 of Link_2 correspond to positions 1001 to 3500
of Cont_2a, so that relationship is described by</p>
<pre>
 Link_2 2001    4500    Contig  Cont_2a 1001    3500</pre>
<p>Positions 4501 to 7000 of Link_2 correspond to positions 5501 to 8000
of Cont_2b, so that relationship is described by</p>
<pre>
 Link_2 4501    7000    Contig  Cont_2b 8000    5501</pre>
<p></p>
<dt><strong><a name="item_The_%5Bannotations%5D_Section">The [annotations] Section</a></strong><br><br>
<dd>
This is the longest section of the load file(s).  It is a 10 or 12
column table.  Each line corresponds to an annotation on one of the
reference sequences.  An annotation that spans multiple discontinuous
sequence ranges, such as an mRNA-&gt;genomic alignment, will occupy
several lines of the file.
<p>Here are a few lines from the sample file that illustrate annotated
exons for the gene named ``abc-1'':</p>
<pre>
 Gene   abc-1   curated transcript Cont_2a    5050 5380  +      .       .
 Gene   abc-1   curated exon       Cont_2a    5050 5100  +      .       .
 Gene   abc-1   curated exon       Cont_2a    5050 5100  +      .       .
 Gene   abc-1   curated exon       Cont_2a    5200 5280  +      .       .
 Gene   abc-1   curated exon       Cont_2a    5300 5380  +      .       .</pre>
<pre>
 Columns 1 &amp; 2:  Group class and name
        Some annotations correspond to a named biological object.  For these
        annotations, columns 1 and 2 are used to give the annotation a class
        and a name.  In the example above, the class is &quot;Gene&quot; and the name
        is &quot;abc-1&quot;.  Giving the annotation a name allows the LDAS server to
        retrieve the annotation when requested.  It also allows you to 
        provide the LDAS server with a URL linking rule for the server to use
        when users request more information about the annotation.</pre>
<pre>
        When a biological object is composed of multiple feature types, as in 
        the example above (1 transcript, 4 exons), each feature type gets a 
        separate line, but shares the same group class and name.  This mechanism is
        also used when a single object spans multiple discontinuous ranges,
        as in an mRNA aligned to the genome:</pre>
<pre>
         EST    yk123.1 ESTWise similarity Cont_2a    5025 5100...
         EST    yk123.1 ESTWise similarity Cont_2a    5200 5280...</pre>
<pre>
        In this example, the EST named &quot;yk123.1&quot; aligns to positions
        5025-5100, and 5200-5280 of contig Cont_2a.</pre>
<pre>
        A group name can be used to describe a single feature only:</pre>
<pre>
         Knockout G123.1  GeneTrap knockout  Cont_1b 8000 8600....</pre>
<pre>
        For features that are not named, such as anonymous repetitive elements,
        just leave the group class and name blank, or use a single dot character
        &quot;.&quot;.</pre>
<pre>
 Columns 3 &amp; 4:  type and subtype
        The type and subtype fields together describe the annotation type.
        The type provides a generic description, such as &quot;exon&quot;, and the
        subtype qualifies the description by describing how the annotation
        was made.  For example, in the WormBase database, a type of
        &quot;exon&quot; and a subtype of &quot;curated&quot; means an exon prediction
        that has been examinedand confirmed by a human annotator.  An
        exon with a subtype field of &quot;GeneFinder&quot; is used for an exon
        that  was predicted by Phil Green's GeneFinder program.</pre>
<pre>
        The choices of type and subtype are up to you.  However, it is recommended
        that whenever possible you use the type fields described in the DAS
        specification (<a href="http://www.biodas.org/documents/spec.html">http://www.biodas.org/documents/spec.html</a>).</pre>
<pre>
        NOTE: The type and subtype fields correspond to the method and
        source fields of the GFF (Gene Finder Format) specification.</pre>
<pre>
 Columns 5, 6 &amp; 7:  Reference sequence and range
         The next three columns give the reference sequence, and the start and
         stop of the annotation in reference sequence coordinates (bp units).  
         The start is always less than the stop.</pre>
<pre>
 Column 8: Strand
         The eighth column gives the strand on which the annotation is located.
         Use &quot;+&quot; for annotations on the forward strand, &quot;-&quot; for annotations on
         the reverse strand, and &quot;.&quot; or blank for annotations that are not
         inherently stranded.  This is typically used for genes and gene 
         products.</pre>
<pre>
 Column 9: Phase
         The next column is used to store the phase of annotations that relate
         to protein coding, such as CDS features.  The phase indicates the 
         position of the first base in the codon, and can be one of 0, 1 or 2.  
         Use a &quot;.&quot; or blank for annotations that do not relate to protein coding.</pre>
<pre>
 Column 10: Score
         The tenth column contains a score.  The score is a floating point
         number of unspecified units.  For similarity features, the score
         can be used to store the expectation value or percent similarity.
         For gene predictions, the score can be used to store the prediction
         confidence value.  Use &quot;.&quot; or blank for annotations that do not have
         scores.</pre>
<pre>
 Columns 11-12: Similarity alignment range
         The last two columns are optional.  If present, they are used to indicate the
         alignment between the reference sequence and the annotated sequence.  The fields
         are typically used for similarity annotations as in the following example:</pre>
<pre>
  EST yk123.1 ESTWise similarity Cont_2a  5200 5280 . . 1.0e-12 77 157</pre>
<pre>
         This example indicates that bases 5200 to 5280 of contig Cont_2a align
         to bases 77-157 of EST yk123.1.  Also note the expectation value score of
         1.0e-12 (read as 1 times 10 to the -12th power).</pre>
<p></p></dl>
<p>You can create these data files using any text editor or spreadsheet
program, but be sure to save the results as text only, using tabs to
delimit the columns.  The data files must have the extension .das, and
must begin with one of the section identifiers [references],
[assembly] or [annotations].  A file can contain several different
sections, and can in fact switch back and forth between them.</p>
<p>The expressivity of the annotations table is limited by the fact that
an annotation can only belong to a single group.  To express more
complex relationships, you must factor out intermediate groups.  For
example, consider a gene that is composed of two alternative
transcripts, each of which is composed of a different subset of four
exons:</p>
<pre>
                         Exon1  Exon2  Exon3  Exon4
        transcript a      x              x      x
        transcript b      x       x      x</pre>
<p>Under current restrictions, you will have to express these
relationships by creating two named Transcript objects, which overlap
in range with a Gene object.  Exons 1 and 3 will be duplicated in the
table:</p>
<pre>
  Gene        abc-1  curated gene       Cont_2a 5050 5380 ...
  Transcript  abc-1a curated transcript Cont_2a 5050 5380 ...
  Transcript  abc-1b curated transcript Cont_2a 5050 5280 ...
  Transcript  abc-1a curated exon       Cont_2a 5050 5100 ...
  Transcript  abc-1a curated exon       Cont_2a 5200 5280 ...
  Transcript  abc-1a curated exon       Cont_2a 5300 5380 ...
  Transcript  abc-1b curated exon       Cont_2a 5050 5100 ...
  Transcript  abc-1b curated exon       Cont_2a 5050 5100 ...
  Transcript  abc-1b curated exon       Cont_2a 5200 5280 ...</pre>
<p>This restriction will be lifted in the DAS/2 server, which will allow
much more expressive grouping of annotations.</p>

<p><input type="button" value="Close" onclick="window.close();" class="btn" ></p>

<%@ include file="include/footer.incl" %>

</BODY>
</HTML>
