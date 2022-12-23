#!/bin/bash
##########################################################################
# Description
##########################################################################
# This script localizes several tools specific to this platform.  It
# should be called by other workflow scripts to define common
# variables.
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
# Using GMT time zone for time computations
export TZ="GMT"

# sets COMET specific environment for intelmpi 2019.5.281
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2019.5.281
module load intelmpi/2019.5.281
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
module load hdf5/1.10.7
module load netcdf/4.7.4intelmpi
module list

# Create paths for netcdf
export JASPERLIB="/usr/lib64"
export JASPERINC="/usr/include"
export PNETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export NETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export HDF5="/share/apps/compute/hdf5/intel2019/intelmpi"
export LD_LIBRARY_PATH=/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=${NCARG_ROOT}/bin:${PATH}

# ensure ulimit is set unlimited
ulimit -s unlimited

# create case insensitive string variables for namelists / switches
AUXINPUT=[Aa][Uu][Xx][Ii][Nn][Pp][Uu][Tt]
BDY=[Bb][Dd][Yy]
DA=[Dd][Aa]
DAY=[Dd][Aa][Yy]
DOM=[Dd][Oo][Mm]
DOMAIN=[Dd][Oo][Mm][Aa][Ii][Nn]
END=[Ee][Nn][Dd]
EQUAL=[[:blank:]]*=[[:blank:]]*
FEEDBACK=[Ff][Ee][Ee][Dd][Bb][Aa][Cc][Kk]
FILE=[Ff][Ii][Ll][Ee]
FORM=[Ff][Oo][Rr][Mm]
GROUP=[Gg][Rr][Oo][Uu][Pp]
HISTORY=[Hh][Ii][Ss][Tt][Oo][Rr][Yy]
HOUR=[Hh][Oo][Uu][Rr]
ID=[Ii][Dd]
IO=[Ii][Oo]
INPUT=[Ii][Nn][Pp][Uu][Tt]
INTERVAL=[Ii][Nn][Tt][Ee][Rr][Vv][Aa][Ll]
LATERAL=[Ll][Aa][Tt][Ee][Rr][Aa][Ll]
LOW=[Ll][Oo][Ww]
LOWER=[Ll][Oo][Ww][Ee][Rr]
MAX=[Mm][Aa][Xx]
MINUTE=[Mm][Ii][Nn][Uu][Tt][Ee]
MONTH=[Mm][Oo][Nn][Tt][Hh]
NIO=[Nn][Ii][Oo]
NO=[Nn][Oo]
PER=[Pp][Ee][Rr]
RESTART=[Rr][Ee][Ss][Tt][Aa][Rr][Tt]
RUN=[Rr][Uu][Nn]
SECOND=[Ss][Ee][Cc][Oo][Nn][Dd]
SST=[Ss][Ss][Tt]
START=[Ss][Tt][Aa][Rr][Tt]
TASK=[Tt][Aa][Ss][Kk]
UPDATE=[Uu][Pp][Dd][Aa][Tt][Ee]
WRF=[Ww][Rr][Ff]
YEAR=[Yy][Ee][Aa][Rr]
YES=[Yy][Ee][Ss]
