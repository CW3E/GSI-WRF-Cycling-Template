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

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
module load hdf5/1.10.7
module load netcdf/4.7.4intelmpi
export NETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export HDF5="/share/apps/compute/hdf5/intel2019/intelmpi"

# create variables for namelist templates / switches
CYCLING=[Cc][Yy][Cc][Ll][Ii][Nn][Gg]
EQUAL=[[:blank:]]*=[[:blank:]]*
LATERAL=[Ll][Aa][Tt][Ee][Rr][Aa][Ll]
LOWER=[Ll][Oo][Ww][Ee][Rr]
RESTART=[Rr][Ee][Ss][Tt][Aa][Rr][Tt]
REALEXE=[Rr][Ee][Aa][Ll][Ee][Xx][Ee]
NO=[Nn][Oo]
YES=[Yy][Ee][Ss]
