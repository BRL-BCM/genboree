require 'brl/blockSet/blocksetUtil.rb'
require 'test/unit'
include BRL::BlockSet

class TestTba < Test::Unit::TestCase
    def setup
        @human, @hfsource = "genboree_r_cbc0598452e95359ec7ad48c1585b9fe", "hg17.tba"
        @mouse, @mfsource = "genboree_r_8d3eafb24ca013552f0c41eb702c8d3e", "mm5.tba"
    end

    #---------------------------------------------------------------------------
    # TBA Jumping Tests
    #---------------------------------------------------------------------------
    
    # General test for jump funcationality.  This test actually calculates the jump
    # parameters for 23 jumps (the source base, mm5:chr4:152589360 has been aligned 
    # to 23 locations on hg17).  This includes both long and short sequences,
    # as well as the first base, and lastbase+1 border case.
    def test_jump1
        answer = ["chr14:18434770", "chr14:18435153", "chr14:18892369", "chr14:18893163", "chr14:18896966", "chr17:15608428", "chr17:20423318", "chr17:21500943", "chr17:21747526", "chr20:25700997", "chr22:14469579", "chr22:14470373", "chr22:14474637", "chr22:14839152", "chr22:14839946", "chr22:18019098", "chr2:132390811", "chr2:132391605", "chr5:177159743", "chr7:57497252", "chr7:57497687", "chr9:44368317", "chr9:44372865", "chr9:44373795"]
        assert_equal( answer, jump( @mouse, @human, 152589360, 4, @mfsource ) )
    end
    
    # This tests when jumping *into* a gapped region.  Expected behaviour:
    # round up/down based on which side we are closest to.
    # This test case should contain an element which should round up
    def test_jump2
        answer = ["chr14:18892181", "chr14:18892885", "chr14:18896743", "chr17:15608187", "chr17:20423095", "chr17:21500702", "chr22:14469391", "chr22:14470095", "chr22:14474414", "chr22:14838965", "chr22:14839741", "chr2:132390619", "chr2:132391327", "chr5:177159541", "chr9:44368074", "chr9:44372675"]        
        assert_equal( answer, jump( @mouse, @human, 152589145, 4, @mfsource ) )
    end
    
    # This tests when jumping *into* a gapped region.  Expected behaviour:
    # round up/down based on which side we are closest to.
    # This test case should contain an element which should round down
    def test_jump3
        answer = ["chr14:18892179", "chr14:18892883", "chr14:18896742", "chr17:15608185", "chr17:20423093", "chr17:21500700", "chr22:14469389", "chr22:14470093", "chr22:14474413", "chr22:14838963", "chr22:14839739", "chr2:132390617", "chr2:132391325", "chr5:177159540", "chr9:44368072", "chr9:44372673"]
        assert_equal( answer, jump( @mouse, @human, 152589143, 4, @mfsource ) )
    end
    
    # This tests when jumping *into* a gap region which we cannot round
    # down because the target gene starts with a gap
    # e.g. --------ACTCAGTACG...
    def test_jump4
        answer = ["chr4:152589283"]
        assert_equal( answer, jump( @human, @mouse, 21500853, 17, @hfsource  ) )
    end
    
    # This tests when jumping *into* a gap region which we cannot round
    # up because the target gene ends with a gap
    # e.g. ...ACTCAGTACG--------
    def test_jump5
        answer = ["chr4:152589399"]
        assert_equal( answer, jump( @human, @mouse, 44368373, 9, @hfsource ) )
    end

    # This tests when jumping is not possible
    def test_jump6
        assert_equal( [], jump( @human, @mouse, 14473732, 22, @hfsource ) )
    end
    
    #---------------------------------------------------------------------------
    # TBA hit tests
    #---------------------------------------------------------------------------
    def test_hit1
        # This has not yet been hand verified
        answer = [696286, 696294, 2197018, 3182966, 3183017, 3183034, 4518329, 4518336, 4519605, 4519613, 4519614, 4519671, 5133449, 5147845, 5150293, 5150468, 5682703, 5838435, 5838441, 5838515, 5839637, 5839651, 5846564]
        assert_equal( answer, hit( @mouse, 152589360, 152589360, 4, @mfsource) )
    end
    
    def test_hit2
        # This has not yet been hand verified
        answer = [696281, 696289, 2197018, 3182959, 3183011, 4519601, 4519608, 4519666, 5133448, 5147844, 5150292, 5838430, 5838439, 5838511, 5839632, 5839644]
        assert_equal( answer, hit( @mouse, 152589145, 152589145, 4, @hfsource) )
    end
end
