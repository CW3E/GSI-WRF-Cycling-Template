#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# WRF driver script of Christopher Harrop Licensed for modification /
# redistribution in the License Statement below.
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with GSI for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the standard gsi.ksh
# driver script provided in the GSI tutorials.
#
# One should write machine specific options for the WRF environment
# in a WRF_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# WRF_constants.sh and the control flow .xml driving this script.
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
# Make checks for WRF settings
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
# DOWN_DOM     = First domain index to downscale ICs from d01, set parameter
#                less than MAX_DOM if downscaling to be used
# WRFOUT_INT   = Interval of wrfout in HH
# CYCLE_INT    = Interval in HH on which DA is cycled in a cycling control flow
# WRF_IC       = Defines where to source WRF initial and boundary conditions from
#                  WRF_IC = REALEXE : ICs / BCs from CYCLE_HME/realprd
#                  WRF_IC = CYCLING : ICs / BCs from GSI / WRFDA analysis
#                  WRF_IC = RESTART : ICs from restart file in CYCLE_HME/wrfprd
# IF_SST_UPDTE = Yes / No: whether WRF uses dynamic SST values 
# IF_FEEBACK   = Yes / No: whether WRF domains use 1- or 2-way nesting
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
  echo "ERROR: \${MAX_DOM}, ${MAX_DOM} is not in DD format."
  exit 1
elif [ ! ${MAX_DOM} -gt 00 ]; then
  echo "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00."
  exit 1
fi

