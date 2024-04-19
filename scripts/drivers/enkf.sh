#!/bin/bash
##################################################################################
# Description
##################################################################################
# NOTE: at this moment this script is not supported and has not been made to
# function with the current versions of the code.  This is simply kept here for
# later reference in case workflows using GSI-EnKF are implemented at a later date.
#
#
# This driver script is a major fork and rewrite of the standard EnKF.ksh
# driver script as discussed in the documentation:
# 
#   https://dtcenter.ucar.edu/EnKF/users/docs/enkf_users_guide/html_v1.3/enkf_ch3.html
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with WRF for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the wrf.ksh
# WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# GSI_constants.sh and the control flow .xml driving this script.
#
##################################################################################
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
##################################################################################
# Preamble
##################################################################################
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
# if_arw   = Ensemble comes from WRF-ARW .true. / .false.
# if_nmm   = Ensemble comes form WRF-NMM .true. / .false.
# ens_prfx = Prefix for the local links for ensemble member names of the form
#            ${ens_prfx}xxx
#
##################################################################################

# uncomment to run verbose for debugging / testing
set -x

if_arw=.true.
if_nmm=.false.
ens_prfx=wrf_en

##################################################################################
# Read in GSI constants for local environment
##################################################################################

if [ ! -x "${CNST}" ]; then
  echo "ERROR: \$CNST does not exist or is not executable!"
  exit 1
fi

. ${CNST}

##################################################################################
# Make checks for DA method settings
##################################################################################
# Options below are defined in cycling.xml (case insensitive)
#
# N_ENS         = INT   : Max ensemble index (00 for control alone) 
# MAX_DOM       = INT   : GSI analyzes the domain d0${dmn} for dmn -le ${MAX_DOM}
#
##################################################################################

if [ ! ${N_ENS} -ge 03 ]; then
	echo "ERROR: \$N_ENS must be specified to the number of ensemble perturbations (greater than 2)"
  exit 1
fi

if [ ! ${MAX_DOM} ]; then
  echo "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

##################################################################################
# Define GSI workflow dependencies
##################################################################################
# Below variables are defined in cycling.xml workflow variables
#
# ANL_TIME       = Analysis time YYYYMMDDHH
# GSI_ROOT       = Directory for clean GSI build
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Analysis time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
# MPIRUN         = MPI Command to execute GSI
# GSI_PROC       = Number of workers for MPI command to exectute on
#
# Below variables are derived by cycling.xml variables for convenience
#
# date_str       = Defined by the ANL_TIME variable, to be used as path
#                  name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
##################################################################################

if [ ! "${ANL_TIME}" ]; then
  echo "ERROR: \$ANL_TIME is not defined!"
  exit 1
fi

if [ `echo "${ANL_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  # Define directory path name variable date_str=YYMMDDHH from ANL_TIME
  hh=`echo ${ANL_TIME} | cut -c9-10`
  anal_date=`echo ${ANL_TIME} | cut -c1-8`
  date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anal_date} ${hh} hours"`
else
  echo "ERROR: start time, '${ANL_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi

if [ ! ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA is not defined!"
  exit 1
fi

if [ ! -d ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! "${INPUT_DATAROOT}" ]; then
  echo "ERROR: \$INPUT_DATAROOT is not defined!"
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \$MPIRUN is not defined!"
  exit 1
fi

if [ ! "${GSI_PROC}" ]; then
  echo "ERROR: \$GSI_PROC is not defined"
  exit 1
fi

if [ -z "${GSI_PROC}" ]; then
  echo "ERROR: The variable \$GSI_PROC must be set to the number of processors to run GSI"
  exit 1
fi

##################################################################################
# The following paths are relative to cycling.xml supplied root paths
#
# work_root     = Working directory where EnKF runs
# fix_root      = Path of fix files
# enkf_exe      = comGSI enkf_wrf.x executable
# enkf_namelist = Path and name of the enkf namelist constructor script
#
##################################################################################

work_root=${INPUT_DATAROOT}/enkfprd
fix_root=${GSI_ROOT}/fix
enkf_exe=${GSI_ROOT}/build/bin/enkf_wrf.x
enkf_namelist=${STATIC_DATA}/namelists/comenkf_namelist.sh

if [ ! -d "${fix_root}" ]; then
  echo "ERROR: FIX directory '${fix_root}' does not exist!"
  exit 1
fi

if [ ! -x "${enkf_exe}" ]; then
  echo "ERROR: ${enkf_exe} does not exist!"
  exit 1
fi

if [ ! -x "${enkf_namelist}" ]; then
  echo "ERROR: ${enkf_namelist} does not exist!"
  exit 1
fi

##################################################################################
# Begin pre-EnKF setup, running one domain at a time
##################################################################################
# Create the work directory organized by domain analyzed and cd into it
dmn=1

while [ ${dmn} -le ${MAX_DOM} ]; do
  work_dir=${work_root}/d0${dmn}

  if [ ! -d "${work_dir}" ]; then
    echo "ERROR \$work_dir ${work_dir} does not exist, this should be created with GSI observer step"
    exit 1
  else
    cd ${work_dir}
  fi

  # NOTE: Optional localization options, may want to test this out later for modifications
  # locinfo=${fix_root}/global_hybens_locinfo.l64.txt
  # cp ${locinfo} ./hybens_locinfo
  
  # get mean
  ln -sf wrf_inout_ensmean ./firstguess.ensmean
  
  # make analysis files
  cp firstguess.ensmean analysis.ensmean
  
  # get each member
  ens_n=1
  while [[ ${ens_n} -le ${N_ENS} ]]; do
     iiimem=`printf %03d $(( 10#${ens_n} ))`
     ln -sf ${ens_prfx}${iiimem} ./firstguess.mem${iiimem}
     cp firstguess.mem${iiimem} analysis.mem${iiimem}
     (( ens_n += 1 ))
  done
  
  # generate the same list as was given in observer step
  list=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `

  # define the x-y-z grid for namelist dynamically based on ensemble mean
  nlons=`ncdump -h wrf_inout_ensmean | grep "west_east =" | awk '{print $3}' `
  nlats=`ncdump -h wrf_inout_ensmean | grep "south_north =" | awk '{print $3}' `
  nlevs=`ncdump -h wrf_inout_ensmean | grep "bottom_top =" | awk '{print $3}' `

  # Build the GSI namelist on-the-fly
  . ${enkf_namelist}
  
  ###################################################
  # Run  EnKF
  ###################################################
  # Print run parameters
  echo
  echo "N_ENS          = ${N_ENS}"
  echo "ANL_TIME       = ${ANL_TIME}"
  echo "GSI_ROOT       = ${GSI_ROOT}"
  echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
  echo
  now=`date +%Y%m%d%H%M%S`
  echo "enkf started at ${now} on domain d0${dmn}"
  echo "Run EnKF"
  
  ${MPIRUN} -n ${GSI_PROC} ${enkf_exe} < enkf.nml > stdout 2>&1
  
  ###############################################################################################
  # Run time error check
  ###############################################################################################
  error=$?
  
  if [ ${error} -ne 0 ]; then
    echo "ERROR: ${enkf_exe} exited with status ${error}"
    exit ${error}
  fi
  (( dmn += 1 ))
done

echo "enkf.sh completed successfully at `date`"

exit 0
