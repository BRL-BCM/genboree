package org.genboree.svg.image;


public class SingleImageGenerator{
    private String dir = null;
    private String xmlFile = null;
    private int userId;
    private String chromToDisplay = null;
    private boolean production = true;
    private boolean onlyGenomic = false;



    public static void printUsage(){
        System.out.print("usage: program ");
        System.out.println("-xmlFile visulization.xml -userId userId -dir directory [ -chromName chromosome_name -onlyGenomic ]");
        return;
    }


    public static void main(String[] args) throws Exception{
    ImageGenerator generateAllImages;
        if(args.length == 0 )
        {
            printUsage();
            System.exit(-1);
        }
        SingleImageGenerator big = new SingleImageGenerator();

        if(args.length >= 2)
        {

            for(int i = 0; i < args.length; i++ )
            {

                if(args[i].compareToIgnoreCase("-dir") == 0){
                    if(args[i+ 1] != null){
                        big.dir = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-userId") == 0){
                    if(args[i+ 1] != null){
                        big.userId = Integer.parseInt(args[i + 1]);
                    }
                }
                else if(args[i].compareToIgnoreCase("-xmlFile") == 0){
                    if(args[i+ 1] != null){
                        big.xmlFile = args[i + 1];
                    }
                }
                else if(args[i].compareToIgnoreCase("-chromName") == 0){
                     if(args[i+ 1] != null){
                        big.chromToDisplay = args[i + 1];
                        big.production = false;
                    }
                }
                else if(args[i].compareToIgnoreCase("-onlyGenomic") == 0){
                        big.onlyGenomic = true;
                }
            }

        }
        else
        {
            printUsage();
            System.exit(-1);
        }

        if(big.dir == null)
        {
            big.dir = "/tmp";
        }

        if(big.production && big.chromToDisplay == null && !big.onlyGenomic)
            generateAllImages = new ImageGenerator(big.userId,big.xmlFile, big.dir);
        else if(big.onlyGenomic)
            generateAllImages = new ImageGenerator(big.userId,big.xmlFile, big.dir, big.onlyGenomic);
        else
            generateAllImages = new ImageGenerator(big.userId,big.xmlFile, big.dir, big.production, big.chromToDisplay);

    }

}