if [ ${#DOWN_DOM} -ne 2 ]; then
  echo "ERROR: \${DOWN_DOM}, ${DOWN_DOM}, is not in DD format."
  exit 1
elif [ ! ${DOWN_DOM} -gt 01 ]; then
  msg="ERROR: \${DOWN_DOM} must be an integer for the first WRF domain index "
  msg+=" to be downscaled from parent ( > 01 )." 
  exit 1
fi

if [ ${#WRFOUT_INT} -ne 2 ]; then
  echo "ERROR: \${WRFOUT_INT} is not in HH format."
  exit 1
elif [ ! ${WRFOUT_INT} -gt 0 ]; then
  echo "ERROR: \${WRFOUT_INT} must be an integer for the max WRF domain index > 0." 
  exit 1
fi

if [ ${#CYCLE_INT} -ne 2 ]; then
  echo "ERROR: \${CYCLE_INT}, ${CYCLE_INT}, is not in 'HH' format."
  exit 1
fi

if [[ ${WRF_IC} = ${REALEXE} ]]; then
  echo "WRF initial and boundary conditions sourced from real.exe."
elif [[ ${WRF_IC} = ${CYCLING} ]]; then
  msg="WRF initial conditions and boundary conditions sourced from GSI / WRFDA "
  msg+=" analysis."
  echo ${msg}
elif [[ ${WRF_IC} = ${RESTART} ]]; then
  echo "WRF initial conditions sourced from restart files."
else
  msg="ERROR: \${WRF_IC}, ${WRF_IC}, must equal REALEXE, CYCLING or RESTART "
  msg+=" (case insensitive)."
  echo ${msg}
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

if [[ ${IF_FEEDBACK} = ${YES} ]]; then
  echo "Two-way WRF nesting is turned on."
  feedback=1
elif [[ ${IF_FEEDBACK} = ${NO} ]]; then
  echo "One-way WRF nesting is turned on."
  feedback=0
else
  echo "ERROR: \${IF_FEEDBACK} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

##################################################################################
# Define WRF workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WRF_ROOT   = Root directory of a clean WRF build WRF/run directory
# EXP_CONFIG = Root directory containing sub-directories for namelists
#              vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# DATA_ROOT  = Directory for all forcing data files, including grib files,
#              obs files, etc.
# MPIRUN     = MPI Command to execute WRF
# N_PROC     = The total number of processes to run wrf.exe with MPI
# NIO_GROUPS = Number of Quilting groups -- only used for NIO_TPG > 0
# NIO_TPG    = Quilting tasks per group, set=0 if no quilting IO is to be used
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
  echo "ERROR: \${EXP_CONFIG} directory ${EXP_CONFIG} does not exist."
  exit 1
fi

if [ ${#CYCLE_HME} -ne 10 ]; then
  echo "ERROR: \${CYCLE_HME}, '${CYCLE_HME}', is not in 'YYYYMMDDHH' format." 
  exit 1
elif [ ! -d ${CYCLE_HME} ]; then
  echo "ERROR: \${CYCLE_HME} directory '${CYCLE_HME}' does not exist."
  exit 1
fi

if [ ! ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} is not defined."
  exit 1
elif [ ! -d ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} directory ${DATA_ROOT} does not exist."
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
  msg+=" of processors to run wrf.exe."
  echo ${msg}
  exit 1
fi

##################################################################################
# Begin pre-WRF setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root      = Working directory where WRF runs
# wrf_dat_files  = All file contents of clean WRF/run directory
#                  namelists, boundary and input data will be linked
#                  from other sources
# wrf_exe        = Path and name of working executable
#
##################################################################################

work_root=${CYCLE_HME}/wrfprd/ens_${memid}
mkdir -p ${work_root}
cmd="cd ${work_root}"
echo ${cmd}; eval ${cmd}

wrf_dat_files=(${WRF_ROOT}/run/*)
wrf_exe=${WRF_ROOT}/main/wrf.exe

if [ ! -x ${wrf_exe} ]; then
  echo "ERROR: ${wrf_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  echo ${cmd}; eval ${cmd}
done

if [[ ${WRF_IC} = ${REALEXE} || ${WRF_IC} = ${CYCLING} ]]
  # Remove any old WRF outputs in the directory from failed runs
  cmd="rm -f wrfout_*"
  echo ${cmd}; eval ${cmd}
  cmd="rm -f wrfrst_*"
  echo ${cmd}; eval ${cmd}
fi

# Link WRF initial conditions
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  wrfinput=wrfinput_d${dmn}
  datestr=`date +%Y-%m-%d_%H_%M_%S -d "${strt_time}"`
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${WRF_IC} = ${CYCLING} && ${dmn} -lt ${DOWN_DOM} ]]; then
    if [[ ${dmn} = 01 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA 
      wrfanlroot=${CYCLE_HME}/wrfdaprd/lateral_bdy_update/ens_${memid}
      wrfbdy=${wrfanlroot}/wrfbdy_d01
      cmd="ln -sf ${wrfbdy} wrfbdy_d01"
      echo ${cmd}; eval ${cmd}
      if [ ! -r "./wrfbdy_d01" ]; then
        echo "ERROR: wrfinput ${wrfbdy} does not exist or is not readable."
        exit 1
      fi

    else
      # Nested domains have boundary conditions defined by parent
      if [ ${memid} -eq 00 ]; then
        # control solution is indexed 00, analyzed with GSI
        wrfanl_root=${CYCLE_HME}/gsiprd/d${dmn}
      else
        # ensemble perturbations are updated with EnKF step
        wrfanl_root=${CYCLE_HME}/enkfprd/d${dmn}
      fi
    fi

    # link the wrf inputs
    wrfanl=${wrfanlroot}/wrfanl_ens_${memid}_${datestr}
    cmd="ln -sf ${wrfanl} ${wrfinput}"
    echo ${cmd}; eval ${cmd}

    if [ ! -r ${wrfinput} ]; then
      echo "ERROR: wrfinput source ${wrfanl} does not exist or is not readable."
      exit 1
    fi

  elif [[ ${WRF_IC} = ${RESTART} ]]
    # check for restart files at valid start time for each domain
    wrfrst=${work_root}/wrfrst_d${dmn}_${datestr}
    if [ ! -r ${wrfrst} ]; then
      echo "ERROR: wrfrst source ${wrfrst} does not exist or is not readable."
      exit 1
    fi

  else
    # else get initial and boundary conditions from real for downscaled domains
    realroot=${CYCLE_HME}/realprd/ens_${memid}
    if [ ${dmn} = 01 ]; then
      # Link the wrfbdy_d01 file from real
      wrfbdy=${realroot}/wrfbdy_d01
      cmd="ln -sf ${wrfbdy} wrfbdy_d01"
      echo ${cmd}; eval ${cmd};

      if [ ! -r wrfbdy_d01 ]; then
        echo "ERROR: ${wrfbdy} does not exist or is not readable."
        exit 1
      fi
    fi
    realname=${realroot}/${wrfinput}
    cmd="ln -sf ${realname} ."
    echo ${cmd}; eval ${cmd}

    if [ ! -r ${wrfinput} ]; then
      echo "ERROR: wrfinput ${realname} does not exist or is not readable."
      exit 1
    fi
  fi

  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
    wrflowinp=wrflowinp_d${dmn}
    realname=${CYCLE_HME}/realprd/ens_${memid}/${wrflowinp}
    cmd="ln -sf ${realname} ."
    echo ${cmd}; eval ${cmd}
    if [ ! -r ${wrflowinp} ]; then
      echo "ERROR: wrflwinp ${wrflowinp} does not exist or is not readable."
      exit 1
    fi
  fi
done

# Move existing rsl files to a subdir if there are any
echo "Checking for pre-existing rsl files."
if [ -f rsl.out.0000 ]; then
  rsldir=rsl.wrf.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S rsl.out.0000 | cut -d" " -f 6`
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
#  Build WRF namelist
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

# Compute number of days and hours, and total minutes, for the run
(( run_days = fcst_len / 24 ))
(( run_hours = fcst_len % 24 ))
(( run_mins = fcst_len * 60 ))

# Update the max_dom in namelist
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

# Update the history interval in wrf namelist (minutes, propagates settings to three domains)
(( hist_int = ${WRFOUT_INT} * 60 ))
cat namelist.input \
  | sed "s/\(HISTORY_INTERVAL\)${EQUAL}HISTORY_INTERVAL/\1 = ${hist_int}, /" \
   > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the restart setting in wrf namelist depending on switch
if [[ ${WRF_IC} = ${RESTART} ]]; then
  cat namelist.input \
    | sed "s/\(RESTART\)${EQUAL}RESTART/\1 = .true./" \
    > namelist.input.tmp
  mv namelist.input.tmp namelist.input
else
  cat namelist.input \
    | sed "s/\(RESTART\)${EQUAL}RESTART/\1 = .false./" \
    > namelist.input.tmp
  mv namelist.input.tmp namelist.input
fi

# Update the restart interval in wrf namelist to the end of the fcst_len
cat namelist.input \
  | sed "s/\(RESTART_INTERVAL\)${EQUAL}RESTART_INTERVAL/\1 = ${run_mins}/" \
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

# Update feedback option for nested domains
cat namelist.input \
  | sed "s/\(FEEDBACK\)${EQUAL}FEEDBACK/\1 = ${feedback}/"\
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the quilting settings to the parameters set in the workflow
cat namelist.input \
  | sed "s/\(NIO_TASKS_PER_GROUP\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_TPG}/" \
  | sed "s/\(NIO_GROUPS\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_GROUPS}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

##################################################################################
# Run WRF
##################################################################################
# Print run parameters
echo
echo "EXP_CONFIG   = ${EXP_CONFIG}"
echo "MEMID        = ${MEMID}"
echo "CYCLE_HME    = ${CYCLE_HME}"
echo "STRT TIME    = "`date +"%Y-%m-%d_%H_%M_%S" -d "${strt_time}"`
echo "END TIME     = "`date +"%Y-%m-%d_%H_%M_%S" -d "${end_time}"`
echo "WRFOUT_INT   = ${WRFOUT_INT}"
echo "BKG_DATA     = ${BKG_DATA}"
echo "MAX_DOM      = ${MAX_DOM}"
echo "WRF_IC       = ${WRF_IC}"
echo "IF_SST_UPDTE = ${IF_SST_UPDTE}"
echo "IF_FEEDBACK  = ${IF_FEEDBACK}"
echo
now=`date +%Y-%m-%d_%H_%M_%S`
echo "wrf started at ${now}."
cmd="${MPIRUN} -n ${N_PROC} ${wrf_exe}"
echo ${cmd}; eval ${cmd}

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.wrf.${now}
mkdir ${rsldir}
cmd="mv rsl.out.* ${rsldir}"
echo ${cmd}; eval ${cmd}
cmd="mv rsl.error.* ${rsldir}"
echo ${cmd}; eval ${cmd}
cmd="mv namelist.* ${rsldir}"
echo ${cmd}; eval ${cmd}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${wrf_exe} exited with status ${error}."
  exit ${error}
fi

# Look for successful completion messages adjusted for quilting processes
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE WRF/' | wc -l`
ntotal=$(( (N_PROC - NIO_GROUPS * NIO_TPG ) * 2 ))
echo "Found ${nsuccess} of ${ntotal} completion messages"
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR: ${wrf_exe} did not complete successfully, missing completion "
  msg+="messages in rsl.* files."
  echo 
fi

# ensure that the bkg directory exists in next ${CYCLE_HME}
datestr=`date +%Y%m%d%H -d "${strt_time} ${CYCLE_INT} hours"`
new_bkg=${datestr}/bkg/ens_${memid}
cmd="mkdir -p ${CYCLE_HME}/../${new_bkg}"
echo ${cmd}; eval ${cmd}

# Check for all wrfout files on WRFOUT_INT and link files to
# the appropriate bkg directory
for dmn in `seq -f "%02g" 1 ${MAX_DOM}`; do
  for fcst in `seq -f "%03g" 0 ${WRFOUT_INT} ${fcst_len}`; do
    datestr=`date +%Y-%m-%d_%H_%M_%S -d "${strt_time} ${fcst} hours"`
    if [ ! -s wrfout_d${dmn}_${datestr} ]; then
      msg="WRF failed to complete, wrfout_d${dmn}_${datestr} "
      msg+="is missing or empty."
      echo ${msg}
      exit 1
    else
      cmd="ln -sf wrfout_d${dmn}_${datestr} ${CYCLE_HME}/../${new_bkg}"
      echo ${cmd}; eval ${cmd}
    fi
  done

  if [ ! -s wrfrst_d${dmn}_${datestr} ]; then
    msg="WRF failed to complete, wrfrst_d${dmn}_${datestr} is "
    msg+="missing or empty."
    echo 
    exit 1
  else
    cmd="ln -sf wrfrst_d${dmn}_${datestr} ${CYCLE_HME}/../${new_bkg}"
    echo ${cmd}; eval ${cmd}
  fi
done

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    cmd="rm -f `basename ${file}`"
    echo ${cmd}; eval ${cmd}
done

echo "wrf.sh completed successfully at `date`."

##################################################################################
# end

exit 0
