import sys
from newick import parse_tree

intree=sys.argv[1]
infile=open(intree)
text=infile.read()
#file=open("/home/junm/baylor/fulldata/NONPQ_rep_set_aligned.tre")
print intree
outtree=intree.replace('.tre','.parsed.tre')
print outtree
outfile=open(outtree,"w")
outfile.write(str(parse_tree(text)))

