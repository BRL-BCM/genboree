#!/bin/bash

set -e  # stop on first error
set -u  # stop when tries to use uninitialized variable

DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cp -r $DIR_SCRIPT/messages $DIR_DATA/
