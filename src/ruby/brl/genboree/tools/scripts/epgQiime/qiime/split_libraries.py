#!/usr/bin/env python
#file split_libraries.py

"""Performs preprocessing steps for barcoded library analysis, e.g. 454.

Specifically, does the quality-filtering step (using several criteria) and
renames each read with the appropriate library id.

This module reads the linker+primer sequence from the input mapping file, and
associates these with the barcodes from the mapping file.  If a barcode is 
read that does not correspond to any in the mapping file, this module checks
against all possible primers from the mapping file.  A rare situation could 
arise if a barcode does not match any from the mapping file (either because
of sequencing errors or because the mapping file is incomplete) and variations
of the same primer are used for sequencing (e.g., a truncated form of the same
primer), where it is impossible to distinguish what primer was actually used
to amplify a given sequence.  In these cases, portions of the given sequence
are sliced out in ascending order of primer sizes and compared to all possible
primers from the mapping file.  The first matching primer is considered a hit
for the purposes of the determining where a primer ends and the actual
sequence data begins.  Because of this, one should be careful about using
truncated forms of the same primer with this module.  The -c option can be
used to disable attempts at barcode correction, and sequences that do not
have a barcode that matches the mapping file will not be recorded.
"""

__author__ = "Rob Knight and Micah Hamady"
__copyright__ = "Copyright 2010, The QIIME Project" 
__credits__ = ["Rob Knight", "Micah Hamady", "Greg Caporaso", "Kyle Bittinger","Jesse Stombaugh","William Walters","Jens Reeder"] #remember to add yourself
__license__ = "GPL"
__version__ = "1.2.0"
__maintainer__ = "William Walters"
__email__ = "rob@spot.colorado.edu, william.a.walters@colorado.edu"
__status__ = "Release"

import re
from gzip import GzipFile
from os import mkdir, stat
from collections import defaultdict

from numpy import array, mean, arange, histogram
from numpy import __version__ as numpy_version

import warnings
warnings.filterwarnings('ignore', 'Not using MPI as mpi4py not found')
from cogent.parse.fasta import MinimalFastaParser
from cogent.seqsim.sequence_generators import SequenceGenerator, IUPAC_DNA
from cogent.core.moltype import IUPAC_DNA_ambiguities
from cogent import DNA, LoadSeqs
from cogent.align.align import make_dna_scoring_dict, local_pairwise

from qiime.check_id_map import process_id_map
from qiime.barcode import correct_barcode
from qiime.hamming import decode_barcode_8
from qiime.golay import decode as decode_golay_12
from qiime.format import format_histograms
from qiime.parse import QiimeParseError, parse_qual_scores
from qiime.util import create_dir

## Including new=True in the histogram() call is necessary to 
## get the correct result in versions prior to NumPy 1.2.0,
## but the new keyword will be removed in NumPy 1.4. In NumPy 1.2.0 
## or later, new=True raises a Warning regarding 
## deprecation of new. One solution to this is to check the 
## numpy version, and if it's less than 1.2.0, overwrite histogram 
## with new=True as the default. This avoids a deprecation warning message 
## in versions 1.2.0 through 1.3.*, and a try/except to handle errors from 
## versions 1.4.0 or later. 

numpy_version = re.split("[^\d]", numpy_version)
numpy_version = tuple([int(i) for i in numpy_version if i.isdigit()])
if numpy_version < (1,3,0):
    numpy_histogram = histogram
    def histogram(a, bins=10, range=None, normed=False, weights=None):
        return numpy_histogram(a,bins=bins,range=range,\
         normed=normed,weights=weights,new=True)

# Supported barcode types - need to adapt these functions to ignore list
# of valid barcodes that the generic decoder requires
BARCODE_TYPES = { 
        "golay_12":(12, lambda bc, bcodes: decode_golay_12(bc)), 
        "hamming_8":(8, lambda bc, bcodes: decode_barcode_8(bc)),
        # The decode function for variable length barcode does nothing -
        # it's just provided to comply with the interface of the other
        # barcode types. The returned barcode is always the same as the 
        # one passed in, and the number of mismatches is always 0. The
        # length is None, corresponding to variable length.
        "variable_length":(None, lambda bc, bcodes: (bc, 0))}

def get_infile(filename):
    """Returns filehandle, allowing gzip input."""
    if filename.endswith(".gz"):
        fin = GzipFile(filename, "rb")     
    else:
        fin = open(filename, "U") 
    return fin

def count_mismatches(seq1, seq2, max_mm):
    """Counts mismatches, primer should be <= length of the seq.
    """
    mm = 0
    for i in range(min(len(seq2), len(seq1))):
        if seq1[i] != seq2[i]:
            mm += 1
            if mm > max_mm:
                return mm
    return mm

def ok_mm_primer(primer_seq, all_primer_seqs, primer_mm):
    """Check if primer_seq matches any primer within max mismatches.
    
    TODO: if we start using highly degenerate primers, should refactor using
    faster algorithm.
    """ 
    for curr_pat in all_primer_seqs:
        if count_mismatches(primer_seq, curr_pat, primer_mm) <= primer_mm:
            return True
    return False
    
