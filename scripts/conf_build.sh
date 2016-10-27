
set +v

# build environment for Genboree

source ${DIR_SCRIPTS}/conf_global.sh

# ================================ Parse command line parameters and set proper variables
CORES_NUMBER=2
GENB_VERSION="unknown"
for i in "$@"
do
	case $i in
		-h|--help)
			printf "Parameters:\n -h or --help - print this help\n --notests - tests are omitted\n --cores=<number> - number of cores to use (default 2)\n"
			exit 1
		;;
		--cores=*)
			CORES_NUMBER="${i#*=}"
		;;
		--notests)
			ARG_WITHOUT_TESTS=1
		;;
		--version=*)
			GENB_VERSION="${i#*=}"
		;;
		*)
			printf "Unknown options: $i.\nRun script with -h parameter to see help.\n"
			exit 1
		;;
	esac
done

# ================================= end of command line parameters

DIR_DEPS="../deps"    # directory with dependencies TODO - correct
DIR_SRC="../src"      # directory with sources TODO - correct
# convert to absolute paths
DIR_DEPS="`readlink -f ${DIR_DEPS}`"
DIR_SRC="`readlink -f ${DIR_SRC}`"

export PS1='genboree_build_env$ '

# we shadow standard bin location because of standard config scripts placed there by different libraries
export PATH=${DIR_TARGET}/bin:${DIR_TARGET}/jdk/bin:${DIR_TARGET}/ant/bin:${PATH}
export ANT_HOME=${DIR_TARGET}/ant

TMP_LIBS_PATH="${DIR_TARGET}/lib:${DIR_TARGET}/apache/apr/lib:${DIR_TARGET}/mysql/lib:${LD_LIBRARY_PATH}"
TMP_INCLUDES="${DIR_TARGET}/include:${DIR_TARGET}/apache/include:${DIR_TARGET}/mysql/include"

export    LIBRARY_PATH=${TMP_LIBS_PATH}
export C_INCLUDE_PATH=${TMP_INCLUDES}
export CPLUS_INCLUDE_PATH=${TMP_INCLUDES}

export CPPFLAGS=`echo ${TMP_INCLUDES} | sed -e 's/^/-I/' | sed -e 's/:/ -I/g' | sed -e 's/-I$//'`
export LDFLAGS=`echo ${TMP_LIBS_PATH} | sed -e 's/^/-L/' | sed -e 's/:/ -L/g' | sed -e 's/-L$//'`

unset TMP_LIBS_PATH
unset TMP_INCLUDES


# ====================== functions
# parameter: name of the package (prefix)
# All files with given prefix are downloaded. 
# All downloaded files recognized as an archive are unpacked.
# All created subdirectories are scanned for files with shebang lines. 
function func_get_package
{
	local TMP_LIST="`ls ${DIR_DEPS}/${1}*`"
	if [ -z "${TMP_LIST}" ] 
	then 
		echo "Package ${1} not found!"
		exit 1
	fi
	for TMP in ${TMP_LIST}
	do
		cp ${TMP} .
		TMP="`basename ${TMP}`"
		case "${TMP}" in
			*.tar)     tar xf   ${TMP};;
			*.tar.bz2) tar xjf  ${TMP};;
			*.tbz2)    tar xjf  ${TMP};;
			*.tar.gz)  tar xzf  ${TMP};;
			*.tgz)     tar xzf  ${TMP};;
			*.gz)      gzip -d  ${TMP};;
			*.bz2)     bzip2 -d ${TMP};;
			*.zip)     unzip    ${TMP};;
			*.tar.xz)  tar xJf  ${TMP};;
			*)         ;;
		esac
	done
	for TMP in `find ${1}* -type f`
	do
		${DIR_SCRIPTS}/replaceShebangLine "${TMP}"
	done
}
# ================================
# parameter: commands to run in build environment
function func_run
{
	local CMD="$1"
	echo "${CMD}"
	( source ${DIR_SCRIPTS}/conf_runtime.sh; eval ${CMD} )
}
# ================================
# the same as previous function, but command is omitted when ARG_WITHOUT_TESTS is defined
function func_run_test
{
	if [ -z ${ARG_WITHOUT_TESTS+x} ]
	then
		local CMD="$1"
		echo "${CMD}"
		( source ${DIR_SCRIPTS}/conf_runtime.sh; eval ${CMD} )
	fi
}
# ================================
# general procedure for gem installation
# installation of single gem file
# parameter: full gem name without dot and file extension
function func_gem
{
	func_get_package "${1}"
	func_run "gem install --no-document --local ${1}.gem"
	rm ${1}.gem
}
# ================================
# general procedure for system library copying
# parameters: full path to library and target library name (link name)
function func_copy_lib
{
	cp  "${1}"  ${DIR_TARGET}/lib/
	ln -s "$(basename ${1})"  "${DIR_TARGET}/lib/${2}"
}
# ================================
# general procedure for module installation
# modulefile and target directory is created (${DIR_TARGET}/opt/name/version/)
# the following variables are set: MOD_NAME, MOD_VERSION, MOD_DIR, MOD_FILE
# parameters: name, version
function func_module
{
	MOD_NAME=${1}
	MOD_VERSION=${2}
	MOD_DIR=${DIR_TARGET}/opt/${MOD_NAME}/${MOD_VERSION}
	MOD_FILE=${DIR_TARGET}/Modules/default/modulefiles/${MOD_NAME}/${MOD_VERSION}
	mkdir -p ${DIR_TARGET}/Modules/default/modulefiles/${MOD_NAME}
	echo '#%Module' > ${MOD_FILE}
	echo "set VERSION     ${MOD_VERSION}" >> ${MOD_FILE}
	echo "set NAME        ${MOD_NAME}"    >> ${MOD_FILE}
	echo "set INSTALL_DIR ${MOD_DIR}"     >> ${MOD_FILE}
	echo "# ================== Module help message" >> ${MOD_FILE}
	echo "proc ModulesHelp { } {" >> ${MOD_FILE}
	echo "puts stderr \"Provides ${MOD_NAME} ${MOD_VERSION}\"" >> ${MOD_FILE}
	echo "puts stderr \"\"" >> ${MOD_FILE}
	echo "}" >> ${MOD_FILE}
	echo "# ================== Configuration specific for module" >> ${MOD_FILE}
	mkdir -p ${MOD_DIR}
}
# ================================
# add to modulefile given line
# target modulefile is found based on MOD_FILE variable
# parameters: text to add (one string)
function func_module_add
{
	echo "${1}" >> ${MOD_FILE}
}
# ================================
# the same as func_module but creates also bin directory 
# and update PATH in modulefile 
function func_module_bin
{
	func_module ${1} ${2}
	mkdir -p ${MOD_DIR}/bin
	func_module_add "prepend-path PATH ${MOD_DIR}/bin"
}
# ================================
# the same as func_module_binlib but creates also lib directory 
# and update LD_LIBRARY_PATH in modulefile 
function func_module_binlib
{
	func_module_bin ${1} ${2}
	mkdir -p ${MOD_DIR}/lib
	func_module_add "prepend-path LD_LIBRARY_PATH ${MOD_DIR}/lib"
}
# ================================
# the same as func_module but creates also lib directory  
# and update LD_LIBRARY_PATH in modulefile 
function func_module_lib
{
	func_module ${1} ${2}
	mkdir -p ${MOD_DIR}/lib
	func_module_add "prepend-path LD_LIBRARY_PATH ${MOD_DIR}/lib"
}
