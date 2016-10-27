# Matthew Linnell
# October 3, 2005
#-------------------------------------------------------------------------------
# Unit test for testing ActiveRecord mappings in Genboree and Genboree databases
# In essence, we check each table relationship in both directions
#-------------------------------------------------------------------------------

require 'test/unit'
require 'brl/db/dbrc'
#-------------------------------------------------------------------------------
# Test Genboree database
#-------------------------------------------------------------------------------
require 'genboree_active_record'

class TestGenobreeActiveRecord < Test::Unit::TestCase
    def setup
        dbrc = BRL::DB::DBRC.new( "~/.dbrc", 'genboree' )
        # Connect to the database
        ActiveRecord::Base.establish_connection(
            :adapter => "mysql",
            :host => "alanine.brl.bcm.tmc.edu",
            :username => dbrc.user,
            :password => dbrc.password,
            :database => dbrc.db
        )
    end
    
    def test_block_element
        # Make sure primary keys work
        assert BlockElement.find( 1 )
        # Text relationship to block
        assert BlockElement.find( 1 ).block
    end
    
    def test_block
        # Test primary keys
        assert Block.find( 2 )
        # Test relationship to block_element
        assert_equal 2, Block.find( 2 ).blockElements.size
    end
    
    def test_blockset
        # Test primary key mapping
        assert Blockset.find( 1 )
        # Test Relationship to block
        assert_equal 414403, Blockset.find( 1 ).blocks.size
        # Test relationship to thread
        assert_equal 2, Blockset.find( 1 ).threads.size
    end
    
    def test_thread
        # Test primary key mapping
        tmp = BlocksetThread.find_by_sql( "SELECT * FROM thread WHERE database_id = 351 AND blockset_id = 1" ).first
        assert tmp
        # Test relationship to blockset
        assert tmp.blockset.id == 1
        # Test relationship to genboree (for grabbing annotation database mappings)
        assert tmp.refseq
    end
    
    def test_style
        # Simply test that we mapped the table correctly since there are 
        # no relationships
        assert Style.find( 1 )
    end
    
    def test_color
        # Simply test that we mapped the table correctly since  
        # there are no relationships
        assert Color.find( 1 )
    end
    
    def test_entryPointTemplate
        # Simply test that we mapped the table correctly since  
        # there are no relationships
        assert EntryPointTemplate.find( 351 )
    end
    
    def test_newuser
        # Simply test that we mapped the table correctly since  
        # there are no relationships
        assert Newuser.find( 189 )
    end
    
    def test_subscription
        # Simply test that we mapped the table correctly since  
        # there are no relationships
        assert Subscription.find( 1 )
    end
    
    def test_refseq
        # Test primary key
        refseq = Refseq.find( 232 )
        assert refseq
        # Test relationship to grouprefseq
        assert refseq.grouprefseqs.include?( Grouprefseq.find( 329 ) )
        # Test relationship to searchConfig (via mapping table reSeqId2scid)
        assert refseq.searchConfigs
        # Test relationship to uplaod via refseq2upload
        assert refseq.uploads
        # Test relationship to BlocksetThread
        assert Refseq.find( 351 ).blocksetThreads.size > 0
        # Test relationshipo to genboreegroup via grouprefseq
        assert refseq.genboreegroups
    end
    
    def test_upload
        # Test primary key
        assert Upload.find( 31 )
        # Test relationship to refseq via refseq2upload
        assert Upload.find( 31 ).refseqs
        # Test relationship to genomeTemplate via tempate2upload
        assert Upload.find( 31 ).genomeTemplates
    end
    
    def test_genomeTemplate
        # Test primary key
        assert GenomeTemplate.find( 25 )
        # Test relationship to chromosomeTemplate
        assert_equal 1, GenomeTemplate.find( 25 ).chromosomeTemplates.size
        # Test relationship to searchConfig via template2scid
        assert GenomeTemplate.find( 25 ).uploads
        # Test relationship to upload via tempalte2upload
    end
    
    def test_chromosomeTemplate
        # Test primary key
        assert ChromosomeTemplate.find( 25 )
        # Test relationship to genomeTemplate
        assert ChromosomeTemplate.find( 25 ).genomeTemplate

    end
    
    def test_searchConfig
        # Test primary key
        assert SearchConfig.find( 1 )
        # Test relationship to genomeTemplate via tempalte2scid
        assert SearchConfig.find( 1 ).genomeTemplates
        # Test relationship to refseq via refSeqId2scid
        assert SearchConfig.find( 1 ).refseqs
    end
    
    def test_grouprefseq
        # Test primary key
        group = Grouprefseq.find( 329 )
        assert group.groupId == 3
        # Test relationship to genboreegroup
        assert group.genboreegroup == Genboreegroup.find( 3 )
        # Test relationship to refseq
        assert group.refseq.refSeqId == 232
    end
    
    def test_genboreegroup
        # Test primary key
        group = Genboreegroup.find( 3 )
        assert_equal "Public", group.groupName
        # Test relationship to usergruop
        assert group.usergroups.include?( Usergroup.find( 732 ) )
        # Test relationship to grouprefseq
        assert group.grouprefseqs.include?( Grouprefseq.find( 329 ) ) 
        # Test relationship to refseq
        assert group.refseqs
    end
    
    def test_usergroup
        # Test primary key
        userg = Usergroup.find( 732 )
        assert userg.userId == 82
        # Test relationship to genboreeuser
        assert userg.genboreeuser == Genboreeuser.find( 82 ) 
        # Test relationship to genboreegroup
        assert userg.genboreegroup.groupName == "Public"
    end
    
    def test_genboreeuser
        # Find a specific user based on name
        user = Genboreeuser.find_by_name( "mlinnell" )
        assert user.name == "mlinnell"
        # Check that the primary key is correct
        user = Genboreeuser.find( user.userId )
        assert user.name == "mlinnell"
        # Test relationship to usergroup
        groups = user.usergroups
        assert_equal 5, groups.size
        assert groups.include?( Usergroup.find( 732 ) ) 
    end
