package org.genboree.util;

import org.genboree.upload.LffConstants;
import org.genboree.upload.Uploader;

import java.io.*;
import java.util.Hashtable;
import java.util.HashMap;
import java.util.Vector;


public class CreateLff {

//    protected int sizeFragment= 2000000;
    protected int sizeFragment= 20000000;
    protected String className = "SEQUENCING_CENTERS";
    protected String name1 = "BCM";
    protected String name2 = "Broad";
    protected String name3 = "WU";
    protected String name4 = "All";
    protected String score1 = "1.00";
    protected String score2 = "0.50";
    protected String score3 = "0.00";
    protected String score4 = "-1.00";
    protected String[] scores = {score1, score2, score3, score1, score2, score3, score1, score2, score3 };
    protected String[] names = {name1, name2, name3, name1, name2, name3, name1, name2, name3 };

//    protected String[] chromosomeNames = null;
//    protected int[] chromosomeSizes = null;
        protected String[] chromosomeNamesHg16 = {
						"chr1",
                        "chr2",
                        "chr3",
                        "chr4",
                        "chr5",
                        "chr6",
                        "chr7",
                        "chr8",
                        "chr9",
						"chr10",
						"chr11",
						"chr12",
						"chr13",
						"chr14",
						"chr15",
						"chr16",
						"chr17",
						"chr18",
						"chr19",
						"chr20",
						"chr21",
						"chr22",
						"chrM",
						"chrX",
						"chrY"
                        /*,
                        "chr10_random",
                        "chr13_random",
                        "chr15_random",
                        "chr17_random",
                        "chr18_random",
                        "chr19_random",
                        "chr1_random",
                        "chr2_random",
                        "chr3_random",
                        "chr4_random",
                        "chr5_random",
                        "chr6_random",
                        "chr7_random",
                        "chr8_random",
                        "chr9_random",
                        "chrUn_random",
                        "chrX_random"
                        */
					};
    protected int[] chromosomeSizesHg16 = {
						246127941, // chr1
                        243615958, // chr2
                        199344050, // chr3
                        191731959, // chr4
                        181034922, // chr5
                        170914576, // chr6
                        158545518, // chr7
                        146308819, // chr8
                        136372045, // chr9
						135037215, // chr10
						134482954, // chr11
						132078379, // chr12
						113042980, // chr13
						105311216, // chr14
						100256656, // chr15
						90041932,  // chr16
						81860266, //  chr17
						76115139, //  chr18
						63811651, //  chr19
						63741868, //  chr20
						46976097, //  chr21
						49396972, //  chr22
						16569, //     chrM
						153692391, // chrX
						50286555 //   chrY
					};

        protected String[] chromosomeNamesHg17 = {
						"chr1",
                        "chr2",
                        "chr3",
                        "chr4",
                        "chr5",
                        "chr6",
                        "chr7",
                        "chr8",
                        "chr9",
						"chr10",
						"chr11",
						"chr12",
						"chr13",
						"chr14",
						"chr15",
						"chr16",
						"chr17",
						"chr18",
						"chr19",
						"chr20",
						"chr21",
						"chr22",
						"chrM",
						"chrX",
						"chrY"
					};
    protected int[] chromosomeSizesHg17 = {
						245522847, // chr1
                        243018229, // chr2
                        199505740, // chr3
                        191411218, // chr4
                        180857866, // chr5
                        170975699, // chr6
                        158628139, // chr7
                        146274826, // chr8
                        138429268, // chr9
						135413628, // chr10
						134452384, // chr11
						132449811, // chr12
						114142980, // chr13
						106368585, // chr14
						100338915, // chr15
                        88827254,  // chr16
						78774742, //  chr17
						76117153, //  chr18
                        63811651, //  chr19
                        62435964, //  chr20
						46944323, //  chr21
						49554710, //  chr22
						16571, //     chrM
                        154824264, // chrX
						57701691 //   chrY
					};
    protected String type = "Sequencing";
    protected String subtype = "Centers";
    protected String strand = "+";
    protected String phase = ".";
    protected String tstart = "0";
    protected String tend = "0";
    protected String comments = ".";
    protected String sequence = ".";

