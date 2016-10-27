#!/bin/bash


DIR_SCRIPTS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   # directory with scripts

DIR_SCRIPTS=${DIR_SCRIPTS} bash --init-file ${DIR_SCRIPTS}/conf_runtime.sh

