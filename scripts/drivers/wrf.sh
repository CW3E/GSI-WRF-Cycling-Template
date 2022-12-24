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
set -x

# io_restart = 2 for regular or 102 for split restart files (currently only
# 2 supported)
io_restart=2

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: ${CONSTANT} does not exist or is not executable."
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

##################################################################################
# Make checks for WRF settings
##################################################################################
# Options below are defined in workflow variables 
#
# ENS_N          = Ensemble ID index, 00 for control, i > 00 for perturbation
# BKG_DATA       = String case variable for supported inputs: GFS, GEFS currently
# FCST_LENGTH    = Total length of WRF forecast simulation in HH
# FCST_INTERVAL  = Interval of wrfout.d01 in HH
# DATA_INTERVAL  = Interval of input data in HH
# CYCLE_INTERVAL = Interval in HH on which DA is cycled in a cycling control flow
# START_TIME     = Simulation start time in YYMMDDHH
# MAX_DOM        = Max number of domains to use in namelist settings
# DOWN_DOM       = First domain index to downscale ICs from d01, set parameter
#                  less than MAX_DOM if downscaling to be used
# IF_CYCLING     = Yes / No: whether to use ICs / BCs from GSI / WRFDA analysis
#                  or real.exe, case insensitive
# IF_SST_UPDATE  = Yes / No: whether WRF uses dynamic SST values 
# IF_FEEBACK     = Yes / No: whether WRF domains use 1- or 2-way nesting
#
##################################################################################

if [ ! "${ENS_N}" ]; then
  echo "ERROR: \${ENS_N} is not defined."
  exit 1
fi

# Ensure padding to two digits is included
ens_n=`printf %02d $(( 10#${ENS_N} ))`

if [ ! "${BKG_DATA}"  ]; then
  echo "ERROR: \${BKG_DATA} is not defined."
  exit 1
fi

if [[ "${BKG_DATA}" != "GFS" &&  "${BKG_DATA}" != "GEFS" ]]; then
  msg="ERROR: \${BKG_DATA} must equal \"GFS\" or \"GEFS\""
  msg+=" as currently supported inputs."
  echo ${msg}
  exit 1
fi

if [ ! ${FCST_LENGTH} ]; then
  echo "ERROR: \${FCST_LENGTH} is not defined."
  exit 1
fi

if [ ! ${FCST_INTERVAL} ]; then
  echo "ERROR: \${FCST_INTERVAL} is not defined."
  exit 1
fi

if [ ! "${DATA_INTERVAL}" ]; then
  echo "ERROR: \${DATA_INTERVAL} is not defined."
  exit 1
fi

if [ ! "${CYCLE_INTERVAL}" ]; then
  echo "ERROR: \${CYCLE_INTERVAL} is not defined."
  exit 1
fi

if [ ! "${START_TIME}" ]; then
  echo "ERROR: \${START_TIME} is not defined."
  exit 1
fi

