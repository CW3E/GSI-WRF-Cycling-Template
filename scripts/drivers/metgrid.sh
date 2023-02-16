#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# metgrid.exe driver script of Christopher Harrop Licensed for modification /
# redistribution in the License Statement below.
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with GSI for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the standard gsi.ksh
# driver script provided in the GSI tutorials.
#
# One should write machine specific options for the WPS environment
# in a WPS_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# WPS_constants.sh and the control flow .xml driving this script.
#
##################################################################################
# License Statement:
##################################################################################
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
# In addition to the Apache 2.0 License terms above, this software is
# furthermore licensed under the conditions of the source software from
# which this fork was derived.  This License statement is included
# in the following:
#
#     Open Source License/Disclaimer, Forecast Systems Laboratory
#     NOAA/OAR/FSL, 325 Broadway Boulder, CO 80305
#
#     This software is distributed under the Open Source Definition,
#     which may be found at http://www.opensource.org/osd.html.
#
#     In particular, redistribution and use in source and binary forms,
#     with or without modification, are permitted provided that the
#     following conditions are met:
#
#     - Redistributions of source code must retain this notice, this
#     list of conditions and the following disclaimer.
#
#     - Redistributions in binary form must provide access to this
#     notice, this list of conditions and the following disclaimer, and
#     the underlying source code.
#
#     - All modifications to this software must be clearly documented,
#     and are solely the responsibility of the agent making the
#     modifications.
#
#     - If significant modifications or enhancements are made to this
#     software, the FSL Software Policy Manager
#     (softwaremgr@fsl.noaa.gov) should be notified.
#
#     THIS SOFTWARE AND ITS DOCUMENTATION ARE IN THE PUBLIC DOMAIN
#     AND ARE FURNISHED "AS IS."  THE AUTHORS, THE UNITED STATES
#     GOVERNMENT, ITS INSTRUMENTALITIES, OFFICERS, EMPLOYEES, AND
#     AGENTS MAKE NO WARRANTY, EXPRESS OR IMPLIED, AS TO THE USEFULNESS
#     OF THE SOFTWARE AND DOCUMENTATION FOR ANY PURPOSE.  THEY ASSUME
#     NO RESPONSIBILITY (1) FOR THE USE OF THE SOFTWARE AND
#     DOCUMENTATION; OR (2) TO PROVIDE TECHNICAL SUPPORT TO USERS.
#
#     Script Name: metgrid.ksh
#
#          Author: Christopher Harrop
#                  Forecast Systems Laboratory
#                  325 Broadway R/FST
#                  Boulder, CO. 80305
#
#        Released: 10/30/2003
#         Version: 1.0
#         Changes: None
#
##################################################################################
# Preamble
##################################################################################
# uncomment to run verbose for debugging / testing
set -x

if [ ! -x "${CNST}" ]; then
  echo "ERROR: constants file ${CNST} does not exist or is not executable."
  exit 1
fi

# Read constants into the current shell
. ${CNST}

##################################################################################
# Make checks for metgrid settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID     = Ensemble ID index, 00 for control, i > 0 for perturbation
# FCST_LEN  = Total length of WRF forecast simulation in HH
# DATA_INT  = Interval of input data in HH
# STRT_TIME = Simulation start time in YYMMDDHH
# MAX_DOM   = Max number of domains to use in namelist settings
#
##################################################################################

if [ ! "${MEMID}"  ]; then
  echo "ERROR: \${MEMID} is not defined."
  exit 1
fi

# ensure padding to two digits is included
memid=`printf %02d $(( 10#${MEMID} ))`

if [ ! "${FCST_LEN}" ]; then
  echo "ERROR: \${FCST_LEN} is not defined."
  exit 1
fi

if [ ! "${DATA_INT}" ]; then
  echo "ERROR: \${DATA_INT} is not defined."
  exit 1
fi

if [ ! "${STRT_TIME}" ]; then
  echo "ERROR: \${STRT_TIME} is not defined."
  exit 1
fi

