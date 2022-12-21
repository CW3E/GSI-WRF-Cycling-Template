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

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: constants file ${CONSTANT} does not exist or is not executable."
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

##################################################################################
# Make checks for real settings
##################################################################################
# Options below are defined in workflow variables
#
# ENS_N         = Ensemble ID index, 00 for control, i > 00 for perturbation
# BKG_DATA      = String case variable for supported inputs: GFS, GEFS currently
# FCST_LENGTH   = Total length of WRF forecast simulation in HH
# DATA_INTERVAL = Interval of input data in HH
# START_TIME    = Simulation start time in YYMMDDHH
# MAX_DOM       = Max number of domains to use in namelist settings
# IF_SST_UPDATE = "Yes" or "No" switch to compute dynamic SST forcing, (must
#                 include auxinput4 path and timing in namelist) case insensitive
#
##################################################################################

if [ ! "${ENS_N}"  ]; then
  echo "ERROR: \${ENS_N} is not defined."
  exit 1
fi

# ensure padding to two digits is included
ens_n=`printf %02d $(( 10#${ENS_N} ))`

if [ ! "${BKG_DATA}"  ]; then
  echo "ERROR: \${BKG_DATA} is not defined."
  exit 1
fi

if [[ "${BKG_DATA}" != "GFS" &&  "${BKG_DATA}" != "GEFS" ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs."
  echo ${msg}
  exit 1
fi

if [ ! "${FCST_LENGTH}" ]; then
  echo "ERROR: \${FCST_LENGTH} is not defined."
  exit 1
fi

if [ ! "${DATA_INTERVAL}" ]; then
  echo "ERROR: \${DATA_INTERVAL} is not defined."
  exit 1
fi

if [ ! "${START_TIME}" ]; then
  echo "ERROR: \${START_TIME} is not defined."
  exit 1
fi

# Convert START_TIME from 'YYYYMMDDHH' format to start_time Unix date format
if [ ${#START_TIME} -ne 10 ]; then
  echo "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' format."
  exit 1
else
  start_time="${START_TIME:0:8} ${START_TIME:8:2}"
fi
start_time=`date -d "${start_time}"`
end_time=`date -d "${start_time} ${FCST_LENGTH} hours"`

if [ ! ${MAX_DOM} ]; then
  echo "ERROR: \${MAX_DOM} is not defined."
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

##################################################################################
# Define real workflow dependencies
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
# MPIRUN     = MPI Command to execute real 
# WPS_PROC   = The total number of processes to run real.exe with MPI
#
##################################################################################

if [ ! "${WRF_ROOT}" ]; then
  echo "ERROR: \${WRF_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${WRF_ROOT}" ]; then
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

if [ ! "${WPS_PROC}" ]; then
  echo "ERROR: \${WPS_PROC} is not defined."
  exit 1
fi

if [ -z "${WPS_PROC}" ]; then
  msg="ERROR: The variable \${WPS_PROC} must be set to the number"
  msg+=" of processors to run real."
  echo ${msg}
  exit 1
fi

##################################################################################
# Begin pre-real setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root      = Working directory where real runs and outputs background files
# wrf_dat_files  = All file contents of clean WRF/run directory
#                  namelists, boundary and input data will be linked
#                  from other sources
# real_exe       = Path and name of working executable
#
##################################################################################

work_root=${CYCLE_HOME}/realprd/ens_${ens_n}
mkdir -p ${work_root}
cd ${work_root}

wrf_dat_files=(${WRF_ROOT}/run/*)
real_exe=${WRF_ROOT}/main/real.exe

if [ ! -x ${real_exe} ]; then
  echo "ERROR: ${real_exe} does not exist, or is not executable."
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  ln -sf ${file} ./
done

# Remove IC/BC in the directory if old data present
rm -f wrfinput_d0*
rm -f wrfbdy_d01

# Check to make sure the real input files (e.g. met_em.d01.*)
# are available and make links to them
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  fcst=0
  while [ ${fcst} -le ${FCST_LENGTH} ]; do
    time_str=`date "+%Y-%m-%d_%H:%M:%S" -d "${start_time} ${fcst} hours"`
    realinput_name=met_em.d0${dmn}.${time_str}.nc
    wps_dir=${CYCLE_HOME}/wpsprd/ens_${ens_n}
    if [ ! -r "${wps_dir}/${realinput_name}" ]; then
      echo "ERROR: Input file '${CYCLE_HOME}/${realinput_name}' is missing."
      exit 1
    fi
    ln -sf ${wps_dir}/${realinput_name} ./
    (( fcst += DATA_INTERVAL ))
  done
  (( dmn += 1 ))
done

# Move existing rsl files to a subdir if there are any
echo "Checking for pre-existing rsl files."
if [ -f "rsl.out.0000" ]; then
  rsldir=rsl.`ls -l --time-style=+%Y%m%d%H%M%S rsl.out.0000 | cut -d" " -f 7`
  mkdir ${rsldir}
  echo "Moving pre-existing rsl files to ${rsldir}."
  mv rsl.out.* ${rsldir}
  mv rsl.error.* ${rsldir}
else
  echo "No pre-existing rsl files were found."
fi

##################################################################################
#  Build real namelist
##################################################################################
# Copy the wrf namelist from the static dir
# NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
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

# Compute number of days and hours for the run
(( run_days = FCST_LENGTH / 24 ))
(( run_hours = FCST_LENGTH % 24 ))

# Update max_dom in namelist
in_dom="\(${MAX}_${DOM}\)${EQUAL}[[:digit:]]\{1,\}"
out_dom="\1 = ${MAX_DOM}"
cat namelist.wps \
  | sed "s/${in_dom}/${out_dom}/" \
  > namelist.wps.new
mv namelist.wps.new namelist.wps

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

# Update interval in namelist
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
# Run REAL
##################################################################################
# Print run parameters
echo
echo "ENS_N          = ${ENS_N}"
echo "BKG_DATA       = ${BKG_DATA}"
echo "WRF_ROOT       = ${WRF_ROOT}"
echo "EXP_CONFIG     = ${EXP_CONFIG}"
echo "CYCLE_HOME     = ${CYCLE_HOME}"
echo "DATA_ROOT      = ${DATA_ROOT}"
echo
echo "FCST LENGTH    = ${FCST_LENGTH}"
echo "DATA INTERVAL  = ${DATA_INTERVAL}"
echo "MAX_DOM        = ${MAX_DOM}"
echo "IF_SST_UPDATE  = ${IF_SST_UPDATE}"
echo
echo "START TIME     = "`date +"%Y/%m/%d %H:%M:%S" -d "${start_time}"`
echo "END TIME       = "`date +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
echo
now=`date +%Y%m%d%H%M%S`
echo "real started at ${now}."

${MPIRUN} -n ${WPS_PROC} ${real_exe}

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.real.${now}
mkdir ${rsldir}
mv rsl.out.* ${rsldir}
mv rsl.error.* ${rsldir}
cp namelist.* ${rsldir}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${real_exe} exited with status ${error}."
  exit ${error}
fi

# Look for successful completion messages in rsl files
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE REAL/' | wc -l`
(( ntotal = WPS_PROC * 2 ))
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
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  ic_file=wrfinput_d0${dmn}
  if [ ! -s ${ic_file} ]; then
    msg="${real_exe} failed to generate initial conditions ${ic_file} "
    msg+="for domain d0${dmn}."
    echo ${msg}
    exit 1
  fi
  (( dmn += 1 ))
done

# check to see if the SST update fields are generated
if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
  dmn=1
  while [ ${dmn} -le ${MAX_DOM} ]; do
    sst_file=wrflowinp_d0${dmn}
    if [ ! -s ${sst_file} ]; then
      msg="${real_exe} failed to generate SST update file ${sst_file} "
      msg+="for domain d0${dmn}."
      echo ${msg}
      exit 1
    fi
    (( dmn += 1 ))
  done
fi

# Remove the real input files (e.g. met_em.d01.*)
rm -f ./met_em.*

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    rm -f `basename ${file}`
done

echo "real.sh completed successfully at `date`."

##################################################################################
# end

exit 0
