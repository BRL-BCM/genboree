using GLib;
using Json;
using Gee;


/*

Here is the original template for the preferences. In the program I divided into three strings to facilitate
the generation of the default values that will be overwritten by the json files in database or files
{
  "BROWSER":
  {
    "canvasWidth"          : 680,             # Width of browser canvas (not a track-specific setting)
    "showEmptyTracks"      : false,
    "showContinuationHints": false,
    "displayTrackDesc"     : true,
    "tracks" :                                # Hash of track settings (keyed by track name)
    {
      "myTrack:0123":                         # Settings for the track "myTrack:0123"
      {
        "windowingMethod"  : "AVG",
        "pxHeight"         : 130,
        "maxScore"         : 546,
        "minScore"         : 5,
        "useLog"           : true,
        "logType"          : "log10",
        "scoreScaling"     : "global",
        "rank"             : 3,
        "color"            : "#0A0D0F",
        "style"            : "Simple Rectangle"
        "expansion"        : "Compact",
        "attributesToDisplay" :                # Hash of attributes-to-display and their settings (keyed by attribute name)
        {
          "pxHeight":                          # Settings for the attribute "gbTrackPxHeight" (which will thus be displayed since it is in the Hash)
          {
            "flag"   : 0,
            "rank"   : 1,
            "color"  : "#FF0000"
          }
        },
        "description"        : "This track was created artificialy by UCSC blah blah more description...",
      }
    }
  }
}
*/


private class DefaultBrowser : GLib.Object 
{
// The browser variable contains the default values for the browser view
// the standar size of the canvas is 680, the empty tracks are not display. 
// the browser do not display annotations that are outside the regular range
// the browser normally display the track description.
   private string defaultBrowserJsonString = """ 
   {
      "BROWSER": 
      {  
         "canvasWidth"  : 680,  
         "showEmptyTracks"  : false,  
         "showContinuationHints" : false,
         "displayTrackDesc"     : true
      }
   }""";

// This string contains the default track values
			    
   private string defaultTrackJsonString = """
   {
     "minScore": 5,
     "scoreScaling": "global",
     "logType": "log10",
     "maxScore": 546,
     "pxHeight": 130,
     "color": "#000000",
     "rank": 3,
     "useLog": true,
     "windowingMethod": "AVG",
     "expansion": "Compact",
     "style": "Simple Rectangle",
     "description"   : "Default description..."
   }""";

// This string contains the default attributes to display, the pxHeight won't be display because the flag is 0

   private string defaultAttributesToDisplayJsonString = """
   {
       "pxHeight":
       {
	   "flag"   : 0,
	   "rank"   : 1,
	    "color"  : "#FF0000"
      }
   }""";

/*Here is a simple constructor for the class */
   public DefaultBrowser()
   {
   }
/* Here is a simple destructor for the class */

   ~DefaultBrowser() 
   { 
   }

    void returnValueNode(Json.Node the_node) 
    {
      string typeName = "";
      int codeNumber = 0;
      
      if(the_node != null)
      {
         typeName = the_node.type_name();        
      }
      
      if(typeName == "gint" || typeName == "gint32" || typeName == "gint64")
      {
         codeNumber = 1;    
      }
      else if(typeName == "gboolean")
      {
         codeNumber = 2;
      }
      else if(typeName == "string" || typeName == "gchararray")
      {
         codeNumber = 3;
      }
      else if(typeName == "JsonObject")
      {
         codeNumber = 4;
      }
      else
      {
         codeNumber = 0;
      }


     switch (codeNumber) 
     {
         case 1:
             int tempValue = the_node.get_int();
             stdout.printf ( " %d\n",  tempValue);
             return;
         case 2:
             bool tempValue = the_node.get_boolean();
             stdout.printf ( " %s\n",  tempValue ? "TRUE" : "FALSE");
             return;
         case 3:
             string tempValue = the_node.get_string();
             stdout.printf ( " %s\n",  tempValue);
             return;
         case 4:
             //Json.Object tempValue = the_node.get_object();
             stdout.printf ( " is and object\n");
             return;
         default:
         stdout.printf ( " is NULL \n");
             return; 
     }
    }



/* Here is an example of how to read a json object */
    
