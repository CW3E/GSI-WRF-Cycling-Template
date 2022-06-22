#!/bin/ksh -l
##########################################################################
#
# Script Name: GSI_constants.ksh
#
# Description:
#    This script localizes several tools specific to this platform.  It
#    should be called by other workflow scripts to define common
#    variables.
#
##########################################################################
# Using GMT time zone for time computations
export TZ="GMT"

# Give other group members write access to the output files
umask 2

# set COMET specific environment for intelmpi 2018.1.163, using ksh

# change to intel mpi
eval `/bin/modulecmd ksh purge`
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
eval `/bin/modulecmd ksh load intel/2018.1.163`
eval `/bin/modulecmd ksh load intelmpi/2018.1.163`

# set up zlib, libpng, jasperlib
#Use this for non module version, note issues with DART
export JASPERLIB="/usr/lib64"
export JASPERINC="/usr/include"
export LD_LIBRARY_PATH=/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
eval `/bin/modulecmd ksh load hdf5/1.10.3`
eval `/bin/modulecmd ksh load netcdf/4.6.1`
NETCDF="/opt/netcdf/4.6.1/intel/intelmpi/"
HDF5="/opt/hdf5/1.10.3/intel/intelmpi/"

# setup lapack
eval `/bin/modulecmd ksh load lapack`
LAPACK_PATH="/share/apps/compute/lapack"
eval `/bin/modulecmd ksh list`

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
MPIRUN=mpirun
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
