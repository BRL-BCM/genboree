package org.genboree.editor;

import javax.servlet.jsp.tagext.TagSupport;
import javax.servlet.jsp.JspWriter;
import java.io.IOException;


/**
 * User: tong Date: Mar 20, 2006 Time: 5:15:52 PM
 */
public class PopulateAnnotation extends TagSupport {
    private int fid;
    public int getFid() {
        return fid;
    }

    public void setFid(int fid) {
        this.fid = fid;
    }



    public AnnotationDetail getAnno() {
        return anno;
    }

    public void setAnno(AnnotationDetail anno) {
        this.anno = anno;
    }

    private AnnotationDetail anno;

    public int doStartTag() {
        try {
            JspWriter out = pageContext.getOut();

         /**/

   out.println( "welcome to start tag!");


        } catch (IOException e) {e.printStackTrace();}
        return SKIP_BODY;



       /*  sb.append("<TR><%if (errorFields.get(\"gname\") != null) { %>");
         sb.append(" <TD class=\"annotation1\" colspan = \"1\" ><divid = \"annoname\" > <B>Annotation & nbsp; Name</B > < / div > < / TD >");
         sb.append("< % errorFields.remove(\"gname\"); } else { %>");
         sb.append(" <td class=\"annotation2\"  colspan = \"1\" > <divid = \"annoname\" > <B>Annotation & nbsp; Name</B > < / div > < / td >");
         sb.append("< % } %>  <TD class=\"annotation2\" colspan =\"3\" ><input type =\"text\" name =\"gname\" id =\"gname\" class=\"largeInput\" maxlength =\"200\" value=\"<%=Util.htmlQuote(annotation.getGname()) %>\" >< / TD >< / TR >");
         sb.append(" <TRid = \"trackRow\" ><TD ALIGN=\"left\" class=\"annotation2\" colspan = \"1\" >");
         sb.append("<divid = \"track\" > <B>Track < B > < / div >< / TD >");
         sb.append("<TD    class=\"annotation2\" colspan = \"1\" >");
         sb.append(" <select class=\"longDroplist\" name = \"tracks\" id = \"tracks\" BGCOLOR = \"white\" onchange = \"checkNewTrack()\" >");
      /*   sb.append("   \n" +
                 "                    < %\n" +
                 "            for (int j = 0; j < tracks.length; j++) {\n" +
                 "                String sel = \"\";\n" +
                 "                if (errorFields.get(\"newTrackRow\") != null && (j == (tracks.length - 1)))\n" +
                 "                    sel = \" selected\";\n" +
                 "                else if (tracks[j].compareTo(annotation.getTrackName()) == 0)\n" +
                 "                    sel = \" selected\";\n" +
                 "                %>\n" +
                 "                <optionvalue = \"<%=tracks[j]%>\" < %= sel % >> < %= tracks[j] % > < / option >\n" +
                 "                        < %\n" +
                 "            }%>\n" +
                 "            < / select >\n" +
                 "                    < / TD >\n" +
                 "                    <TDALIGN = \"left\"\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"2\" > & nbsp;\n" +
                 "            < / TD >\n" +
                 "                    < / TR >\n" +
                 "\n" +
                 "                    < %\n" +
                 "            if (errorFields.get(\"newTrackRow\") != null) {\n" +
                 "                errorFields.remove(\"newTrackRow\");\n" +
                 "                String typeValue = \"\";\n" +
                 "                String subtypeValue = \"\";\n" +
                 "                if (mys.getAttribute(\"duptype\") != null)\n" +
                 "                    typeValue = (String) mys.getAttribute(\"duptype\");\n" +
                 "                if (mys.getAttribute(\"dupsubtype\") != null)\n" +
                 "                    subtypeValue = (String) mys.getAttribute(\"dupsubtype\");\n" +
                 "                mys.removeAttribute(\"dutype\");\n" +
                 "                mys.removeAttribute(\"dupsubtype\");\n" +
                 "                %>\n" +
                 "                <TRid = \"newTrackRow\"\n" +
                 "                style = \"track.style.display\" >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                id = \"newTypeLabel\"\n" +
                 "                style = \"color:red\" >\n" +
                 "                        <B>Track & nbsp;\n" +
                 "                Type</B >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"20\"\n" +
                 "                name = \"newType\"\n" +
                 "                id = \"newType\"\n" +
                 "                value = \"<%=typeValue%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                id = \"newSubtypeLabel\"\n" +
                 "                style = \"color:red\" >\n" +
                 "                        <B>Track & nbsp;\n" +
                 "                Subtype</B >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"20\"\n" +
                 "                name = \"newsubtype\"\n" +
                 "                id = \"newsubtype\"\n" +
                 "                value = \"<%=subtypeValue%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } else {\n" +
                 "                %>\n" +
                 "                <TRid = \"newTrackRow\"\n" +
                 "                style = \"display:none\" >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                id = \"newTypeLabel\"\n" +
                 "                style = \"color:#403c59\" >\n" +
                 "                        <B>Track & nbsp;\n" +
                 "                Type</B >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                id = \"new_type\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"20\"\n" +
                 "                name = \"new_type\" >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                id = \"newSubtypeLabel\"\n" +
                 "                style = \"color:#403c59\" >\n" +
                 "                        <B>Track & nbsp;\n" +
                 "                Subtype</B >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                id = \"new_subtype\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"20\"\n" +
                 "                name = \"new_subtype\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } %>\n" +
                 "            < / TR >\n" +
                 "\n" +
                 "                    <TR>\n" +
                 "                    <%\n" +
                 "            if (chromosomes != null && chromosomes.length > 1 && chromosomes.length <= org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"ch1\" > <B>Chromosome < B > < / div >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <selectname = \"chromosomes\"\n" +
                 "                id = \"chromosomes\"\n" +
                 "                class=\"longDroplist\"\n" +
                 "                BGCOLOR = \"white\" >\n" +
                 "                        < %\n" +
                 "                for (int j = 0; j < chromosomes.length; j++) {\n" +
                 "                    String sel = \"\";\n" +
                 "                    if (chromosomes[j].compareTo(annotation.getChromosome()) == 0) {\n" +
                 "                        sel = \" selected\";\n" +
                 "                        chromosome = (Chromosome) chromosomeMap.get(chromosomes[j]);\n" +
                 "                    }\n" +
                 "                    %>\n" +
                 "                    <optionvalue = \"<%=chromosomes[j]%>\" < %= sel % >> < %= chromosomes[j] % > < / option >\n" +
                 "                            < %\n" +
                 "                }%>\n" +
                 "                < / select >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST) && (errorFields.get(\"chromosome\") == null)) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"ch2\" > <B>Chromosome < B > < / div >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                name = \"chromosomes\"\n" +
                 "                id = \"chromosomes\"\n" +
                 "                class=\"longInput\"\n" +
                 "                value = \"<%=annotation.getChromosome()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } else if (chromosomes != null && (chromosomes.length > org.genboree.util.Constants.GB_MAX_FREF_FOR_DROPLIST) && (errorFields.get(\"chromosome\") != null)) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation1\"\n" +
                 "                colspan = \"1\" > <B>Chromosome < B >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                name = \"chromosomes\"\n" +
                 "                id = \"chromosomes\"\n" +
                 "                class=\"longInput\"\n" +
                 "                value = \"<%=annotation.getChromosome()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "                // errorFields.remove(\"chromosome\");\n" +
                 "            } else {\n" +
                 "                %>\n" +
                 "                <\n" +
                 "                !--\n" +
                 "                if\n" +
                 "                no entry\n" +
                 "                point name\n" +
                 "                in db, make\n" +
                 "                an empty\n" +
                 "                field-- >\n" +
                 "                        <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"ch0\" > <B>Chromosome < B > < / div >\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                name = \"chromosomes\"\n" +
                 "                id = \"chromosomes\"\n" +
                 "                class=\"longInput\"\n" +
                 "                value = \"\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            }\n" +
                 "            %>\n" +
                 "\n" +
                 "            <TDALIGN = \"left\"\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"2\" > & nbsp;\n" +
                 "            < / TD >\n" +
                 "                    < / TR >\n" +
                 "                    <TRalign = \"center\" >\n" +
                 "                    < %\n" +
                 "            if (errorFields.get(\"start\") != null) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation1\"\n" +
                 "                colspan = \"1\" > <divid = \"startLabel\" > <B>Start < B > < / div >\n" +
                 "\n" +
                 "                        < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                name = \"startValue\"\n" +
                 "                id = \"startValue\"\n" +
                 "                value = \"<%=annotation.getFstart()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "                        errorFields.remove(\"start\");\n" +
                 "            } else {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"startLabel\" > <B>Start < B > < / div > < / TD >\n" +
                 "                        <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                name = \"startValue\"\n" +
                 "                id = \"startValue\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                value = \"<%=annotation.getFstart()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } %>\n" +
                 "            < %\n" +
                 "            if (errorFields.get(\"stop\") != null) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation1\"\n" +
                 "                colspan = \"1\" > <divid = \"stopLabel\" > <B>Stop < B > < / div > < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                BGCOLOR = \"white\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                name = \"stopValue\"\n" +
                 "                id = \"stopValue\"\n" +
                 "                minLength = \"20\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                value = \"<%=annotation.getFstop()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < % errorFields.remove(\"stop\");\n" +
                 "            } else {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"stopLabel\" > <B>Stop < B > < / div > < / TD >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                BGCOLOR = \"white\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                class=\"longInput\"\n" +
                 "                name = \"stopValue\"\n" +
                 "                id = \"stopValue\"\n" +
                 "                minLength = \"20\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                value = \"<%=annotation.getFstop()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            }%>\n" +
                 "            < / TR >\n" +
                 "                    <TR>\n" +
                 "                    <% if (errorFields.get(\"tstart\") == null) {\n" +
                 "                        %>\n" +
                 "                        <TDALIGN = \"left\"\n" +
                 "                        class=\"annotation2\"\n" +
                 "                        colspan = \"1\" > <divid = \"qstartLabel\" > <B>Query & nbsp;\n" +
                 "                        Start</B > < / div >\n" +
                 "\n" +
                 "                                < / TD >\n" +
                 "\n" +
                 "                                <TD\n" +
                 "                        class=\"annotation2\"\n" +
                 "                        colspan = \"1\" >\n" +
                 "                                <inputname = \"qstart\"\n" +
                 "                        id = \"qstart\"\n" +
                 "                        type = \"text\"\n" +
                 "                        BGCOLOR = \"white\"\n" +
                 "                        class=\"longInput\"\n" +
                 "                        maxlength = \"50\"\n" +
                 "                        value = \"<%=annotation.getTstart()%>\" >\n" +
                 "                                < / TD >\n" +
                 "                                < %\n" +
                 "                    } else {\n" +
                 "                        %>\n" +
                 "                        <TDALIGN = \"left\"\n" +
                 "                        class=\"annotation1\"\n" +
                 "                        colspan = \"1\" > <divid = \"qstartLabel\" > <B>Query & nbsp;\n" +
                 "                        Start</B > < / div >\n" +
                 "\n" +
                 "                                < / TD >\n" +
                 "\n" +
                 "                                <TD\n" +
                 "                        class=\"annotation2\"\n" +
                 "                        colspan = \"1\" >\n" +
                 "                                <inputname = \"qstart\"\n" +
                 "                        id = \"qstart\"\n" +
                 "                        type = \"text\"\n" +
                 "                        BGCOLOR = \"white\"\n" +
                 "                        class=\"longInput\"\n" +
                 "                        maxlength = \"50\"\n" +
                 "                        value = \"<%=annotation.getTstart()%>\" >\n" +
                 "                                < / TD >\n" +
                 "                                < %\n" +
                 "                    } %>\n" +
                 "            < %\n" +
                 "            if (errorFields.get(\"tstop\") == null) {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" > <divid = \"qstopLabel\" > <B>Query & nbsp;\n" +
                 "                Stop</B > < / div >\n" +
                 "\n" +
                 "                        < / TD >\n" +
                 "                        <\n" +
                 "                !--Target\n" +
                 "                Stop-- >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                name = \"qstop\"\n" +
                 "                id = \"qstop\"\n" +
                 "                BGCOLOR = \"white\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                value = \"<%=annotation.getTstop()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            } else {\n" +
                 "                %>\n" +
                 "                <TDALIGN = \"left\"\n" +
                 "                class=\"annotation1\"\n" +
                 "                colspan = \"1\" > <divid = \"qstopLabel\" > <B>Query & nbsp;\n" +
                 "                Stop</B > < / div > < / TD >\n" +
                 "                        <\n" +
                 "                !--Target\n" +
                 "                Stop-- >\n" +
                 "                        <TD\n" +
                 "                class=\"annotation2\"\n" +
                 "                colspan = \"1\" >\n" +
                 "                        <inputtype = \"text\"\n" +
                 "                name = \"qstop\"\n" +
                 "                id = \"qstop\"\n" +
                 "                BGCOLOR = \"white\"\n" +
                 "                class=\"longInput\"\n" +
                 "                maxlength = \"50\"\n" +
                 "                value = \"<%=annotation.getTstop()%>\" >\n" +
                 "                        < / TD >\n" +
                 "                        < %\n" +
                 "            }%>\n" +
                 "            < / TR >\n" +
                 "                    <TR>\n" +
                 "                    < TD\n" +
                 "            ALIGN = \"left\"\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"1\" > <div> < strand > <B>Strand </B > < / div > < / TD >\n" +
                 "                    <TD\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"1\" >\n" +
                 "                    <selectname = \"strand\"\n" +
                 "            class=\"longDroplist\"\n" +
                 "            id = \"strand\"\n" +
                 "            align = \"left\"\n" +
                 "            BGCOLOR = \"white\" >\n" +
                 "                    < %\n" +
                 "                    String [] strands = new String[]{\"+\", \"-\"};\n" +
                 "            for (int j = 0; j < 2; j++) {\n" +
                 "                String sel = \"\";\n" +
                 "                if (strands[j].compareTo(annotation.getStrand()) == 0) {\n" +
                 "                    sel = \" selected\";\n" +
                 "                }\n" +
                 "                %>\n" +
                 "                <optionvalue = \"<%=strands[j]%>\" < %= sel % >> < %= strands[j] % > < / option >\n" +
                 "                        < %\n" +
                 "            }%>\n" +
                 "            < / select >\n" +
                 "                    < / TD >\n" +
                 "                    <TDALIGN = \"left\"\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"1\" > <divid = \"phase\" > <B>Phase </B > < / div >\n" +
                 "\n" +
                 "                    < / TD >\n" +
                 "                    <TDALIGN = \"left\"\n" +
                 "            class=\"annotation2\"\n" +
                 "            colspan = \"1\" >\n" +
                 "                    <select\n" +
                 "            class=\"longDroplist\"\n" +
                 "            align = \"left\"\n" +
                 "            name = \"phase\"\n" +
                 "            id = \"phase\" >\n" +
                 "                    < %\n" +
                 "                    String [] phases = new String[]{\"0\", \"1\", \"2\"};\n" +
                 "            for (int j = 0; j < phases.length; j++) {\n" +
                 "                String sel = \"\";\n" +
                 "                if (annotation.getPhase() != null) {\n" +
                 "                    if (phases[j].compareTo(annotation.getPhase()) == 0)\n" +
                 "                        sel = \" selected\";\n" +
                 "                } else {\n" +
                 "                    if (j == 0)\n" +
                 "                        sel = \" selected\";\n" +
                 "                }\n" +
                 "                %>\n" +
                 "                <optionvalue = \"<%=phases[j]%>\" < %= sel % >> < %= phases[j] % > < / option >\n" +
                 "                        < %\n" +
                 "            }\n" +
                 "            %>\n" +
                 "            < / select >\n" +
                 "                    < / TD >\n" +
                 "                    < / TR >");

            */
   /*
    sb.append("  <TR>\n" +
                    "                    <%if (errorFields.get(\"score\") == null) {\n" +
                    "                        %>\n" +
                    "                        <TDALIGN = \"left\"\n" +
                    "                        class=\"annotation2\"\n" +
                    "                        colspan = \"1\" > <divid = \"scoreLabel\" > <B>Score </B > < / div > < / TD > <\n" +
                    "                        !--SCORE-- >\n" +
                    "                                <TDALIGN = \"left\"\n" +
                    "                        class=\"annotation2\"\n" +
                    "                        colspan = \"1\" >\n" +
                    "                                <inputtype = \"text\"\n" +
                    "                        class=\"longInput\"\n" +
                    "                        name = \"score\"\n" +
                    "                        id = \"score\"\n" +
                    "                        BGCOLOR = \"white\"\n" +
                    "                        maxlength = \"50\"\n" +
                    "                        value = \"<%=annotation.getFscore()%>\" >\n" +
                    "                                < / TD >\n" +
                    "                                < %\n" +
                    "                    } else {\n" +
                    "                        %>\n" +
                    "                        <TDALIGN = \"left\"\n" +
                    "                        class=\"annotation1\"\n" +
                    "                        colspan = \"1\" > <divid = \"scoreLabel\" > <B>Score </B > < / div > < / TD > <\n" +
                    "                        !--SCORE-- >\n" +
                    "                                <TD\n" +
                    "                        class=\"annotation2\" >\n" +
                    "                                <inputtype = \"text\"\n" +
                    "                        class=\"longInput\"\n" +
                    "                        name = \"score\"\n" +
                    "                        id = \"score\"\n" +
                    "                        BGCOLOR = \"white\"\n" +
                    "                        maxlength = \"50\"\n" +
                    "                        value = \"<%=annotation.getFscore()%>\" >\n" +
                    "                                < / TD >\n" +
                    "                                < %\n" +
                    "                    }\n" +
                    "            %>\n" +
                    "            <TDALIGN = \"left\"\n" +
                    "            class=\"annotation2\"\n" +
                    "            colspan = \"2\" > & nbsp;\n" +
                    "            < / TD >\n" +
                    "                    < / TR >");

    sb.append(" <TR>\n" +
                    "                    <%if (errorFields.get(\"comments\") != null) {\n" +
                    "                        %>\n" +
                    "                        <TDALIGN = \"left\"\n" +
                    "                        class=\"annotation1\"\n" +
                    "                        colspan = \"1\" > <divid = \"labelcomment\" > <B>Comment </B > < / div > < / TD >\n" +
                    "                                < %\n" +
                    "                    } else {\n" +
                    "                        %>\n" +
                    "                        <TDALIGN = \"left\"\n" +
                    "                        colspan = \"1\"\n" +
                    "                        class=\"annotation2\" > <divid = \"labelcomment\" > <B>Comment </B > < / div > < / TD >\n" +
                    "                                < %\n" +
                    "                    }\n" +
                    "            %>\n" +
                    "            <TDalign = \"left\"\n" +
                    "            class=\"annotation2\"\n" +
                    "            colspan = \"3\" >\n" +
                    "                    <TEXTAREAname = \"comments\"\n" +
                    "            id = \"comments\"\n" +
                    "            align = \"left\"\n" +
                    "            rows = \"4\"\n" +
                    "            class=\"largeTextarea\"\n" +
                    "            value = \"<%=annotation.getComments()%>\" > < %= annotation.getComments() % > < / TEXTAREA >\n" +
                    "                    < / TD >\n" +
                    "                    < / TR >");

     sb.append("   <TR>\n" +
                    "                    <%if (errorFields.get(\"sequence\") != null) {\n" +
                    "                        %>\n" +
                    "                        <TDALIGN = \"left\"\n" +
                    "                        class=\"annotation1\" colspan=\"1\"><div id=\"sequences\"><B>Sequence</B></div></TD>\n" +
                    "                                        <%    }\n" +
                    "                            else {\n" +
                    "                                %>\n" +
                    "                                <TD ALIGN=\"left\" colspan=\"1\" class=\"annotation2\"><div id=\"sequences\"><B>Sequence</B></div></TD>\n" +
                    "                                        <% } %>");

     sb.append("<TD align=\"left\" class=\"annotation2\" colspan=\"3\">\n" +
             "                    <TEXTAREA name=\"sequence\" id=\"sequence\" align=\"left\" rows=\"4\" class=\"largeTextarea\"  value=\"<%=annotation.getSequences()%>\"><%=annotation.getSequences()%></TEXTAREA>\n" +
             "                            </TD>\n" +
             "                            </TR>\n" +
             "                            </TABLE>  ");
*/

    }


}