end

#-------------------------------------------------------------------------------
# Test Genboree annotations databases
#-------------------------------------------------------------------------------
require 'genboree_database_active_record'
class TestGenboreeAnnotationsActiveRecord < Test::Unit::TestCase
    def setup
        dbrc = BRL::DB::DBRC.new( "~/.dbrc", 'genboree_r_e9a07d1c4a7855eabdab1c737159d187' )
        # Connect to the database
        ActiveRecord::Base.establish_connection(
            :adapter => "mysql",
            :host => "alanine.brl.bcm.tmc.edu",
            :username => dbrc.user,
            :password => dbrc.password,
            :database => dbrc.db
        )
    end
    
    def test_style
        # Test primary key
        assert Style.find( 1 )
        # Test relationship to ftype via featuretostyle
        assert Style.find( 1 ).ftypes
    end
    
    def test_ftype
        # Test primary key
        assert Ftype.find( 1 )
        # Test relationship to style via feature to style
        assert Ftype.find( 1 ).styles
        # Test relationship to link via featuretolink
        assert Ftype.find( 1 ).links
        # Test relationship to color via featuretocolor
        assert Ftype.find( 1 ).colors
        # Test relationship to fdata2 via fidText
        assert Ftype.find( 1 ).fdata2s
        # Test relationship to gclass via ftype2gclass
        assert Ftype.find( 1 ).gclasses
        # Test relationship to featureurl
        assert Ftype.find( 1 ).featureurls
        # Test relationship to featuredisplay
        assert Ftype.find( 1 ).featuredisplays
        # Test relationship to featuresort
        assert Ftype.find( 1 ).featuresorts
    end
    
    def test_featuresort
        # Test primary key
        assert Featuresort.find( 4 )
        # Test relationship to ftype
        assert Featuresort.find( 4 ).ftype
    end
    
    def test_gclass
        # Test primary key
        assert Gclass.find( 1 )
        # Test relationship to ftype via ftype2gclass
        assert Gclass.find( 1 ).ftypes
    end
    
    def test_color
        # Test primary key
        assert Color.find( 1 )
        # Test relationship to ftype via featuretocolor
        assert Color.find( 1 ).ftypes
    end

    def test_link
        # Test primary key
        assert Link.find( 1 )
        # Test relationship to ftype
        assert Link.find( 1 ).ftypes
    end
    
    def test_featuredisplay
        # Test primary key
        assert Featuredisplay.find( 4 )
        # Test relationship to ftype
        assert Featuredisplay.find( 4 ).ftype
    end
    
    def test_featureurl
        # Test primary key
        assert Featureurl.find( 4 )
        # Test relationship to ftype
        assert Featureurl.find( 4 ).ftype
    end
    
    def test_fidText
        # Test primary key
        assert FidText.find( 678 )
        # Test relationship to fdata2
        assert FidText.find( 678 ).fdata2
        # Test relationship to ftype
        assert FidText.find( 678 ).ftype
    end
    
    def test_fdata2
        # Test primary key
        assert Fdata2.find( 28301 )
        # Test relationship to fidText
        assert Fdata2.find( 28301 ).fidTexts
        # Test relationship to ftype
        assert Fdata2.find( 28301 ).ftype
        # Test relationship to fref
        assert Fdata2.find( 28301 ).fref
    end
    
    def test_fref
        # Test primary key
        assert Fref.find( 1 )
        # Test relationship to fdata2
        assert Fref.find( 1 ).fdata2s
        # Test relationship to image_cache
        assert Fref.find( 1 ).imageCaches
        # Test relationship to ridSequence via rid2ridSeqId
        assert Fref.find( 1 ).ridSequences
    end
    
    def image_cache
        # Test primary key
        assert ImageCache.find( 1 )
        # Test relationship to fref
        assert ImageCache.find( 1 ).fref
    end
    
    def test_ridSequence
        # Test primary key
        assert RidSequence.find( 1 )
        # Test relationship to fref via rid2ridSeqId
        assert RidSequence.find( 1 ).frefs
    end
    
    def test_fdna
    end
    
    def test_fattribute
    end
end