def MatchScorerAmbigs(match, mismatch, matches=None):
    """ Alternative scorer factory for sw_align which allows match to ambiguous chars

    It allows for matching to ambiguous characters which is useful for 
     primer/sequence matching. Not sure what should happen with gaps, but they
     shouldn't be passed to this function anyway. Currently a gap will only match
     a gap.

    match and mismatch should both be numbers. Typically, match should be 
    positive and mismatch should be negative.

    Resulting function has signature f(x,y) -> number.
    
    Code original from Greg Caporaso
    """
    
    matches = matches or \
     {'A':{'A':None},'G':{'G':None},'C':{'C':None},\
      'T':{'T':None},'-':{'-':None}}
    for ambig, chars in IUPAC_DNA_ambiguities.items():
        try:
            matches[ambig].update({}.fromkeys(chars))
        except KeyError:
            matches[ambig] = {}.fromkeys(chars)
        
        for char in chars:
            try:
                matches[char].update({ambig:None})
            except KeyError:
                matches[char] = {ambig:None}
            
    def scorer(x, y):
        # need a better way to disallow unknown characters (could
        # try/except for a KeyError on the next step, but that would only 
        # test one of the characters)
        if x not in matches or y not in matches:
            raise ValueError, "Unknown character: %s or %s" % (x,y)
        if y in matches[x]:
            return match
        else:
            return mismatch
    return scorer
    
# The scoring function which can be passed to cogent.alignment.algorithms.sw_align
equality_scorer_ambigs = MatchScorerAmbigs(1, -1)
expanded_equality_scorer_ambigs = MatchScorerAmbigs(1, -1,\
     matches=\
      {'A':{'A':None,'G':None},\
       'G':{'G':None,'A':None,'T':None,'C':None,},\
       'C':{'C':None,'G':None},\
       'T':{'T':None,'G':None},\
       '-':{'-':None}})
    
def pair_hmm_align_unaligned_seqs(seqs,moltype=DNA,params={}):
    """
        Checks parameters for pairwise alignment, returns alignment.
        
        Code from Greg Caporaso.
    """
    
    seqs = LoadSeqs(data=seqs,moltype=moltype,aligned=False)
    try:
        s1, s2 = seqs.values()
    except ValueError:
        raise ValueError,\
         "Pairwise aligning of seqs requires exactly two seqs."
    
    try:
        gap_open = params['gap_open']
    except KeyError:
        gap_open = 5
    try:
        gap_extend = params['gap_extend']
    except KeyError:
        gap_extend = 2
    try:
        score_matrix = params['score_matrix']
    except KeyError:
        score_matrix = make_dna_scoring_dict(\
         match=1,transition=-1,transversion=-1)
    
    return local_pairwise(s1,s2,score_matrix,gap_open,gap_extend)
    
def local_align_primer_seq(primer,sequence,sw_scorer=equality_scorer_ambigs):
    """Perform local alignment of primer and sequence
    
        primer: Input primer sequence
        sequence: target sequence to test primer against
        
        Returns the number of mismatches,
         and the start position in sequence of the hit.
         
        Modified from code written by Greg Caporaso.
    """
    
    query_primer = primer

    query_sequence = str(sequence)
     
    # Get alignment object from primer, target sequence
    alignment = pair_hmm_align_unaligned_seqs([query_primer,query_sequence])
    
    # Extract sequence of primer, target site, may have gaps in insertions
    # or deletions have occurred.
    primer_hit = str(alignment.Seqs[0])
    target_hit = str(alignment.Seqs[1])
    
    # Count insertions and deletions
    insertions = primer_hit.count('-')
    deletions = target_hit.count('-')
    
    mismatches = 0
    for i in range(len(target_hit)):
        # using the scoring function to check for
        # matches, but might want to just access the dict
        if sw_scorer(target_hit[i],primer_hit[i]) == -1 and \
         target_hit[i] != '-' and primer_hit[i] != '-': 
           mismatches += 1
    try:
        hit_start = query_sequence.index(target_hit.replace('-',''))
    except ValueError:
        raise ValueError,('substring not found, query string %s, target_hit %s' % (query_sequence, target_hit))
    
    # sum total mismatches
    mismatch_count = insertions + deletions + mismatches
    
   
    return mismatch_count, hit_start

def expand_degeneracies(raw_primer):
    """ Returns all non-degenerate versions of a given primer sequence """
    
    primers=SequenceGenerator(template=raw_primer,alphabet=IUPAC_DNA)
    expanded_primers=[]
    for primer in primers:
        expanded_primers.append(primer)
        
    return expanded_primers
    

def check_map(infile, has_barcodes=True, disable_primer_check=False):
    """Check mapping file and extract list of valid barcodes, primers """
    hds, id_map, dsp, run_description, errors, warnings = \
        process_id_map(infile, is_barcoded=has_barcodes, \
        disable_primer_check=disable_primer_check)
    barcode_to_sample_id = {}
    
    primer_seqs_lens = {}
    all_primers = {}

    for sample_id, sample in id_map.items():
        barcode_to_sample_id[sample['BarcodeSequence'].upper()] = sample_id
        if not disable_primer_check:
            raw_primer = sample['LinkerPrimerSequence'].upper()
            expanded_primers = expand_degeneracies(raw_primer)
            curr_bc_primers = {}
            for primer in expanded_primers:
                curr_bc_primers[primer] = len(primer)
                all_primers[primer] = len(primer)
            primer_seqs_lens[sample['BarcodeSequence']] = curr_bc_primers
    
    
    return hds, id_map, barcode_to_sample_id, warnings, errors, \
     primer_seqs_lens, all_primers

