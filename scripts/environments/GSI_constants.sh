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
# Copyright 2023 Colin Grudzien, cgrudzien@ucsd.edu
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

# set COMET specific environment for intelmpi 2018.1.163
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2018.1.163
module load intelmpi/2018.1.163
module load hdf5/1.10.3
module load netcdf/4.6.1

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
export NETCDF="/opt/netcdf/4.6.1/intel/intelmpi/"
export HDF5="/opt/hdf5/1.10.3/intel/intelmpi/"

# setup lapack
module load lapack
LAPACK_PATH="/share/apps/compute/lapack"

# ensure ulimit is set unlimited
ulimit -s unlimited

# Yes / No case insensitive switch
YES=[Yy][Ee][Ss]
NO=[Nn][Oo]
