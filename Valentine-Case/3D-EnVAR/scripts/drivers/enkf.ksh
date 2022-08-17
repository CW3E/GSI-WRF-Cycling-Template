#!/bin/ksh
#####################################################
# Description
#####################################################
# This driver script is a major fork and rewrite of the standard EnKF ksh
# driver script as discussed in the documentation:
# https://dtcenter.ucar.edu/EnKF/users/docs/enkf_users_guide/html_v1.3/enkf_ch3.html
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with WRF for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the wrf.ksh
# WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.ksh script to be sourced in the below.  Variables
# aliases in this script are based on conventions defined in the
# companion GSI_constants.ksh with this driver.
#
# SEE THE README FOR FURTHER INFORMATION
#
#####################################################
# License Statement:
#####################################################
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
#####################################################
# Preamble
#####################################################
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
# if_arw   = Ensemble comes from WRF-ARW .true. / .false.
# if_nmm   = Ensemble comes form WRF-NMM .true. / .false.
# ens_prfx = Prefix for the local links for ensemble member names of the form
#            ${ens_prfx}xxx
#
#####################################################

# uncomment to run verbose for debugging / testing
set -x

if_arw=.true.
if_nmm=.false.
ens_prfx=wrf_en

#####################################################
# Read in GSI constants for local environment
#####################################################

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: \$CONSTANT does not exist or is not executable!"
  exit 1
fi

. ${CONSTANT}

#####################################################
# Make checks for DA method settings
#####################################################
# Options below are defined in cycling.xml (case insensitive)
#
# MAX_DOM       = INT   : GSI analyzes the domain d0${dmn} for dmn -le ${MAX_DOM}
# N_ENS         = INT   : Max ensemble index (00 for control alone) 
#
#####################################################

if [ ! ${MAX_DOM} ]; then
  echo "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

if [ ! "${N_ENS}" ]; then
  echo "ERROR: \$N_ENS must be specified to the number of ensemble perturbations!"
  exit 1
fi

#####################################################
# Define GSI workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# ANAL_TIME      = Analysis time YYYYMMDDHH
# GSI_ROOT       = Directory for clean GSI build
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Analysis time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
# MPIRUN         = MPI Command to execute GSI
#
# Below variables are derived by cycling.xml variables for convenience
#
# date_str       = Defined by the ANAL_TIME variable, to be used as path
#                  name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
#####################################################

if [ ! "${ANAL_TIME}" ]; then
  echo "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

if [ `echo "${ANAL_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  # Define directory path name variable date_str=YYMMDDHH from ANAL_TIME
  hh=`echo ${ANAL_TIME} | cut -c9-10`
  anal_date=`echo ${ANAL_TIME} | cut -c1-8`
  date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anal_date} ${hh} hours"`
else
  echo "ERROR: start time, '${ANAL_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
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

#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# work_root     = Working directory where EnKF runs
# fix_root      = Path of fix files
# enkf_exe      = comGSI enkf_wrf.x executable
# enkf_namelist = Path and name of the enkf namelist constructor script
#
#####################################################

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

#####################################################
# Begin pre-EnKF setup, running one domain at a time
#####################################################
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
     iiimem=`printf %03d ${ens_n}`
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
  echo "ANAL_TIME      = ${ANAL_TIME}"
  echo "GSI_ROOT       = ${GSI_ROOT}"
  echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
  echo
  now=`date +%Y%m%d%H%M%S`
  echo "enkf started at ${now} on domain d0${dmn}"
  echo "Run EnKF"
  
  ${MPIRUN} ${enkf_exe} < enkf.nml > stdout 2>&1
  
  ##################################################################
  # Run time error check
  ##################################################################
  error=$?
  
  if [ ${error} -ne 0 ]; then
    echo "ERROR: ${enkf_exe} exited with status ${error}"
    exit ${error}
  fi
  (( dmn += 1 ))
done

echo "enkf.ksh completed successfully at `date`"

exit 0