def fasta_ids(fasta_files, verbose=False):
    """ Returns list of ids in FASTA files """
    all_ids = set([])
    for fasta_in in fasta_files:
        for label, seq in MinimalFastaParser(fasta_in):
            rid = label.split()[0]
            if rid in all_ids:
                raise ValueError, \
                    "Duplicate ID found in FASTA/qual file: %s" % label      
            all_ids.add(rid)
    return all_ids

def count_ambig(curr_seq, valid_chars='ATCG'):
    """Counts non-standard characters in seq"""
    up_seq  = curr_seq.upper()
    total = 0
    for vchar in valid_chars:
        total += up_seq.count(vchar)
    return len(curr_seq) - total

def split_seq(curr_seq, barcode_len, primer_seq_len):
    """Split sequence into parts barcode, primer and remainder"""
    curr_barcode = curr_seq[0:barcode_len] 
    rest_of_seq = curr_seq[barcode_len:]
    primer_seq = rest_of_seq[0:primer_seq_len]
    rest_of_seq = rest_of_seq[primer_seq_len:] 
    return curr_barcode, primer_seq, rest_of_seq 
    
def get_barcode(curr_seq, barcode_len):
    """ Split sequence into barcode and remaining sequence

    Linker and primer part of remaining sequence, as one must first
    read the barcode to find the associated primer from the mapping file"""
    raw_barcode = curr_seq[0:barcode_len]
    raw_seq = curr_seq[barcode_len:]
    return raw_barcode, raw_seq

def primer_exceeds_mismatches(primer_seq, all_primer_seqs, max_primer_mm):
    """Returns True if primer exceeds allowed mismatches"""   
    if primer_seq not in all_primer_seqs:
        if not ok_mm_primer(primer_seq, all_primer_seqs, max_primer_mm):
            return True
    return False

def seq_exceeds_homopolymers(curr_seq, max_len=6):
    """Returns False if primer contains any homopolymer > allowed length"""
    for base in 'ATGC':
        curr = base * (max_len+1)
        if curr in curr_seq:
            return True
    return False

def check_barcode(curr_barcode, barcode_type, valid_map,
 attempt_correction=True):
    """Return whether barcode is valid, and attempt correction."""
    
    corrected_bc = False
    if curr_barcode in valid_map:
        return False, curr_barcode, corrected_bc
    elif attempt_correction == False:
        return True, curr_barcode, corrected_bc
    
    if barcode_type in BARCODE_TYPES:
        expect_len, curr_bc_fun  = BARCODE_TYPES[barcode_type]
        barcode, num_errors = curr_bc_fun(curr_barcode, valid_map)
        corrected_bc = True
        return num_errors, barcode, corrected_bc
    else:
        try:
            expect_len, curr_bc_fun = int(barcode_type), correct_barcode
            barcode, num_errors = curr_bc_fun(curr_barcode, valid_map)
            corrected_bc = True
        except ValueError:
            raise ValueError, "Unsupported barcode type: %s" % barcode_type
        return num_errors, barcode, corrected_bc

def make_histograms(pre_lengths, post_lengths, binwidth=10):
    """Makes histogram data for pre and post lengths"""
    min_len = min(pre_lengths)
    max_len = max(pre_lengths)
    floor = (min_len/binwidth)*binwidth
    ceil = ((max_len/binwidth)+2)*binwidth
    bins = arange(floor, ceil, binwidth)
    pre_hist = histogram(pre_lengths,bins)[0]
    post_hist, bin_edges = histogram(post_lengths,bins)
    return pre_hist, post_hist, bin_edges

'''def format_histograms(pre_hist, post_hist, bin_edges):
    """Returns text-formatted histogram."""
    lines = []
    lines.append('Length\tBefore\tAfter')
    for edge, pre, post in zip(bin_edges, pre_hist, post_hist):
        lines.append('\t'.join(map(str, [edge, pre, post])))
    return '\n'.join(lines) '''

class SeqQualBad(object):
    """Checks if a seq and qual score are bad, saving ids that are bad."""

    def __init__(self, name, f):
        """New SeqQualBad keeps track of failed ids."""
        self.FailedIds = []
        self.Name = name
        self.F = f

    def __call__(self, id_, seq, qual):
        """SeqQualBad called on id, seq and qual returns bool.

        Note: saves failed ids in self.FailedIds."""
        result = self.F(id_, seq, qual)
        if result:
            self.FailedIds.append(id_)
        return result

    def __str__(self):
        """SeqQualBad str returns tab-delimited output of counts."""
        return "%s\t%s" % (self.Name, len(self.FailedIds))


def qual_missing(id_, seq, qual):
    """returns True if qual is None"""
    return qual is None

QualMissing = SeqQualBad('Missing Qual Score', qual_missing)

def get_seq_lengths(seq_lengths, bc_counts):
    """Convenience wrapper for getting lengths of good and bad seqs"""
    all_seq_lengths = seq_lengths.values()
    all_seq_ids = set(seq_lengths.keys())
    bad_seq_ids = set(bc_counts[None]).union(set(bc_counts['#FAILED']))
    good_seq_ids = all_seq_ids - bad_seq_ids
    good_seq_lengths = map(seq_lengths.__getitem__, good_seq_ids)
    return all_seq_lengths, good_seq_lengths
 
