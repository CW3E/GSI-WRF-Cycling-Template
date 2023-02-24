#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# real.exe driver script of Christopher Harrop Licensed for modification /
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
#     Script Name: wrf_wps.ksh
#
#         Author: Christopher Harrop
#                 Forecast Systems Laboratory
#                 325 Broadway R/FST
#                 Boulder, CO. 80305
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
# Make checks for real settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID        = Ensemble ID index, 00 for control, i > 00 for perturbation
# STRT_TIME    = Simulation start time in YYMMDDHH
# IF_DYN_LEN   = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS     = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF      = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT      = Interval of input data in HH
# BKG_DATA     = String case variable for supported inputs: GFS, GEFS currently
# MAX_DOM      = Max number of domains to use in namelist settings
# IF_SST_UPDTE = "Yes" or "No" switch to compute dynamic SST forcing, (must
#                include auxinput4 path and timing in namelist) case insensitive
#
##################################################################################

if [ ! ${MEMID}  ]; then
  echo "ERROR: \${MEMID} is not defined."
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
fi

if [ ${#STRT_TIME} -ne 10 ]; then
  echo "ERROR: \${STRT_TIME}, ${STRT_TIME}, is not in 'YYYYMMDDHH' format." 
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

if [[ ${BKG_DATA} != GFS &&  ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs."
  echo ${msg}
  exit 1
fi

if [ ${#MAX_DOM} -ne 2 ]; then
  echo "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not in DD format."
  exit 1
elif [ ! ${MAX_DOM} -gt 00 ]; then
  echo "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00." 
  exit 1
fi

if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  echo "SST Update turned on."
  sst_update=1
elif [[ ${IF_SST_UPDTE} = ${NO} ]]; then
  echo "SST Update turned off."
  sst_update=0
else
  echo "ERROR: \${IF_SST_UPDTE} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

##################################################################################
# Define real workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WRF_ROOT  = Root directory of a "clean" WRF build WRF/run directory
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Start time named directory for cycling data containing
#             bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# MPIRUN    = MPI multiprocessing evaluation call, machine specific
# N_PROC    = The total number of processes to run real.exe with MPI
#
##################################################################################

if [ ! ${WRF_ROOT} ]; then
  echo "ERROR: \${WRF_ROOT} is not defined."
  exit 1
elif [ ! -d ${WRF_ROOT} ]; then
  echo "ERROR: \${WRF_ROOT} directory ${WRF_ROOT} does not exist."
  exit 1
fi

if [ ! ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} is not defined."
  exit 1
elif [ ! -d ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} directory ${EXP_CNFG} does not exist."
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
  msg+=" of processors to run real.exe."
  echo ${msg}
  exit 1
fi

##################################################################################
# Begin pre-real setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root     = Working directory where real runs and outputs background files
# wrf_dat_files = All file contents of clean WRF/run directory
#                 namelists, boundary and input data will be linked
#                 from other sources
# real_exe      = Path and name of working executable
#
##################################################################################

work_root=${CYCLE_HME}/realprd/ens_${memid}
mkdir -p ${work_root}
cmd="cd ${work_root}"
echo ${cmd}; eval ${cmd}

wrf_dat_files=(${WRF_ROOT}/run/*)
real_exe=${WRF_ROOT}/main/real.exe

if [ ! -x ${real_exe} ]; then
  echo "ERROR: ${real_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  echo ${cmd}; eval ${cmd}
done

# Remove IC/BC in the directory if old data present
cmd="rm -f wrfinput_d0*"
echo ${cmd}; eval ${cmd}

cmd="rm -f wrfbdy_d01"
echo ${cmd}; eval ${cmd}

# Check to make sure the real input files (e.g. met_em.d01.*)
# are available and make links to them
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  for fcst in `seq -f "%03g" 0 ${BKG_INT} ${fcst_len}`; do
    time_str=`date "+%Y-%m-%d_%H_%M_%S" -d "${strt_time} ${fcst} hours"`
    realinput_name=met_em.d${dmn}.${time_str}.nc
    wps_dir=${CYCLE_HME}/wpsprd/ens_${memid}
    if [ ! -r "${wps_dir}/${realinput_name}" ]; then
      echo "ERROR: Input file '${CYCLE_HME}/${realinput_name}' is missing."
      exit 1
    else
      cmd="ln -sf ${wps_dir}/${realinput_name} ."
      echo ${cmd}; eval ${cmd}
    fi
  done
done

# Move existing rsl files to a subdir if there are any
echo "Checking for pre-existing rsl files."
if [ -f rsl.out.0000 ]; then
  rsldir=rsl.`ls -l --time-style=+%Y-%m-%d_%H_%M_%S rsl.out.0000 | cut -d" " -f 6`
  mkdir ${rsldir}
  echo "Moving pre-existing rsl files to ${rsldir}."
  cmd="mv rsl.out.* ${rsldir}"
  echo ${cmd}; eval ${cmd}
  cmd="mv rsl.error.* ${rsldir}"
  echo ${cmd}; eval ${cmd}
else
  echo "No pre-existing rsl files were found."
fi

##################################################################################
#  Build real namelist
##################################################################################
# Copy the wrf namelist template, NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
namelist_temp=${EXP_CNFG}/namelists/namelist.${BKG_DATA}
if [ ! -r ${namelist_temp} ]; then 
  msg="WRF namelist template '${namelist_temp}' is not readable or "
  msg+="does not exist."
  echo ${msg}
  exit 1
else
  cmd="cp ${namelist_temp} ./namelist.input"
  echo ${cmd}; eval ${cmd}
fi

# Get the start and end time components
s_Y=`date +%Y -d "${strt_time}"`
s_m=`date +%m -d "${strt_time}"`
s_d=`date +%d -d "${strt_time}"`
s_H=`date +%H -d "${strt_time}"`
s_M=`date +%M -d "${strt_time}"`
s_S=`date +%S -d "${strt_time}"`
e_Y=`date +%Y -d "${end_time}"`
e_m=`date +%m -d "${end_time}"`
e_d=`date +%d -d "${end_time}"`
e_H=`date +%H -d "${end_time}"`
e_M=`date +%M -d "${end_time}"`
e_S=`date +%S -d "${end_time}"`

# Compute number of days and hours for the run
(( run_days = FCST_HRS / 24 ))
(( run_hours = FCST_HRS % 24 ))

# Update max_dom in namelist
in_dom="\(MAX_DOM\)${EQUAL}MAX_DOM"
out_dom="\1 = ${MAX_DOM}"
cat namelist.input \
  | sed "s/${in_dom}/${out_dom}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the run_days in wrf namelist.input
cat namelist.input \
  | sed "s/\(RUN_DAYS\)${EQUAL}RUN_DAYS/\1 = ${run_days}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the run_hours in wrf namelist
cat namelist.input \
  | sed "s/\(RUN_HOURS\)${EQUAL}RUN_HOURS/\1 = ${run_hours}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the start time in wrf namelist (propagates settings to three domains)
cat namelist.input \
  | sed "s/\(START_YEAR\)${EQUAL}START_YEAR/\1 = ${s_Y}, ${s_Y}, ${s_Y}/" \
  | sed "s/\(START_MONTH\)${EQUAL}START_MONTH/\1 = ${s_m}, ${s_m}, ${s_m}/" \
  | sed "s/\(START_DAY\)${EQUAL}START_DAY/\1 = ${s_d}, ${s_d}, ${s_d}/" \
  | sed "s/\(START_HOUR\)${EQUAL}START_HOUR/\1 = ${s_H}, ${s_H}, ${s_H}/" \
  | sed "s/\(START_MINUTE\)${EQUAL}START_MINUTE/\1 = ${s_M}, ${s_M}, ${s_M}/" \
  | sed "s/\(START_SECOND\)${EQUAL}START_SECOND/\1 = ${s_S}, ${s_S}, ${s_S}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update end time in namelist (propagates settings to three domains)
cat namelist.input \
  | sed "s/\(END_YEAR\)${EQUAL}END_YEAR/\1 = ${e_Y}, ${e_Y}, ${e_Y}/" \
  | sed "s/\(END_MONTH\)${EQUAL}END_MONTH/\1 = ${e_m}, ${e_m}, ${e_m}/" \
  | sed "s/\(END_DAY\)${EQUAL}END_DAY/\1 = ${e_d}, ${e_d}, ${e_d}/" \
  | sed "s/\(END_HOUR\)${EQUAL}END_HOUR/\1 = ${e_H}, ${e_H}, ${e_H}/" \
  | sed "s/\(END_MINUTE\)${EQUAL}END_MINUTE/\1 = ${e_M}, ${e_M}, ${e_M}/" \
  | sed "s/\(END_SECOND\)${EQUAL}END_SECOND/\1 = ${e_S}, ${e_S}, ${e_S}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update interval in namelist
(( data_interval_sec = BKG_INT * 3600 ))
cat namelist.input \
  | sed "s/\(INTERVAL_SECONDS\)${EQUAL}INTERVAL_SECONDS/\1 = ${data_interval_sec}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update sst_update settings
cat namelist.input \
  | sed "s/\(SST_UPDATE\)${EQUAL}SST_UPDATE/\1 = ${sst_update}/"\
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  # update the auxinput4_interval to the BKG_INT
  (( auxinput4_minutes = BKG_INT * 60 ))
  aux_in="\(AUXINPUT4_INTERVAL\)${EQUAL}AUXINPUT4_INTERVAL"
  aux_out="\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}"
  cat namelist.input \
    | sed "s/${aux_in}/${aux_out}/" \
    > namelist.input.tmp
  mv namelist.input.tmp namelist.input
fi

##################################################################################
# Run REAL
##################################################################################
# Print run parameters
echo
echo "EXP_CNFG     = ${EXP_CNFG}"
echo "MEMID        = ${MEMID}"
echo "CYCLE_HME    = ${CYCLE_HME}"
echo "STRT_TIME    = "`date +%Y-%m-%d_%H_%M_%S -d "${strt_time}"`
echo "END_TIME     = "`date +%Y-%m-%d_%H_%M_%S -d "${end_time}"`
echo "BKG_INT      = ${BKG_INT}"
echo "BKG_DATA     = ${BKG_DATA}"
echo "MAX_DOM      = ${MAX_DOM}"
echo "IF_SST_UPDTE = ${IF_SST_UPDTE}"
echo
now=`date +%Y-%m-%d_%H_%M_%S`
echo "real started at ${now}."
cmd="${MPIRUN} -n ${N_PROC} ${real_exe}"
echo ${cmd}; eval ${cmd}

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.real.${now}
mkdir ${rsldir}
cmd="mv rsl.out.* ${rsldir}"
echo ${cmd}; eval ${cmd}

cmd="mv rsl.error.* ${rsldir}"
echo ${cmd}; eval ${cmd}

cmd="mv namelist.* ${rsldir}"
echo ${cmd}; eval ${cmd}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${real_exe} exited with status ${error}."
  exit ${error}
fi

# Look for successful completion messages in rsl files
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE REAL/' | wc -l`
(( ntotal = N_PROC * 2 ))
echo "Found ${nsuccess} of ${ntotal} completion messages."
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR: ${real_exe} did not complete sucessfully, missing "
  msg+="completion messages in rsl.* files."
  echo ${msg}
  exit 1
fi

# check to see if the BC output is generated
bc_file=wrfbdy_d01
if [ ! -s ${bc_file} ]; then
  echo "${real_exe} failed to generate boundary conditions ${bc_file}."
  exit 1
fi

# check to see if the IC output is generated
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  ic_file=wrfinput_d${dmn}
  if [ ! -s ${ic_file} ]; then
    msg="${real_exe} failed to generate initial conditions ${ic_file} "
    msg+="for domain d${dmn}."
    echo ${msg}
    exit 1
  fi
done

# check to see if the SST update fields are generated
if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
    sst_file=wrflowinp_d${dmn}
    if [ ! -s ${sst_file} ]; then
      msg="${real_exe} failed to generate SST update file ${sst_file} "
      msg+="for domain d${dmn}."
      echo ${msg}
      exit 1
    fi
  done
fi

# Remove the real input files (e.g. met_em.d01.*)
cmd="rm -f ./met_em.*"
echo ${cmd}; eval ${cmd}

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    cmd="rm -f `basename ${file}`"
    echo ${cmd}; eval ${cmd}
done

echo "real.sh completed successfully at `date`."

##################################################################################
# end

exit 0
