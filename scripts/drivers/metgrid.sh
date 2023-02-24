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
#set -x

if [ ! -x ${CNST} ]; then
  echo "ERROR: constants file ${CNST} does not exist or is not executable."
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  echo ${cmd}; eval ${cmd}
fi

##################################################################################
# Make checks for metgrid settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID      = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_TIME  = Simulation start time in YYMMDDHH
# IF_DYN_LEN = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS   = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF    = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT    = Interval of input data in HH
# MAX_DOM    = Max number of domains to use in namelist settings
#
##################################################################################

if [ ! ${MEMID} ]; then
  echo "ERROR: \${MEMID} is not defined."
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
fi

if [ ${#STRT_TIME} -ne 10 ]; then
  echo "ERROR: \${STRT_TIME}, '${STRT_TIME}', is not in 'YYYYMMDDHH' format." 
  exit 1
else
  # Convert STRT_TIME from 'YYYYMMDDHH' format to strt_time Unix date format
  strt_time="${STRT_TIME:0:8} ${STRT_TIME:8:2}"
  strt_time=`date -d "${strt_time}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  echo "Generating fixed length forecast forcing data."
  if [ ! ${FCST_HRS} ]; then
    echo "ERROR: \${FCST_HRS} is not defined."
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_len=`printf %03d $(( 10#${FCST_HRS} ))`
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  echo "Generating forecast forcing data until experiment validation time."
  if [ ${#EXP_VRF} -ne 10 ]; then
    echo "ERROR: \${EXP_VRF}, ${EXP_VRF} is not in 'YYYMMDDHH' format."
    exit 1
  else
    # compute forecast length relative to start time and verification time
    exp_vrf="${EXP_VRF:0:8} ${EXP_VRF:8:2}"
    exp_vrf=`date +%s -d "${exp_vrf}"`
    fcst_len=$(( (${exp_vrf} - `date +%s -d "${strt_time}"`) / 3600 ))
    fcst_len=`printf %03d $(( 10#${fcst_len} ))`
  fi
else
  echo "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive)."
  exit 1
fi

# define the end time based on forecast length control flow above
end_time=`date -d "${strt_time} ${fcst_len} hours"`

if [ ! ${BKG_INT} ]; then
  echo "ERROR: \${BKG_INT} is not defined."
  exit 1
elif [ ! ${BKG_INT} -gt 0 ]; then
  echo "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs."
  exit 1
fi

if [ ${#MAX_DOM} -ne 2 ]; then
  echo "ERROR: \${MAX_DOM}, ${MAX_DOM} is not in DD format."
  exit 1
elif [ ! ${MAX_DOM} -gt 00 ]; then
  echo "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00." 
  exit 1
fi

##################################################################################
# Define metgrid workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of a clean WPS build
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Cycle YYYYMMDDHH named directory for cycling data containing
#             bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# MPIRUN    = MPI multiprocessing evaluation call, machine specific
# N_PROC    = The total number of processes to run metgrid.exe with MPI
#
##################################################################################

if [ ! ${WPS_ROOT} ]; then
  echo "ERROR: \${WPS_ROOT} is not defined."
  exit 1
elif [ ! -d ${WPS_ROOT} ]; then
  echo "ERROR: \${WPS_ROOT} directory '${WPS_ROOT}' does not exist."
  exit 1
fi

if [ ! ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} is not defined."
  exit 1
elif [ ! -d ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} directory '${EXP_CNFG}' does not exist."
  exit 1
fi

if [ ${#CYCLE_HME} -ne 10 ]; then
  echo "ERROR: \${CYCLE_HME}, '${CYCLE_HME}', is not in 'YYYYMMDDHH' format." 
  exit 1
elif [ ! -d ${CYCLE_HME} ]; then
  echo "ERROR: \${CYCLE_HME} directory '${CYCLE_HME}' does not exist."
  exit 1
fi

if [ ! ${MPIRUN} ]; then
  echo "ERROR: \${MPIRUN} is not defined."
  exit 1
fi

if [ ! ${N_PROC} ]; then
  echo "ERROR: \${N_PROC} is not defined."
  exit 1
elif [ ! ${N_PROC} -gt 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processors to run metgrid.exe."
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
  cmd="cd ${work_root}"
  echo ${cmd}; eval ${cmd}
fi

wps_dat_files=(${WPS_ROOT}/*)
metgrid_exe=${WPS_ROOT}/metgrid.exe

if [ ! -x ${metgrid_exe} ]; then
  echo "ERROR: ${metgrid_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  echo ${cmd}; eval ${cmd}
done

# Remove any previous geogrid static files
cmd="rm -f geo_em.d*"
echo ${cmd}; eval ${cmd}

# Check to make sure the geogrid input files (e.g. geo_em.d01.nc)
# are available and make links to them
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  geoinput_name=${EXP_CNFG}/geogrid/geo_em.d${dmn}.nc
  if [ ! -r "${geoinput_name}" ]; then
    echo "ERROR: Input file '${geoinput_name}' is missing."
    exit 1
  else
    cmd="ln -sf ${geoinput_name} ."
    echo ${cmd}; eval ${cmd}
  fi
done

##################################################################################
#  Build WPS namelist
##################################################################################
# Copy the wps namelist template, NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
namelist_temp=${EXP_CNFG}/namelists/namelist.wps
if [ ! -r ${namelist_temp} ]; then 
  msg="WPS namelist template '${namelist_temp}' is not readable or "
  msg+="does not exist."
  echo ${msg}
  exit 1
else
  cmd="cp ${namelist_temp} ."
  echo ${cmd}; eval ${cmd}
fi

# Update max_dom in namelist
in_dom="\(MAX_DOM\)${EQUAL}MAX_DOM"
out_dom="\1 = ${MAX_DOM}"
cat namelist.wps \
  | sed "s/${in_dom}/${out_dom}/" \
  > namelist.wps.tmp
mv namelist.wps.tmp namelist.wps

# define start / end time patterns for namelist.wps
strt_dt=`date +%Y-%m-%d_%H_%M_%S -d "${strt_time}"`
end_dt=`date +%Y-%m-%d_%H_%M_%S -d "${end_time}"`

in_sd="\(START_DATE\)${EQUAL}START_DATE"
out_sd="\1 = '${strt_dt}','${strt_dt}','${strt_dt}'"
in_ed="\(END_DATE\)${EQUAL}END_DATE"
out_ed="\1 = '${end_dt}','${end_dt}','${end_dt}'"

# Update the start and end date in namelist (propagates settings to three domains)
cat namelist.wps \
  | sed "s/${in_sd}/${out_sd}/" \
  | sed "s/${in_ed}/${out_ed}/" \
  > namelist.wps.tmp
mv namelist.wps.tmp namelist.wps

# Update interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))
in_int="\(INTERVAL_SECONDS\)${EQUAL}INTERVAL_SECONDS"
out_int="\1 = ${data_interval_sec}"
cat namelist.wps \
  | sed "s/${in_int}/${out_int}/" \
  > namelist.wps.tmp
mv namelist.wps.tmp namelist.wps

# Remove pre-existing metgrid files
cmd="rm -f met_em.d0*.*.nc"
echo ${cmd}; eval ${cmd}

##################################################################################
# Run metgrid 
##################################################################################
# Print run parameters
echo
echo "EXP_CNFG  = ${EXP_CNFG}"
echo "MEMID     = ${MEMID}"
echo "CYCLE_HME = ${CYCLE_HME}"
echo "STRT_TIME = ${strt_dt}"
echo "END_TIME  = ${end_dt}"
echo "BKG_INT   = ${BKG_INT}"
echo "MAX_DOM   = ${MAX_DOM}"
echo
now=`date +%Y-%m-%d_%H_%M_%S`
echo "metgrid started at ${now}."
cmd="${MPIRUN} -n ${N_PROC} ${metgrid_exe}"
echo ${cmd}; eval ${cmd}

##################################################################################
# Run time error check
##################################################################################
error=$?

# save metgrid logs
log_dir=metgrid_log.${now}
mkdir ${log_dir}
cmd="mv metgrid.log* ${log_dir}"
echo ${cmd}; eval ${cmd}

cmd="mv namelist.wps ${log_dir}"
echo ${cmd}; eval ${cmd}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${metgrid_exe} exited with status ${error}."
  exit ${error}
fi

# Check to see if metgrid outputs are generated
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  for fcst in `seq -f "%03g" 0 ${BKG_INT} ${fcst_len}`; do
    time_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_time} ${fcst} hours"`
    if [ ! -s "met_em.d${dmn}.${time_str}.nc" ]; then
      echo "ERROR: ${metgrid_exe} failed to complete for d${dmn}."
      exit 1
    fi
  done
done

# Remove links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
  cmd="rm -f `basename ${file}`"
  echo ${cmd}; eval ${cmd}
done

echo "metgrid.sh completed successfully at `date`."

##################################################################################
# end

exit 0
