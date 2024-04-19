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
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
#
##########################################################################
# Using GMT time zone for time computations
export TZ="GMT"

# defines expanse environment
module purge
module restore

# intel
module load cpu/0.15.4
module load intel/19.1.1.217
module load intel-mpi/2019.8.254
module load netcdf-c/4.7.4
module load netcdf-fortran/4.5.3
module load netcdf-cxx/4.2
module load hdf5/1.10.6
module load parallel-netcdf/1.12.1

export NETCDF="/expanse/lustre/projects/ddp181/cpapadop/WRF_CODE/WRF-4.5/NETCDF"
export HDF5="/cm/shared/apps/spack/cpu/opt/spack/linux-centos8-zen2/intel-19.1.1.217/hdf5-1.10.6-v7kfafsb4rv7yds3i3zr4ym24q62veef"
# for quilting
export NETCDFPAR=${NETCDF}

# set up libs
export LD_LIBRARY_PATH=${NETCDF}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=${NETCDF}/bin:${PATH}

# create variables for namelist templates / switches
CYCLING=[Cc][Yy][Cc][Ll][Ii][Nn][Gg]
EQUAL=[[:blank:]]*=[[:blank:]]*
LATERAL=[Ll][Aa][Tt][Ee][Rr][Aa][Ll]
LOWER=[Ll][Oo][Ww][Ee][Rr]
RESTART=[Rr][Ee][Ss][Tt][Aa][Rr][Tt]
REALEXE=[Rr][Ee][Aa][Ll][Ee][Xx][Ee]
NO=[Nn][Oo]
YES=[Yy][Ee][Ss]