    public void printTrackInfo(Json.Object browserObject)
    {
    	foreach (var brObj in browserObject.get_members())  
      {
        	stdout.printf ("Browser property  %s with a value of ", brObj);
        	unowned Json.Node tempNode = browserObject.get_member(brObj);
        	 this.returnValueNode(tempNode);
        	if(brObj == "tracks")
        	{
        		Json.Object tracks2 = browserObject.get_member(brObj).get_object();
        		foreach(var trkObj in tracks2.get_members())
		      {
		         stdout.printf("the name is %s\n", trkObj);
		         Json.Object trackOne = tracks2.get_member(trkObj).get_object();
		         foreach(var mem in trackOne.get_members())
		         {
		            stdout.printf ("\ttrack att %s", mem); 
		            unowned Json.Node tempNode2 = trackOne.get_member(mem);
        	         this.returnValueNode(tempNode2);
		            if(mem == "attributesToDisplay") 
		            {
                     Json.Object attributes = trackOne.get_member(mem).get_object();
                     if(attributes.has_member("pxHeight"))
                     {
                        foreach(var att in attributes.get_member("pxHeight").get_object().get_members())
       		            {
                           stdout.printf("\t\tInside the attributes name %s\n", att);
       			         }
                     }	
                  }
               }
		      }	
        	}    	
      }
    }

/* This method loads the default strings on the top of the file and create a template object */

   public Json.Object createDefaultBrowserObject(Gee.ArrayList trackNames)
   {
      Json.Parser parser = null;
      Json.Object browserObject = null;
      Json.Object trackObject = null;
      unowned Json.Node root = null;
      try
      {
         if(!trackNames.is_empty)
         {
            parser = new Json.Parser (); 
	         parser.load_from_data(defaultBrowserJsonString, -1);
            root = parser.get_root ();
            browserObject = root.get_object().get_member ("BROWSER").get_object();
            parser.load_from_data(defaultTrackJsonString, -1);
            Json.Node trackNode = parser.get_root().copy();
	         trackObject = trackNode.get_object();
	         parser.load_from_data(defaultAttributesToDisplayJsonString, -1);
	         Json.Node attributesNode = parser.get_root().copy();
	         trackObject.add_member("attributesToDisplay", attributesNode.copy());
	         Json.Node tracks = new Json.Node(0);
	         tracks.set_object(new Json.Object());
	
	         for(int i = 0; i < trackNames.size; i++)
            {
               tracks.get_object().add_member((string)trackNames.get(i), trackNode.copy());  	       	
            }
	
            browserObject.add_member("tracks",  (owned)tracks); 
            parser.dispose();
         }
        else
         {
         	stdout.printf("the trackNames is empty\n");	
         }  
      }
      catch (Error e) 
      {
         warning ("%s", e.message);
      }
      return browserObject;  
 }

 /* This method is a used to create the object from a json string extracted from the database */ 
 public Json.Object readJsonString(Gee.ArrayList trackNames, Json.Object defaultBrowser, string bigString)
 {
      Json.Parser parser = null;
      Json.Object browserObject = null;
      Json.Object tracksObject = null;
      Json.Object defaultTrackObject = null;
      unowned Json.Node root = null;
      Json.Object track = null;
      Json.Object defaultTrack = null;
      
      try
      {
         if(!trackNames.is_empty)
         {
            parser = new Json.Parser (); 
            parser.load_from_data(bigString, -1); 
            root = parser.get_root ();
            browserObject = root.get_object().get_member ("BROWSER").get_object();

            foreach (var brObj in browserObject.get_members())  
            { 
		           if(brObj == "tracks")
		           {

                  tracksObject = browserObject.get_member("tracks").get_object();
                  defaultTrackObject = defaultBrowser.get_member("tracks").get_object();
	               for(int i = 0; i < trackNames.size; i++)
                  {
                     if(tracksObject.has_member((string)trackNames.get(i)))
                     {
                        track = tracksObject.get_member((string)trackNames.get(i)).get_object();
                        if(defaultTrackObject.has_member((string)trackNames.get(i)))
                        {
                           defaultTrack = defaultTrackObject.get_member((string)trackNames.get(i)).get_object();
                           foreach(var mem in track.get_members())
		                     {		            	    
		               	      if(mem == "attributesToDisplay") 
		                        {
                                 Json.Object attributes = track.get_member(mem).get_object();
                                 Json.Object defaultAttributes = defaultTrack.get_member(mem).get_object();

                                 foreach(var att in attributes.get_members())
             		               {
             		                 if(!defaultAttributes.has_member(att))
             		                 {
             		                   defaultAttributes.add_member(att, attributes.get_member(att).copy()); 
             		                 }
             		                 else
             		                 {
             		                    		defaultAttributes.remove_member(att);
		                                    defaultAttributes.add_member(att, attributes.get_member(att).copy());
             		                 }
             			            }	
		                        }
                              else 
                              {
                               if(track.has_member(mem))
                                 {
		                              if(!defaultTrack.has_member(mem))
		                              {
		                                 defaultTrack.add_member(mem, track.get_member(mem).copy());
		                              }
		                              else
		                              {
		                                    defaultTrack.remove_member(mem);
		                                    defaultTrack.add_member(mem, track.get_member(mem).copy());
		                              }
		                           }
		                           
		                        }      
		                     }
                           
                        }
                        else
                        {
                           defaultTrackObject.add_member((string)trackNames.get(i), tracksObject.get_member((string)trackNames.get(i)).copy());
                        }
                     }
                 }
	         }
	         else
	         {
	               if(defaultBrowser.has_member(brObj))
	               {
                    defaultBrowser.remove_member(brObj);
                    defaultBrowser.add_member(brObj, browserObject.get_member(brObj).copy());
	               }
	               else
	               {
	                  defaultBrowser.add_member(brObj, browserObject.get_member(brObj).copy());
	               }  
	         }
	          
         } 
         parser.dispose();
         }
         else
         {
         	stdout.printf("the trackNames is empty\n");	
         } 
                   
      }
      catch (Error e) 
      {
         warning ("%s\n", e.message);
      }

      return defaultBrowser;   
 }
 