def check_window_qual_scores(qual_scores, window=50, min_average=25):
    """Check that all windows have ave qual score > threshold."""

    
    # Code from Jens Reeder, added 1-13-2010
    l = len(qual_scores)

    window = min(window, l)
    if (window == 0):
        return True
    #initialize with sum of first window
    window_score = sum(qual_scores[:window])   
    idx = 0
    while (window_score/float(window) >= min_average
           and idx < l-window):
            #'Move' window
            window_score += qual_scores[idx+window] - qual_scores[idx]
            idx += 1
    if (idx == l-window):
        # we processed all qual_scores, must be good
        return True
    else:
        return False


def check_seqs(fasta_out, fasta_files, starting_ix, valid_map, qual_mappings, 
    filters, barcode_len, keep_primer, keep_barcode, barcode_type, 
    max_bc_errors,remove_unassigned, attempt_bc_correction,
    primer_seqs_lens, all_primers, max_primer_mm, disable_primer_check,
    reverse_primers, rev_primers, qual_out):
    """Checks fasta-format sequences and qual files for validity."""
    seq_lengths = {}
    bc_counts = defaultdict(list)
    curr_ix = starting_ix
    corr_ct = 0 #count of corrected barcodes

    # get the list of barcode lengths in reverse order
    barcode_length_order = list(set([len(bc) for bc in valid_map]))
    barcode_length_order.sort()
    barcode_length_order = barcode_length_order[::-1]

    primer_mismatch_count = 0
    all_primers_lens = list(set(all_primers.values()))
    all_primers_lens.sort()
    
    reverse_primer_not_found = 0
    
    
    for fasta_in in fasta_files:
        for curr_id, curr_seq in MinimalFastaParser(fasta_in):
            curr_rid = curr_id.split()[0]
            curr_len = len(curr_seq)
            curr_qual = qual_mappings.get(curr_rid, None)
            
            #if qual_out:
            #    curr_qual_out_score = \
            #     "%2.2f" % float(float(sum(curr_qual))/float(len(curr_qual)))
            seq_lengths[curr_rid] = curr_len
            failed = False
            
            for f in filters:
                failed = failed or f(curr_rid, curr_seq, curr_qual)
            if failed:  #if we failed any of the checks, bail out here
                bc_counts['#FAILED'].append(curr_rid)
                continue
                
            if barcode_type == 'variable_length':
                # Reset the raw_barcode, raw_seq, and barcode_len -- if 
                # we don't match a barcode from the mapping file, we want
                # these values to be None
                raw_barcode, raw_seq, barcode_len = (None, None, None)
                # Iterate through the barcode length from longest to shortest
                for l in barcode_length_order:
                    # extract the current length barcode from the sequence
                    bc, seq = get_barcode(curr_seq, l)
                    # check if the sliced sequence corresponds to a valid
                    # barcode, and if so set raw_barcode, raw_seq, and 
                    # barcode_len for use in the next steps
                    if bc in valid_map:
                        raw_barcode, raw_seq = bc, seq
                        barcode_len = len(raw_barcode)
                        break
                # if we haven't found a valid barcode, log this sequence as
                # failing to match a barcode, and move on to the next sequence
                if not raw_barcode:
                    bc_counts['#FAILED'].append(curr_rid)
                    continue
                
            else:
                # Get the current barcode to look up the associated primer(s)
                raw_barcode, raw_seq = get_barcode(curr_seq, barcode_len)
            
            if not disable_primer_check:
                try:
                    current_primers = primer_seqs_lens[raw_barcode]
                    # In this case, all values will be the same, i.e. the length
                    # of the given primer, or degenerate variations thereof.
                    primer_len = current_primers.values()[0]

                    if primer_exceeds_mismatches(raw_seq[:primer_len],\
                    current_primers, max_primer_mm):
                         bc_counts['#FAILED'].append(curr_rid)
                         primer_mismatch_count += 1
                         continue
                except KeyError:
                    # If the barcode read does not match any of those in the 
                    # mapping file, the situation becomes more complicated.  We do
                    # not know the length the sequence to slice out to compare to
                    # our primer sets, so, in ascending order of all the given
                    # primer lengths, a sequence will the sliced out and compared
                    # to the primer set.  
                    current_primers = all_primers
                    found_match = False
                    for seq_slice_len in all_primers_lens:
                        if not(primer_exceeds_mismatches(raw_seq[:seq_slice_len],\
                            current_primers, max_primer_mm)):
                                primer_len = seq_slice_len
                                found_match = True
                                break
                    if not found_match:
                        bc_counts['#FAILED'].append(curr_rid)
                        primer_mismatch_count += 1
                        continue
                except IndexError:
                    # Try to raise meaningful error if problem reading primers
                    raise IndexError, ('Error reading primer sequences.  If '+\
                    'primers were purposefully not included in the mapping '+\
                    'file, disable usage with the -p option.')
            else:
                # Set primer length to zero if primers are disabled.
                primer_len = 0

            # split seqs
            cbc, cpr, cres = split_seq(curr_seq, barcode_len,\
             primer_len)
             
            # get current barcode
            try:
                bc_diffs, curr_bc, corrected_bc = \
                    check_barcode(cbc, barcode_type, valid_map.keys(), \
                    attempt_bc_correction)
                if bc_diffs > max_bc_errors:
                    raise ValueError, "Too many errors in barcode"
                corr_ct += bool(corrected_bc)
            except Exception, e:
                bc_counts[None].append(curr_rid)
                continue
            
            curr_samp_id = valid_map.get(curr_bc, 'Unassigned')
            
            new_id = "%s_%d" % (curr_samp_id, curr_ix)
            # check if writing out primer
            write_seq = cres
            
                       
            if reverse_primers == "truncate_only":
                try:
                    rev_primer = rev_primers[curr_bc]
                    rev_primer_mm, rev_primer_index  = \
                     local_align_primer_seq(rev_primer,cres)
                    if rev_primer_mm <= max_primer_mm:
                        write_seq = write_seq[0:rev_primer_index]
                        if qual_out:
                            curr_qual = curr_qual[0:barcode_len +\
                             primer_len + rev_primer_index]
                    else:
                        reverse_primer_not_found += 1
                except KeyError:
                    pass
            elif reverse_primers == "truncate_remove":
                try:
                    rev_primer = rev_primers[curr_bc]
                    rev_primer_mm, rev_primer_index  = \
                     local_align_primer_seq(rev_primer,cres)
                    if rev_primer_mm <= max_primer_mm:
                        write_seq = write_seq[0:rev_primer_index]
                        if qual_out:
                            curr_qual = curr_qual[0:barcode_len +\
                             primer_len + rev_primer_index]
                    else:
                        reverse_primer_not_found += 1
                        write_seq = False
                except KeyError:
                    bc_counts['#FAILED'].append(curr_rid)
                    continue
                    
            # Slice out regions of quality scores that correspond to the 
            # written sequence, i.e., remove the barcodes/primers and reverse
            # primers if option is enabled.
            if qual_out:
                qual_barcode, qual_primer, qual_scores_out = \
                 split_seq(curr_qual, barcode_len, primer_len)
                # Convert to strings instead of numpy arrays, strip off brackets
                qual_barcode = format_qual_output(qual_barcode)
                qual_primer = format_qual_output(qual_primer)
                qual_scores_out = format_qual_output(qual_scores_out)

            
            if not write_seq:
                bc_counts['#FAILED'].append(curr_rid)
                continue
            
            if keep_primer:
                write_seq = cpr + write_seq
                if qual_out:
                    qual_scores_out = qual_primer + qual_scores_out
            if keep_barcode:
                write_seq = cbc + write_seq
                if qual_out:
                    qual_scores_out = qual_barcode + qual_scores_out
                
                
            
            
            
            # Record number of seqs associated with particular barcode.
            bc_counts[curr_bc].append(curr_rid)
                 
            if remove_unassigned or (not attempt_bc_correction):
                if curr_samp_id!="Unassigned":
                    fasta_out.write(">%s %s orig_bc=%s new_bc=%s bc_diffs=%s\n%s\n" % 
                     (new_id, curr_rid, cbc, curr_bc, int(bc_diffs), write_seq))
                    if qual_out:
                        qual_out.write(">%s %s orig_bc=%s new_bc=%s bc_diffs=%s\n%s" % 
                         (new_id, curr_rid, cbc, curr_bc, int(bc_diffs), qual_scores_out))
                else:
                    bc_counts['#FAILED'].append(curr_rid)
            else:    
                fasta_out.write(">%s %s orig_bc=%s new_bc=%s bc_diffs=%s\n%s\n" % 
                    (new_id, curr_rid, cbc, curr_bc, int(bc_diffs), write_seq))
                if qual_out:
                        qual_out.write(">%s %s orig_bc=%s new_bc=%s bc_diffs=%s\n%s" % 
                         (new_id, curr_rid, cbc, curr_bc, int(bc_diffs), qual_scores_out))
            curr_ix += 1
    log_out = format_log(bc_counts, corr_ct, seq_lengths, valid_map, filters,\
    remove_unassigned, attempt_bc_correction, primer_mismatch_count, \
    max_primer_mm, reverse_primers, reverse_primer_not_found)
    all_seq_lengths, good_seq_lengths = get_seq_lengths(seq_lengths, bc_counts)
    return log_out, all_seq_lengths, good_seq_lengths