    public CreateLff()
    {
    }

    public void createTrack2(String assembly)
    {
        int serial = 1;
        int missingPart = 0;
        int sizeNames = 0;

        String[] chromosomeNames = null;
        int[] chromosomeSizes = null;

        if(assembly.equalsIgnoreCase("Hg16"))
        {
            chromosomeNames = chromosomeNamesHg16;
            chromosomeSizes = chromosomeSizesHg16;
        }
        else if(assembly.equalsIgnoreCase("Hg17"))
        {
            chromosomeNames = chromosomeNamesHg17;
            chromosomeSizes = chromosomeSizesHg17;
        }
        else
            return;


        for(int chrom = 0 ; chrom < chromosomeNames.length; chrom++)
        {
            int sizeChrom = 0;

            while( sizeChrom < chromosomeSizes[chrom]  )
            {
                System.out.print(
                        className + "\t" + names[sizeNames] + serial + "\t" +
                        type + "\t" + subtype + "\t" + chromosomeNames[chrom] + "\t" + (sizeChrom +1) + "\t"
                );

                if(missingPart > 0 && sizeChrom == 0)
                {
                    sizeChrom += missingPart;
                    missingPart = 0;
                }
                else
                    sizeChrom += sizeFragment;

                if(sizeChrom > chromosomeSizes[chrom])
                {
                    missingPart = sizeChrom - chromosomeSizes[chrom];
                    sizeChrom = chromosomeSizes[chrom];
                }
                System.out.println( sizeChrom + "\t" + strand + "\t" + phase + "\t" + scores[sizeNames] + "\t" +
                        tstart + "\t" + tend + "\t" + comments + "\t" + sequence
                );
                if(missingPart == 0)
                {
                    sizeNames++;
                    serial++;
                    if(sizeNames >= names.length) sizeNames = 0;
                }
            }
        }
    }


/*
    public void createTrack()
    {

        int currentName = 0;
        int serial = 1;

        for(int chrom = 0 ; chrom < chromosomeNames.length; chrom++)
        {
            int sizeChrom = 0;
            int sizeNames = currentName;

            while( (sizeChrom  + sizeFragment) < chromosomeSizes[chrom]  )
            {
                System.out.print(
                        className + "\t" + names[sizeNames] + serial + "\t" +
                        type + "\t" + subtype + "\t" + chromosomeNames[chrom] + "\t" + (sizeChrom +1) + "\t"
                );
                sizeChrom += sizeFragment;
                System.out.println( sizeChrom + "\t" + strand + "\t" + phase + "\t" + scores[sizeNames] + "\t" +
                        tstart + "\t" + tend + "\t" + comments + "\t" + sequence
                );
                sizeNames++;
                serial++;
                if(sizeNames >= names.length) sizeNames = 0;
            }
        }
    }
  */

    public static void printUsage()
    {
        System.out.print("usage: CreateLff ");
        System.out.println(
                "-a assembly \n " +
                "Optional [\n" +
                "]\n");
        return;
    }



    public static void main(String[] args)
    {
        String assembly = null;

         if(args.length == 0 )
         {
             printUsage();
             System.exit(-1);
         }


         if(args.length >= 1)
         {

             for(int i = 0; i < args.length; i++ )
             {
                 if(args[i].compareToIgnoreCase("-a") == 0)
                 {
                     i++;
                     if(args[i] != null)
                     {
                         assembly = args[i];
                     }
                 }
             }

         }
         else
         {
             printUsage();
             System.exit(-1);
         }


        CreateLff newTrack = new CreateLff();
        newTrack.createTrack2(assembly);



    }


}
