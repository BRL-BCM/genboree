#!/bin/sh

echo "START ${JOB_ID} Genboree Cluster Computing on host ${HOST}" >> $SGE_STDERR_PATH
date >> $SGE_STDERR_PATH
# env >> $SGE_STDERR_PATH
if [ `hostname` != "probe.hgsc.bcm.tmc.edu" ]
then
  genboreeClusterTmpDir=/usr/local/brl/data/sge/tmp
  export sgeBashScript=${genboreeClusterTmpDir}/${JOB_NAME}.clusterWrapper.sh
  echo "rsync command : /usr/local/brl/local/bin/rrsync probe.hgsc.bcm.tmc.edu:${sgeBashScript} ${genboreeClusterTmpDir} >> ${SGE_STDERR_PATH} 2>&1" 1>&2
  /usr/local/brl/local/bin/rrsync probe.hgsc.bcm.tmc.edu:${sgeBashScript} ${genboreeClusterTmpDir} >> ${SGE_STDERR_PATH} 2>&1 
  echo "finished copying bash driver script" >> $SGE_STDERR_PATH
else
  echo "we are running on the master host" >> ${SGE_STDERR_PATH}
fi