def format_qual_output(qual_array):
    """ Converts to string from numpy arrays, removes brackets """
    
    # Size of lines needed for proper quality score file format
    qual_line_size = 60
    
    qual_scores = ""
    
    for slice in range(0, len(qual_array), qual_line_size):
            current_segment = qual_array[slice:slice + qual_line_size]
            current_segment =\
             " ".join(str(score) for score in current_segment) + "\n"
            
            qual_scores += current_segment
    
    '''qual_array = str(qual_array)
    qual_array = qual_array.replace('[','')
    qual_array = qual_array.replace(']','') '''
    return qual_scores
    

def format_log(bc_counts, corr_ct, seq_lengths, valid_map, filters,\
remove_unassigned, attempt_bc_correction, primer_mismatch_count, max_primer_mm,\
reverse_primers, reverse_primer_not_found):
    """Makes log lines"""

    
    log_out = []
    all_seq_lengths, good_seq_lengths = get_seq_lengths(seq_lengths, bc_counts)
    log_out.append("Number raw input seqs\t%d\n" % len(seq_lengths)) 
    
    for f in filters:
        log_out.append(str(f))
    log_out.append('Num mismatches in primer exceeds limit of %s: %d\n' %\
     (max_primer_mm, primer_mismatch_count))
    if reverse_primers == "truncate_only":
        log_out.append('Number of sequences with identifiable barcode '+\
         'but without identifiable reverse primer: '+\
         '%d\n' % reverse_primer_not_found)
        log_out.append('-z truncate_only option enabled; sequences '+\
         'without a discernable reverse primer as well as sequences with a '+\
         'valid barcode not found in the mapping file may still be written.\n')
    if reverse_primers == "truncate_remove":
        log_out.append('Number of sequences with identifiable barcode '+\
         'but without identifiable reverse primer: '+\
         '%d\n' % reverse_primer_not_found)
        log_out.append('-z truncate_remove option enabled; sequences '+\
         'without a discernable reverse primer as well as sequences with a '+\
         'valid barcode not found in the mapping file will not be written.\n')
    log_out.append("Raw len min/max/avg\t%.1f/%.1f/%.1f" % 
        (min(all_seq_lengths), max(all_seq_lengths), mean(all_seq_lengths)))
    
    if good_seq_lengths:
        log_out.append("Wrote len min/max/avg\t%.1f/%.1f/%.1f" % 
        (min(good_seq_lengths), max(good_seq_lengths), mean(good_seq_lengths))) 
    
    #figure out which barcodes we got that didn't come from valid samples
    valid_bc_nomap = set(bc_counts) - set(valid_map) - set([None,'#FAILED'])
    valid_bc_nomap_counts = [(len(bc_counts[b]),b) for b in valid_bc_nomap]

    
    log_out.append("\nBarcodes corrected/not\t%d/%d" % 
            (corr_ct, len(bc_counts[None])))
    if attempt_bc_correction:
        log_out.append("Uncorrected barcodes will not be written to the "+\
        "output fasta file.\nCorrected barcodes will be written with "+\
        "the appropriate barcode category.\nCorrected but unassigned "+\
        "sequences will be written as such unless disabled via the -r "+\
        "option.\n")
    else:
        log_out.append("Barcode correction has been disabled via the -c "+\
        "option.\n")
    log_out.append("Total valid barcodes that are not in mapping file\t%d" %\
    len(valid_bc_nomap_counts)) 
    if valid_bc_nomap:
        log_out.append("Barcodes not in mapping file\tCount")
        for count, bc in reversed(sorted(valid_bc_nomap_counts)):
            log_out.append("%s\t%d" % (bc, count))
    if remove_unassigned:
        log_out.append("Sequences associated with valid barcodes that are not"+\
        " in the mapping file will not be written. -r option enabled.")
    elif not attempt_bc_correction:
        log_out.append("Barcode correction has been disabled (-c option), "+\
        "no unassigned or invalid barcode sequences will be recorded.")
    else:
        log_out.append("Sequences associated with valid barcodes that are "+\
        "not in the mapping file will be written as 'unassigned'.  -r option "+\
        "disabled.")
    log_out.append("\nBarcodes in mapping file")
   
    sample_cts = [(len(bc_counts[bc]), bc, sample_id) for bc, sample_id 
            in valid_map.items()]
    if sample_cts:
        filtered_sample_cts = [s[0] for s in sample_cts if s[0]]
        if filtered_sample_cts:
            log_out.append("Num Samples\t%d" % len(filtered_sample_cts))
            log_out.append("Sample ct min/max/mean: %d / %d / %.2f" % (
            min(filtered_sample_cts), max(filtered_sample_cts), 
            mean(filtered_sample_cts)))
        log_out.append("Sample\tSequence Count\tBarcode")
        for count, bc, sample_id in reversed(sorted(sample_cts)):
            log_out.append("%s\t%d\t%s" % (sample_id, count, bc))

        
        
    log_out.append("\nTotal number seqs written\t%d" % len(good_seq_lengths)) 
    return log_out
    