# Convert START_TIME from 'YYYYMMDDHH' format to start_time Unix date format
if [ ${#START_TIME} -ne 10 ]; then
  echo "ERROR: start time, '${START_TIME}', is not in 'YYYYMMDDHH' format."
  exit 1
else
  start_time="${START_TIME:0:8} ${START_TIME:8:2}"
fi
start_time=`date -d "${start_time}"`
end_time=`date -d "${start_time} ${FCST_LENGTH} hours"`

if [ ! "${MAX_DOM}" ]; then
  echo "ERROR: \${MAX_DOM} is not defined."
  exit 1
fi

if [ ! "${DOWN_DOM}" ]; then
  echo "ERROR: \${DOWN_DOM} is not defined."
  exit 1
fi

if [[ ${IF_CYCLING} != ${YES} && ${IF_CYCLING} != ${NO} ]]; then
  echo "ERROR: \${IF_CYCLING} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
  echo "SST Update turned on."
  sst_update=1
elif [[ ${IF_SST_UPDATE} = ${NO} ]]; then
  sst_update=0
else
  echo "ERROR: \${IF_SST_UPDATE} must equal 'Yes' or 'No' (case insensitive)."
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
# WRF_ROOT   = Root directory of a "clean" WRF build WRF/run directory
# EXP_CONFIG = Root directory containing sub-directories for namelists
#              vtables, geogrid data, GSI fix files, etc.
# CYCLE_HOME = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# DATA_ROOT  = Directory for all forcing data files, including grib files,
#              obs files, etc.
# MPIRUN     = MPI Command to execute WRF
# WRF_PROC   = The total number of processes to run WRF with MPI
# NIO_GROUPS = Number of Quilting groups -- only used for NIO_TPG > 0
# NIO_TPG    = Quilting tasks per group, set=0 if no quilting IO is to be used
#
##################################################################################

if [ ! "${WRF_ROOT}" ]; then
  echo "ERROR: \${WRF_ROOT} is not defined."
  exit 1
fi

if [ ! -d ${WRF_ROOT} ]; then
  echo "ERROR: \${WRF_ROOT} directory ${WRF_ROOT} does not exist."
  exit 1
fi

if [ ! -d ${EXP_CONFIG} ]; then
  echo "ERROR: \${EXP_CONFIG} directory ${EXP_CONFIG} does not exist."
  exit 1
fi

if [ -z ${CYCLE_HOME} ]; then
  echo "ERROR: \${CYCLE_HOME} directory name is not defined."
  exit 1
fi

if [ ! -d ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} directory ${DATA_ROOT} does not exist."
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \${MPIRUN} is not defined."
  exit 1
fi

if [ ! "${WRF_PROC}" ]; then
  echo "ERROR: \${WRF_PROC} is not defined."
  exit 1
fi

if [ -z "${WRF_PROC}" ]; then
  msg="ERROR: The variable \${WRF_PROC} must be set to the number of "
  msg+="processors to run WRF."
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

work_root=${CYCLE_HOME}/wrfprd/ens_${ens_n}
mkdir -p ${work_root}
cd ${work_root}

wrf_dat_files=(${WRF_ROOT}/run/*)
wrf_exe=${WRF_ROOT}/main/wrf.exe

if [ ! -x ${wrf_exe} ]; then
  echo "ERROR: ${wrf_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  ln -sf ${file} ./
done

# Remove any old WRF outputs in the directory
rm -f wrfout_*

# Link WRF initial conditions from WPS real or GSI analysis depending on IF_CYCLING
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  wrfinput=wrfinput_d0${dmn}
  datestr=`date +%Y-%m-%d_%H:%M:%S -d "${start_time}"`
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${IF_CYCLING} = ${YES} && ${dmn} -lt ${DOWN_DOM} ]]; then
    if [[ ${dmn} = 1 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA 
      wrfanlroot="${CYCLE_HOME}/wrfdaprd/lateral_bdy_update/ens_${ens_n}"
      wrfbdy="${wrfanlroot}/wrfbdy_d01"
      cmd="ln -sf ${wrfbdy} ./wrfbdy_d01"
      echo ${cmd}; eval ${cmd}
      if [ ! -r "./wrfbdy_d01" ]; then
        echo "ERROR: wrfinput ${wrfbdy} does not exist or is not readable."
        exit 1
      fi

    else
      # Nested domains have boundary conditions defined by parent
      if [ ${ens_n} -eq 00 ]; then
	# control solution is indexed 00, analyzed with GSI
        wrfanl_root="${CYCLE_HOME}/gsiprd/d0${dmn}"
      else
	# ensemble perturbations are updated with EnKF step
        wrfanl_root="${CYCLE_HOME}/enkfprd/d0${dmn}"
      fi
    fi

    # link the wrf inputs
    wrfanl="${wrfanlroot}/wrfanl_ens_${ens_n}_${datestr}"
    cmd="ln -sf ${wrfanl} ./${wrfinput}"
    echo ${cmd}; eval ${cmd}
    if [ ! -r "./${wrfinput}" ]; then
      echo "ERROR: wrfinput ${wrfanl} does not exist or is not readable."
      exit 1
    fi

  else
    # else get initial and boundary conditions from real
    realroot=${CYCLE_HOME}/realprd/ens_${ens_n}
    if [[ ${dmn} = 1 ]]; then
      # Link the wrfbdy_d01 file from real
      wrfbdy="${realroot}/wrfbdy_d01"
      cmd="ln -sf ${wrfbdy} ./wrfbdy_d01"
      echo ${cmd}; eval ${cmd};

      if [ ! -r "./wrfbdy_d01" ]; then
        echo "ERROR: ${wrfbdy} does not exist or is not readable."
        exit 1
      fi
    fi
    realname="${realroot}/${wrfinput}"
    cmd="ln -sf ${realname} ./"
    echo ${cmd}; eval ${cmd}

    if [ ! -r ./${wrfinput} ]; then
      echo "ERROR: wrfinput ${realname} does not exist or is not readable."
      exit 1
    fi

  fi

  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
    wrflowinp=wrflowinp_d0${dmn}
    realname=${CYCLE_HOME}/realprd/ens_${ens_n}/${wrflowinp}
    cmd="ln -sf ${realname} ./"
    echo ${cmd}; eval ${cmd}
    if [ ! -r ${wrflowinp} ]; then
      echo "ERROR: wrflwinp ${wrflowinp} does not exist or is not readable."
      exit 1
    fi
  fi

  (( dmn += 1 ))
done

# Move existing rsl files to a subdir if there are any
echo "Checking for pre-existing rsl files."
if [ -f "rsl.out.0000" ]; then
  rsldir=rsl.wrf.`ls -l --time-style=+%Y%m%d%H%M%S rsl.out.0000 | cut -d" " -f 6`
  mkdir ${rsldir}
  echo "Moving pre-existing rsl files to ${rsldir}."
  mv rsl.out.* ${rsldir}
  mv rsl.error.* ${rsldir}
else
  echo "No pre-existing rsl files were found."
fi

##################################################################################
#  Build WRF namelist
##################################################################################
# Copy the wrf namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
namelist=${EXP_CONFIG}/namelists/namelist.${BKG_DATA}
cp ${namelist} ./namelist.input

# Get the start and end time components
s_Y=`date +%Y -d "${start_time}"`
s_m=`date +%m -d "${start_time}"`
s_d=`date +%d -d "${start_time}"`
s_H=`date +%H -d "${start_time}"`
s_M=`date +%M -d "${start_time}"`
s_S=`date +%S -d "${start_time}"`
e_Y=`date +%Y -d "${end_time}"`
e_m=`date +%m -d "${end_time}"`
e_d=`date +%d -d "${end_time}"`
e_H=`date +%H -d "${end_time}"`
e_M=`date +%M -d "${end_time}"`
e_S=`date +%S -d "${end_time}"`

# Compute number of days and hours, and total minutes, for the run
(( run_days = FCST_LENGTH / 24 ))
(( run_hours = FCST_LENGTH % 24 ))
(( run_mins = FCST_LENGTH * 60 ))

# Update the max_dom in namelist
cat namelist.input \
  | sed "s/\(${MAX}_${DOM}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${MAX_DOM}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the run_days in wrf namelist.input
cat namelist.input \
  | sed "s/\(${RUN}_${DAY}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${run_days}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the run_hours in wrf namelist
cat namelist.input \
  | sed "s/\(${RUN}_${HOUR}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${run_hours}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the restart interval in wrf namelist to the end of the FCST_LENGTH
cat namelist.input \
  | sed "s/\(${RESTART}_${INTERVAL}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${run_mins}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the restart I/O form in wrf namelist
cat namelist.input \
  | sed "s/\(${IO}_${FORM}_${RESTART}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${io_restart}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the start time in wrf namelist (propagates settings to three domains)
cat namelist.input \
  | sed "s/\(${START}_${YEAR}\)${EQUAL}[[:digit:]]\{4\}.*/\1 = ${s_Y}, ${s_Y}, ${s_Y}/" \
  | sed "s/\(${START}_${MONTH}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${s_m}, ${s_m}, ${s_m}/" \
  | sed "s/\(${START}_${DAY}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${s_d}, ${s_d}, ${s_d}/" \
  | sed "s/\(${START}_${HOUR}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${s_H}, ${s_H}, ${s_H}/" \
  | sed "s/\(${START}_${MINUTE}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${s_M}, ${s_M}, ${s_M}/" \
  | sed "s/\(${START}_${SECOND}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${s_S}, ${s_S}, ${s_S}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update end time in namelist (propagates settings to three domains)
cat namelist.input \
  | sed "s/\(${END}_${YEAR}\)${EQUAL}[[:digit:]]\{4\}.*/\1 = ${e_Y}, ${e_Y}, ${e_Y}/" \
  | sed "s/\(${END}_${MONTH}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${e_m}, ${e_m}, ${e_m}/" \
  | sed "s/\(${END}_${DAY}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${e_d}, ${e_d}, ${e_d}/" \
  | sed "s/\(${END}_${HOUR}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${e_H}, ${e_H}, ${e_H}/" \
  | sed "s/\(${END}_${MINUTE}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${e_M}, ${e_M}, ${e_M}/" \
  | sed "s/\(${END}_${SECOND}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${e_S}, ${e_S}, ${e_S}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update feedback option for nested domains
cat namelist.input \
  | sed "s/\(${FEEDBACK}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${feedback}/"\
  > namelist.input.new
mv namelist.input.new namelist.input

# Update the quilting settings to the parameters set in the workflow
cat namelist.input \
  | sed "s/\(${NIO}_${TASK}[Ss]_${PER}_${GROUP}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_TPG}/" \
  | sed "s/\(${NIO}_${GROUP}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_GROUPS}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update data interval in namelist
(( data_interval_sec = DATA_INTERVAL * 3600 ))
cat namelist.input \
  | sed "s/\(${INTERVAL}_${SECOND}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${data_interval_sec}/" \
  > namelist.input.new
mv namelist.input.new namelist.input

# Update sst_update settings
cat namelist.input \
  | sed "s/\(${SST}_${UPDATE}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${sst_update}/"\
  > namelist.input.new
mv namelist.input.new namelist.input

if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
  # update the auxinput4_interval to the DATA_INTERVAL
  (( auxinput4_minutes = DATA_INTERVAL * 60 ))
  aux_in="\(${AUXINPUT}4_${INTERVAL}\)${EQUAL}[[:digit:]]\{1,\}.*"
  aux_out="\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}"
  cat namelist.input \
    | sed "s/${aux_in}/${aux_out}/" \
    > namelist.input.new
  mv namelist.input.new namelist.input
fi

##################################################################################
# Run WRF
##################################################################################
# Print run parameters
echo
echo "ENS_N         = ${ENS_N}"
echo "BKG_DATA      = ${BKG_DATA}"
echo "WRF_ROOT      = ${WRF_ROOT}"
echo "EXP_CONFIG    = ${EXP_CONFIG}"
echo "CYCLE_HOME    = ${CYCLE_HOME}"
echo "DATA_ROOT     = ${DATA_ROOT}"
echo
echo "FCST LENGTH   = ${FCST_LENGTH}"
echo "FCST INTERVAL = ${FCST_INTERVAL}"
echo "MAX_DOM       = ${MAX_DOM}"
echo "IF_CYCLING    = ${IF_CYCLING}"
echo "IF_SST_UPDATE = ${IF_SST_UPDATE}"
echo "IF_FEEDBACK   = ${IF_FEEDBACK}"
echo
echo "START TIME    = "`date +"%Y/%m/%d %H:%M:%S" -d "${start_time}"`
echo "END TIME      = "`date +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
echo
now=`date +%Y%m%d%H%M%S`
echo "wrf started at ${now}."

${MPIRUN} -n ${WRF_PROC} ${wrf_exe}

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.wrf.${now}
mkdir ${rsldir}
mv rsl.out.* ${rsldir}
mv rsl.error.* ${rsldir}
cp namelist.* ${rsldir}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${wrf_exe} exited with status ${error}."
  exit ${error}
fi

# Look for successful completion messages adjusted for quilting processes
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE WRF/' | wc -l`
(( ntotal=(WRF_PROC - NIO_GROUPS * NIO_TPG ) * 2 ))
echo "Found ${nsuccess} of ${ntotal} completion messages"
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR: ${wrf_exe} did not complete successfully, missing completion "
  msg+="messages in rsl.* files."
  echo 
fi

# ensure that the cycle_io/date/bkg directory exists for starting next cycle
cycle_intv=`date +%H -d "${CYCLE_INTERVAL}"`
datestr=`date +%Y%m%d%H -d "${start_time} ${cycle_intv} hours"`
new_bkg=${datestr}/bkg/ens_${ens_n}
mkdir -p ${CYCLE_HOME}/../${new_bkg}

# Check for all wrfout files on FCST_INTERVAL and link files to
# the appropriate bkg directory
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  fcst=0
  while [ ${fcst} -le ${FCST_LENGTH} ]; do
    datestr=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${fcst} hours"`
    if [ ! -s "wrfout_d0${dmn}_${datestr}" ]; then
      msg="WRF failed to complete, wrfout_d0${dmn}_${datestr} "
      msg+="is missing or empty."
      echo ${msg}
      exit 1
    else
      ln -sfr wrfout_d0${dmn}_${datestr} ${CYCLE_HOME}/../${new_bkg}/
    fi

    (( fcst += FCST_INTERVAL ))
  done

  if [ ! -s "wrfrst_d0${dmn}_${datestr}" ]; then
    msg="WRF failed to complete, wrfrst_d0${dmn}_${datestr} is "
    msg+="missing or empty."
    echo 
    exit 1
  else
    ln -sfr wrfrst_d0${dmn}_${datestr} ${CYCLE_HOME}/../${new_bkg}/
  fi

  (( dmn += 1 ))
done

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    rm -f `basename ${file}`
done

echo "wrf.sh completed successfully at `date`."

##################################################################################
# end

exit 0