  /* This method is used to facilitate using an existing Hash table created by the c program and 
  transform the keys into an array list that is more easy to use in vala
   */ 
  ArrayList<string> extractKeysFromHashTable(HashTable trackHash)
  {
    var trackNames = new ArrayList<string>();
    GLib.List keys = null;

    
    keys = trackHash.get_keys<string>();
    for(int ii = 0; ii < keys.length(); ii++)
    {
        trackNames.add((string)keys.nth_data(ii)); 
    }
       
   return trackNames;
  
  }
 
   /* This method is an interfase to take a hashtable with the name of the tracks and a string with the json
   properties and return a json object
   */
 
  Json.Object createJsonObject (HashTable trackHash, string jsonString, Json.Object templateObject)
  {
    Json.Object browserObject = null;
    
    ArrayList<string> trackNames = this.extractKeysFromHashTable(trackHash);
    
    browserObject = this.readJsonString(trackNames, templateObject, jsonString); 
    return browserObject;

  }
  
    /* This method is an interfase to take a hashtable with the name of the tracks and a string with the json
   properties and return a json object
   */
 
  Json.Object createTemplateJsonObject (HashTable trackHash)
  {
    ArrayList<string> trackNames = this.extractKeysFromHashTable(trackHash);
    Json.Object browserObject = this.createDefaultBrowserObject(trackNames);
    
    return browserObject;
  } 
  
 
  
   static int main (string[] args)
  {
    string fileName = "/usr/local/brl/home/manuelg/officialOptimizedGB/bigJsonFile.json";
    string def = "/usr/local/brl/home/manuelg/officialOptimizedGB/default.json";
    string jsonString = null;
    ulong len;
    string defJson = null;
    ulong defLen;
    HashTable tempTrackHash = new HashTable<string, string>(str_hash, str_equal);
    tempTrackHash.insert("track:one", "one");
    tempTrackHash.insert("track:two", "two");
    tempTrackHash.insert("track:three", "three");
    tempTrackHash.insert("track:four", "four");

    var testBrowser = new DefaultBrowser();
    try
    {
      FileUtils.get_contents(def, out defJson, out defLen);
    }
    catch (Error e) 
    {
         warning ("%s", e.message);
    }
    
    try
    {
      FileUtils.get_contents(fileName, out jsonString, out len);
    }
    catch (Error e) 
    {
         warning ("%s", e.message);
    }
 
    Json.Object templateObj = testBrowser.createTemplateJsonObject(tempTrackHash);
    
    stdout.printf("Here is the template------------------------\n");
    testBrowser.printTrackInfo(templateObj);
    
    
    Json.Object groupDefaultObj = testBrowser.createJsonObject(tempTrackHash, defJson, templateObj);
    stdout.printf("\n\nHere is the default group ------------------------\n");
    stdout.flush ();
    testBrowser.printTrackInfo(groupDefaultObj);
    
    Json.Object browserObject = testBrowser.createJsonObject(tempTrackHash, jsonString, groupDefaultObj);
    
    stdout.printf("\n\nHere is the finalt browserObject ------------------------\n");    
    testBrowser.printTrackInfo(browserObject);
            
    return 0;
  }   
    
    
}