def get_reverse_primers(id_map):
    """ Return a dictionary with barcodes and rev-complement of rev primers """
    
    rev_primers = {}
    for n in id_map.items():
        # Generate a dictionary with Barcode:reverse primer
        # Convert to reverse complement of the primer so its in the 
        # proper orientation with the input fasta sequences
        rev_primers[n[1]['BarcodeSequence']]=DNA.rc(n[1]['ReversePrimer'])
        
    return rev_primers

def preprocess(fasta_files, qual_files, mapping_file, 
    barcode_type="golay_12",
    min_seq_len=200, max_seq_len=1000, min_qual_score=25, starting_ix=1,
    keep_primer=True, max_ambig=0, max_primer_mm=1, trim_seq_len=True,
    dir_prefix='.', max_bc_errors=2, max_homopolymer=4,remove_unassigned=False,
    keep_barcode=False, attempt_bc_correction=True, qual_score_window=0,
    disable_primers=False, reverse_primers='disable', record_qual_scores=False):
        

        
    """
    Preprocess barcoded libraries, e.g. from 454.

    Parameters:

    fasta_files: list of raw 454 fasta files, fasta format.
    
    qual_files: list of raw 454 qual file(s)
    
    mapping_file: mapping file with BarcodeSequence column containing valid 
    barcodes used in the 454 run 

    barcode_type: type of barcode, e.g. golay_12. Should appear in list of
    known barcode types.

    min_seq_len: minimum sequence length to allow.

    max_seq_len: maximum sequence length to allow.

    min_qual_score: minimum average qual score considered acceptaable.
    
    starting_ix: integer to start sample sequence numbering at.

    keep_primer: when True, will keep primer sequence, otherwise will strip it 

    keep_barcode: when True, will keep barcode sequence, otherwise will strip it 

    max_ambig: maximum number of ambiguous bases to allow in the read.

    max_primer_mm: maximum number of primer mismatches to allow.

    trim_seq_len: if True (default), calculates lengths after trimming.

    dir_prefix: prefix of directories to write files into.

    max_bc_errors: maximum number of barcode errors to allow in output seqs
    
    max_homopolymer: maximum number of a nucleotide that can be 
    repeated in a given sequence.
    
    remove_unassigned: If True (False default), will not write seqs to the
    output .fna file that have a valid barcode (by Golay or Hamming standard)
    but are not included in the input mapping file.
    
    attempt_bc_correction: (default True) will attempt to find nearest valid
    barcode.  Can be disabled to improve performance.
    
    disable_primers: (default False) Disables testing for primers in the
    input mapping file and primer testing in the input sequence files.
    
    reverse_primers: (default 'disable') Enables removal of reverse primers and
    any subsequence sequence data from output reads.  Reverse primers have to
    be in 5'->3' format and in correct IUPAC codes in a column "ReversePrimer"
    in the input mapping file.  Run check_id_map to make test primers in this
    column for valid formatting.  The primers read from this column will be
    reverse complemented and associated with the given barcode in the
    mapping file.  If set to 'truncate_only', sequences where primers are found
    will be truncated, sequences where the primer is not found will be written
    unchanged.  If set to 'truncate_remove', sequences where primers are found
    will be truncated, sequences where the primer is not found will not be 
    written and counted in the log file as failing for this reason.  The 
    mismatches allowed for a reverse primer match are the same as specified 
    for the forward primer mismatches with the -M parameter (default 0).
    
    record_qual_scores:  (default False) Will record quality scores for all
    sequences that are written to the output seqs.fna file in a separate
    file (seqs_filtered.qual) containing the same sequence IDs and 
    quality scores for all bases found in the seqs.fna file.

    Result:
    in dir_prefix, writes the following files:
    id_map.xls: 2-column tab-delimited text format orig_id:new_id
    error_map.xls: 2-column tab-delimited text format orig_id:fail_reasons
    seqs.fasta: sequences with new ids lib_index in fasta format
    lengths.xls: histograms of unfiltered and filtered lengths, resolution 10 bp
    """

    
    if max_seq_len < 10:
        raise ValueError, "Max sequence must be >= 10"
    if min_seq_len >= max_seq_len:
        raise ValueError, "Min len cannot be >= max len"
    if min_qual_score < 0:
        raise ValueError, "Min qual score must be > 0"
    if starting_ix < 1:
        raise ValueError, "Starting index must be > 0."
    if max_ambig < 0:
        raise ValueError, "Max ambig chars must be >= 0."
    if max_primer_mm < 0:
        raise ValueError, "Max primer mismatches must be >= 0."
    if min_qual_score < 5:
        raise ValueError, "Min qual score must be >= 5."
    if reverse_primers not in ['disable','truncate_only','truncate_remove']:
        raise ValueError, ("reverse_primers parameter must be 'disable', "+\
         "truncate_only, or truncate_remove.")

    create_dir(dir_prefix, fail_on_exist=False)

