
# if/then is needed to make sure that this file is run only once
if [ -z ${GENBOREE_ENV+x} ]
then

	export GENBOREE_ENV=1

	DIR_SCRIPTS=${HOME}
	source ${DIR_SCRIPTS}/conf_runtime.sh
	source ${DIR_TARGET}/Modules/default/init/bash

	module load bowtie
	module load bowtie2
	module load bwa
	module load qiime
	module load tabix

fi