# Convert STRT_TIME from 'YYYYMMDDHH' format to strt_time Unix date format
if [ ${#STRT_TIME} -ne 10 ]; then
  echo "ERROR: \${STRT_TIME}, '${STRT_TIME}', is not in 'YYYYMMDDHH' format." 
  exit 1
else
  strt_time="${STRT_TIME:0:8} ${STRT_TIME:8:2}"
fi
strt_time=`date -d "${strt_time}"`
end_time=`date -d "${strt_time} ${FCST_LEN} hours"`

if [ ! ${MAX_DOM} ]; then
  echo "ERROR: \${MAX_DOM} is not defined."
  exit 1
fi

##################################################################################
# Define metgrid workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of a "clean" WPS build
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Start time named directory for cycling data containing
#             bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
#
##################################################################################

if [ ! "${WPS_ROOT}" ]; then
  echo "ERROR: \${WPS_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${WPS_ROOT}" ]; then
  echo "ERROR: \${WPS_ROOT} directory ${WPS_ROOT} does not exist."
  exit 1
fi

if [ ! -d ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} directory ${EXP_CNFG} does not exist."
  exit 1
fi

if [ -z ${CYCLE_HME} ]; then
  echo "ERROR: \${CYCLE_HME} directory name is not defined."
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \${MPIRUN} is not defined."
  exit 1
fi

if [ ! "${WPS_PROC}" ]; then
  echo "ERROR: \${WPS_PROC} is not defined."
  exit 1
fi

if [ -z "${WPS_PROC}" ]; then
  msg="ERROR: The variable \${WPS_PROC} must be set to the number"
  msg+=" of processors to run WPS."
  echo ${msg}
  exit 1
fi

##################################################################################
# Begin pre-metgrid setup
##################################################################################
# The following paths are relative to workflow root paths
#
# work_root     = Working directory where metgrid_exe runs and outputs
# wps_dat_files = All file contents of clean WPS directory
#                 namelists and input data will be linked from other sources
# metgrid_exe   = Path and name of working executable
#
##################################################################################

work_root=${CYCLE_HME}/wpsprd/ens_${memid}
if [ ! -d ${work_root} ]; then
  echo "ERROR: \${work_root} directory ${work_root} does not exist."
  exit 1
else
  cd ${work_root}
fi

wps_dat_files=(${WPS_ROOT}/*)
metgrid_exe=${WPS_ROOT}/metgrid.exe

if [ ! -x ${metgrid_exe} ]; then
  echo "ERROR: ${metgrid_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
  ln -sf ${file} ./
done

# Remove any previous geogrid static files
rm -f geo_em.d0*

# Check to make sure the geogrid input files (e.g. geo_em.d01.nc)
# are available and make links to them
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  geoinput_name=${EXP_CNFG}/geogrid/geo_em.d0${dmn}.nc
  if [ ! -r "${geoinput_name}" ]; then
    echo "ERROR: Input file '${geoinput_name}' is missing."
    exit 1
  fi
  ln -sf ${geoinput_name} ./
  (( dmn += 1 ))
done

##################################################################################
#  Build WPS namelist
##################################################################################
# Copy the wrf namelist from the static dir
# NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
cp ${EXP_CNFG}/namelists/namelist.wps .

# Update max_dom in namelist
in_dom="\(${MAX}_${DOM}\)${EQUAL}[[:digit:]]\{1,\}"
out_dom="\1 = ${MAX_DOM}"
cat namelist.wps \
  | sed "s/${in_dom}/${out_dom}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

# define start / end time patterns for namelist.wps
strt_dt=`date +%Y-%m-%d_%H:%M:%S -d "${strt_time}"`
end_dt=`date +%Y-%m-%d_%H:%M:%S -d "${end_time}"`

in_sd="\(${STRT}_${DATE}\)${EQUAL}'${YYYYMMDD_HHMMSS}'.*"
out_sd="\1 = '${strt_dt}','${strt_dt}','${strt_dt}'"
in_ed="\(${END}_${DATE}\)${EQUAL}'${YYYYMMDD_HHMMSS}'.*"
out_ed="\1 = '${end_dt}','${end_dt}','${end_dt}'"

# Update the start and end date in namelist (propagates settings to three domains)
cat namelist.wps \
  | sed "s/${in_sd}/${out_sd}/" \
  | sed "s/${in_ed}/${out_ed}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

# Update interval in namelist
(( data_interval_sec = DATA_INT * 3600 ))
in_int="\(${INTERVAL}_${SECOND}[Ss]\)${EQUAL}[[:digit:]]\{1,\}"
out_int="\1 = ${data_interval_sec}"
cat namelist.wps \
  | sed "s/${in_int}/${out_int}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

# Remove pre-existing metgrid files
rm -f met_em.d0*.*.nc

##################################################################################
# Run metgrid 
##################################################################################
# Print run parameters
echo
echo "EXP_CNFG  = ${EXP_CNFG}"
echo "MEMID     = ${MEMID}"
echo "CYCLE_HME = ${CYCLE_HME}"
echo "DATA_INT  = ${DATA_INT}"
echo "FCST_LEN  = ${FCST_LEN}"
echo
echo "MAX_DOM   = ${MAX_DOM}"
echo "STRT_TIME = "`date +"%Y/%m/%d %H:%M:%S" -d "${strt_time}"`
echo "END_TIME  = "`date +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
echo
now=`date +%Y%m%d%H%M%S`
echo "metgrid started at ${now}."

${MPIRUN} -n ${WPS_PROC} ${metgrid_exe}

##################################################################################
# Run time error check
##################################################################################
error=$?

# save metgrid logs
log_dir=metgrid_log.${now}
mkdir ${log_dir}
mv metgrid.log* ${log_dir}

# save a copy of namelist
cp namelist.wps ${log_dir}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${metgrid_exe} exited with status ${error}."
  exit ${error}
fi

# Check to see if metgrid outputs are generated
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  fcst=0
  while [ ${fcst} -le ${FCST_LEN} ]; do
    time_str=`date +%Y-%m-%d_%H:%M:%S -d "${strt_time} ${fcst} hours"`
    if [ ! -e "met_em.d0${dmn}.${time_str}.nc" ]; then
      echo "${metgrid_exe} for d0${dmn} failed to complete."
      exit 1
    fi
    (( fcst += DATA_INT ))
  done
  (( dmn += 1 ))
done

# Remove links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
    rm -f `basename ${file}`
done

# Remove namelist
rm -f namelist.wps

echo "metgrid.sh completed successfully at `date`."

##################################################################################
# end

exit 0