#    try:
#        stat(dir_prefix)
#    except OSError:
#        mkdir(dir_prefix)

    """# Generate primer sequence patterns - changing to mapping file primers.
    all_primer_seqs, primer_seq_len = \
        get_primer_seqs(primer_seq_pats.split(',')) """
        
    # Check mapping file and get barcode mapping 
    map_file = open(mapping_file, 'U')
    headers, id_map, valid_map, warnings, errors, \
     primer_seqs_lens, all_primers = check_map(map_file, \
     disable_primer_check = disable_primers )
     
    if reverse_primers != 'disable':
        if 'ReversePrimer' not in headers:
            raise ValueError, ('To enable reverse primer check, there must '+\
             'be a "ReversePrimer" column in the mapping file with a reverse '+\
             'primer in each cell.')
        rev_primers = get_reverse_primers(id_map)
    else:
        rev_primers = False
        
    # *** Generate dictionary of {barcode: DNA.rc(ReversePrimer)}
    # First check for ReversePrimer in headers, raise error if not found
    # Implement local alignment for primer after barcode is determined.
    # Add option to flag seq with error for rev_primer not found
    # Check primer hit index, truncate sequence
    # unit tests.
    
    map_file.close()
    if errors:
        raise ValueError, "Invalid mapping file. "+\
        "Validate with check_id_map first: %s" % "\n".join(errors)

    # Find actual length of barcodes in the mapping file, also check for
    # variable lengths
    barcode_length_check = list(set([len(bc) for bc in valid_map]))
    # Check barcode type
    if barcode_type not in BARCODE_TYPES:
        try:
            barcode_len, barcode_fun = int(barcode_type), correct_barcode
        except ValueError:
            raise ValueError, "Unsupported barcode type: %s" % barcode_type
    else:
        barcode_len, barcode_fun = BARCODE_TYPES[barcode_type]


    # As people often do not specify a barcode that matches the lengths
    # of the barcodes used, a check on the actual barcode lengths needs to
    # be done, and an exception raised if they are variable length and not
    # specified as so.
    if barcode_type != "variable_length":
        # Raise error if variable length barcodes are present but not
        # specified
        if len(barcode_length_check) != 1:
            raise ValueError, ('Mapping file has variable length '+\
            'barcodes.  If this is intended, specifiy variable lengths '+\
            'with the -b variable_length option.')
        # Raise error if the specified barcode length doesn't match what
        # is present in the mapping file.
        if barcode_len != barcode_length_check[0]:
            raise ValueError, ('Barcode length detected in the mapping file, '+\
            ' %d does not match specified barcode length, %d.  ' % \
            (barcode_length_check[0], barcode_len) + 'To specify a barcode '+\
            'length use -b golay_12 or -b hamming_8 for 12 and 8 base pair '+\
            'golay or hamming codes respectively, or -b # where # is the '+\
            'length of the barcode used.  E.g. -b 4 for 4 base pair barcodes.')



    fasta_files = map(get_infile, fasta_files)
    qual_files = map(get_infile, qual_files)
    
    # Check fasta files valid format, no duplicate ids
    # and ids match between fasta and qual files
    all_fasta_ids = fasta_ids(fasta_files)
    all_qual_ids = fasta_ids(qual_files)
    if qual_files and (len(all_fasta_ids) != len(all_qual_ids)):
        f_ids = all_fasta_ids.difference(all_qual_ids)
        q_ids = all_qual_ids.difference(all_fasta_ids)
        raise ValueError, "Found %d ids in fasta file not in qual file, %d ids in qual file not in fasta"  % (len(f_ids), len(q_ids))

    
    for f in fasta_files:
        f.seek(0)
    if qual_files:
        for q in qual_files:
            q.seek(0)
        # Load quality scores 
        qual_mappings = parse_qual_scores(qual_files)
        for q in qual_files:
            q.close()
    else:
        qual_mappings = {}

    #make filters
    filters = []
    #seq len filter depends on whether we're including the barcode
    if trim_seq_len:
        # This processing occurs before primer testing, will use largest
        # primer length to calculate lengths.  the dict all_primers has
        # keys of each primer with the length of said primer as the value
        if not disable_primer_check:
            primer_seq_len = max(all_primers.values())
        else:
            # Set to zero if primers not used
            primer_seq_len = 0
        trim = barcode_len + primer_seq_len
        filters.append(SeqQualBad(
            'Length outside bounds of %s and %s' % (min_seq_len,max_seq_len),
            lambda id_, seq, qual: \
                not (min_seq_len<=len(seq)-trim<= max_seq_len)))
    else:
        filters.append(SeqQualBad(
            'Length outside bounds of %s and %s' % (min_seq_len,max_seq_len),
            lambda id_, seq, qual: not (min_seq_len<=len(seq)<= max_seq_len)))
    filters.append(SeqQualBad(
        'Num ambiguous bases exceeds limit of %s' % max_ambig,
        lambda id_, seq, qual: count_ambig(seq) > max_ambig))
    
    if qual_mappings:
        filters.append(QualMissing)
        filters.append(SeqQualBad(
            'Mean qual score below minimum of %s' % min_qual_score, 
            lambda id_, seq, qual: mean(qual) < min_qual_score))
    if qual_score_window:
            filters.append(SeqQualBad('Mean window qual score below '+\
                            'minimum of %s' % min_qual_score,
                                      lambda id_, seq, qual: \
             not check_window_qual_scores(qual, qual_score_window, \
             min_qual_score)))

    # Changed this to check entire sequence after barcode-could cause issue
    # if barcode-linker-primer have long homopolymers though.
    filters.append(SeqQualBad(
        'Max homopolymer run exceeds limit of %s' % max_homopolymer,
        lambda id_, seq, qual: seq_exceeds_homopolymers(
            seq[barcode_len:], max_homopolymer)))

    # Check seqs and write out
    fasta_out = open(dir_prefix + '/' + 'seqs.fna', 'w+')
    if record_qual_scores:
        qual_out = open(dir_prefix + '/' + 'seqs_filtered.qual', 'w+')
    else:
        qual_out = False
        
    '''log_stats, pre_lens, post_lens = check_seqs(fasta_out, fasta_files, 
        starting_ix, valid_map, qual_mappings, filters, barcode_len,
        primer_seq_len, keep_primer, keep_barcode, barcode_type, max_bc_errors,
        remove_unassigned) '''
    log_stats, pre_lens, post_lens = check_seqs(fasta_out, fasta_files, 
        starting_ix, valid_map, qual_mappings, filters, barcode_len,
        keep_primer, keep_barcode, barcode_type, max_bc_errors,
        remove_unassigned, attempt_bc_correction,
        primer_seqs_lens, all_primers, max_primer_mm, disable_primers,
        reverse_primers, rev_primers, qual_out)

    # Write log file
    log_file = open(dir_prefix + '/' + "split_library_log.txt", 'w+')
    log_file.write('\n'.join(log_stats))
    log_file.close()

    # Write sequence distros here
    histogram_file = open(dir_prefix + '/' + 'histograms.txt', 'w+')
    histogram_file.write(format_histograms
        (*make_histograms(pre_lens, post_lens)))
    histogram_file.close()
