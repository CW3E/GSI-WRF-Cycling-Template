#!/bin/ksh
##########################################################################
#
# Script Name: WPS_constants.ksh
#
# Description:
#    This script localizes several tools specific to this platform.  It
#    should be called by other workflow scripts to define common
#    variables.
#
##########################################################################
# License Statement:
##########################################################################
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
#
##########################################################################
# Usin GMT time zone for time computations
export TZ="GMT"

# Give other group members write access to the output files
umask 2

# sets COMET specific environment for intelmpi 2019.5.281
eval `/bin/modulecmd ksh purge`
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
eval `/bin/modulecmd ksh load intel/2019.5.281`
eval `/bin/modulecmd ksh load intelmpi/2019.5.281`
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
eval `/bin/modulecmd ksh load hdf5/1.10.7`
eval `/bin/modulecmd ksh load netcdf/4.7.4intelmpi`
eval `/bin/modulecmd ksh list`

# Create paths for netcdf
export JASPERLIB="/usr/lib64"
export JASPERINC="/usr/include"
export PNETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export NETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export HDF5="/share/apps/compute/hdf5/intel2019/intelmpi"
export LD_LIBRARY_PATH=/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# ensure ulimit is set unlimited
ulimit -s unlimited

# Set up paths to shell commands
AWK="/bin/gawk --posix"
BASENAME=/bin/basename
BC=/bin/bc
CAT=/bin/cat
CHMOD=/bin/chmod
CONVERT=/bin/convert
CP=/bin/cp
CUT=/bin/cut
DATE=/bin/date
DIRNAME=/bin/dirname
ECHO=/bin/echo
EXPR=/bin/expr
GREP=/bin/grep
LN=/bin/ln
LS=/bin/ls
MD5SUM=/bin/md5sum
MKDIR=/bin/mkdir
MV=/bin/mv
OD=/bin/od
PATH=${NCARG_ROOT}/bin:${PATH}
RM=/bin/rm
RSYNC=/bin/rsync
SCP=/bin/scp
SED=/bin/sed
SORT=/bin/sort
SSH=/bin/ssh
TAIL=/bin/tail
TAR=/bin/tar
TIME=/bin/time
TOUCH=/bin/touch
TR=/bin/tr
WC=/bin/wc
