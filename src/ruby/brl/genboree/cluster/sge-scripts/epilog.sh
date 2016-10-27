#!/bin/sh

echo "EPILOG: Genboree Cluster Computing" >> $SGE_STDERR_PATH

genboreeClusterTmpDir=/usr/local/brl/data/sge/tmp
tmpDirCache=${genboreeClusterTmpDir}/genboreeClusterComputingCache.${JOB_NAME}.${JOB_ID}
source ${tmpDirCache}
echo ${outputDirectory__GenboreeCluster} >> ${SGE_STDERR_PATH}
echo ${destinationHost__GenboreeCluster} >> ${SGE_STDERR_PATH}
date >> $SGE_STDERR_PATH
date >> $SGE_STDOUT_PATH
/usr/local/brl/local/bin/rrsync ${tmpDirCache}  ${destinationHost__GenboreeCluster}:${outputDirectory__GenboreeCluster} >> ${SGE_STDERR_PATH} 2>&1
if [ "${removeTemporaryFiles__GenboreeCluster}" == "yes" ]
then
  echo "removing temporary files " >> ${SGE_STDERR_PATH}
  /bin/rm -rf ${genboreeClusterTmpDir}/${bashScript__GenboreeCluster} >> ${SGE_STDERR_PATH} 2>&1
  /bin/rm -rf ${jobDirectory__GenboreeCluster} >> ${SGE_STDERR_PATH} 2>&1
  /bin/rm -rf ${tmpDirCache}                   >> ${SGE_STDERR_PATH} 2>&1
  echo "copying stdout and stderr back to master host " >> ${SGE_STDERR_PATH}
  /usr/local/brl/local/bin/rrsync ${SGE_STDERR_PATH} ${SGE_STDOUT_PATH} ${destinationHost__GenboreeCluster}:${outputDirectory__GenboreeCluster} >> ${SGE_STDERR_PATH} 2>&1
  /bin/rm -rf ${SGE_STDOUT_PATH} ${SGE_STDERR_PATH}
else
  echo "will not remove temporary files" >> ${SGE_STDERR_PATH}
  echo "copying stdout and stderr back to master host " >> ${SGE_STDERR_PATH}
  /usr/local/brl/local/bin/rrsync ${tmpDirCache} ${SGE_STDERR_PATH} ${SGE_STDOUT_PATH} ${destinationHost__GenboreeCluster}:${outputDirectory__GenboreeCluster} >> ${SGE_STDERR_PATH} 2>&1
fi