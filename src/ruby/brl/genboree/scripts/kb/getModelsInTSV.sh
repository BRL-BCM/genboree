head -1 allCollections.tsv  > header.txt
sed -n '/#name/,/^Study/p' allCollections.tsv | grep -v "^Study" > biosample.tsv
sed -n '/^Analysis/,/^*--URL/p' allCollections.tsv > analysis.tsv
cat header.txt analysis.tsv > analysis.tsv.tmp; mv analysis.tsv.tmp analysis.tsv
sed -n '/^Study/,/^Submission/p' allCollections.tsv | grep -v "^Submission" > study.tsv
cat header.txt study.tsv > study.tsv.tmp; mv study.tsv.tmp study.tsv
sed -n '/^Submission/,/^Run/p' allCollections.tsv | grep -v "^Run" > submission.tsv
cat header.txt submission.tsv > submission.tsv.tmp; mv submission.tsv.tmp submission.tsv
sed -n '/^Run/,/^Experiment/p' allCollections.tsv | grep -v "^Experiment" > run.tsv
cat header.txt run.tsv > run.tsv.tmp; mv run.tsv.tmp run.tsv
sed -n '/^Experiment/,/^Analysis/p' allCollections.tsv | grep -v "^Analysis" > experiment.tsv
cat header.txt experiment.tsv > experiment.tsv.tmp; mv experiment.tsv.tmp experiment.tsv




