#!/bin/ksh
#####################################################
# Description
#####################################################
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
# in a WRF_constants.ksh script to be sourced in the below.  Variables
# aliases in this script are based on conventions defined in the
# companion WRF_constants.ksh with this driver.
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
#     Purpose: This is a complete rewrite of the run_wrf.pl script that is
#              distributed with the WRF Standard Initialization.  This script
#              may be run on the command line, or it may be submitted directly
#              to a batch queueing system.  A few environment variables must be
#              set before it is run.
#
#     A short and simple "control" script could be written to call this script
#     or to submit this  script to a batch queueing  system.  Such a "control"
#     script  could  also  be  used to  set the above environment variables as
#     appropriate  for  a  particular experiment.  Batch  queueing options can
#     be  specified on the command  line or  as directives at  the top of this
#     script.  A set of default batch queueing directives is provided.
#
#####################################################
# Preamble
#####################################################
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
#####################################################
# uncomment to run verbose for debugging / testing
set -x
#####################################################
# Read in WRF constants for local environment
#####################################################

if [ ! -x "${CONSTANT}" ]; then
  ${ECHO} "ERROR: ${CONSTANT} does not exist or is not executable"
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

#####################################################
# Make checks for WRF settings
#####################################################
# Options below are defined in cycling.xml
#
# FCST_LENGTH = Total length of WRF forecast simulation in HH
# FCST_INTERVAL = Interval of wrfout.d01 in HH
# DATA_INTERVAL = Interval of input data in HH
# START_TIME = Simulation start time in YYMMDDHH
# MAX_WRF_DOM = Max number of domains to use in namelist settings
# MAX_GSI_DOM = Number of domains GSI analyzes when cycling
# IF_CYCLING = Yes / No: whether to use ICs from GSI analysis or real.exe, case insensitive
#
#####################################################

if [ ! ${FCST_LENGTH} ]; then
  ${ECHO} "ERROR: \$FCST_LENGTH is not defined!"
  exit 1
fi

if [ ! ${FCST_INTERVAL} ]; then
  ${ECHO} "ERROR: \$FCST_INTERVAL is not defined!"
  exit 1
fi

if [ ! "${DATA_INTERVAL}" ]; then
  ${ECHO} "ERROR: \$DATA_INTERVAL is not defined"
  exit 1
fi

if [ ! "${START_TIME}" ]; then
  ${ECHO} "ERROR: \$START_TIME is not defined"
  exit 1
fi

# Convert START_TIME from 'YYYYMMDDHH' format to start_time in Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{10}$/'` ]; then
  start_time=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi
start_time=`${DATE} -d "${start_time}"`
end_time=`${DATE} -d "${start_time} ${FCST_LENGTH} hours"`

if [ ! "${MAX_WRF_DOM}" ]; then
  ${ECHO} "ERROR: \$MAX_WRF_DOM is not defined"
  exit 1
fi

if [ ! "${MAX_GSI_DOM}" ]; then
  ${ECHO} "ERROR: \$MAX_GSI_DOM is not defined"
  exit 1
fi

if [[ ${IF_CYCLING} != ${YES} && ${IF_CYCLING} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_CYCLING must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_SST_UPDATE} != ${YES} && ${IF_SST_UPDATE} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_SST_UPDATE must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

#####################################################
# Define WRF workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# WRF_ROOT       = Root directory of a "clean" WRF build WRF/run directory
# WRF_PROC       = The total number of processes to run WRF with MPI
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories obs, bkg, gfsens, wpsprd, realprd, wrfprd, gsiprd
# MPIRUN         = MPI Command to execute WRF
#
#####################################################

if [ ! "${WRF_ROOT}" ]; then
  ${ECHO} "ERROR: \$WRF_ROOT is not defined"
  exit 1
fi

if [ ! -d ${WRF_ROOT} ]; then
  ${ECHO} "ERROR: \$WRF_ROOT directory ${WRF_ROOT} does not exist"
  exit 1
fi

if [ ! "${WRF_PROC}" ]; then
  ${ECHO} "ERROR: \$WRF_PROC is not defined"
  exit 1
fi

if [ -z "${WRF_PROC}" ]; then
  ${ECHO} "ERROR: The variable \$WRF_PROC must be set to the number of processors to run WRF"
  exit 1
fi

if [ ! -d ${STATIC_DATA} ]; then
  ${ECHO} "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! -d ${INPUT_DATAROOT} ]; then
  ${ECHO} "ERROR: \$INPUT_DATAROOT directory ${INPUT_DATAROOT} does not exist"
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \$MPIRUN is not defined!"
  exit 1
fi

#####################################################
# Begin pre-WRF setup
#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# WORK_ROOT      = Working directory where WRF runs
# WRF_DAT_FILES  = All file contents of clean WRF/run directory
#                  namelists, boundary and input data will be linked
#                  from other sources
# WRF_EXE        = Path and name of working executable
#
#####################################################

WORK_ROOT=${INPUT_DATAROOT}/wrfprd
set -A WRF_DAT_FILES ${WRF_ROOT}/run/*
WRF_EXE=${WRF_ROOT}/main/wrf.exe

if [ ! -x ${WRF_EXE} ]; then
  ${ECHO} "ERROR: ${WRF_EXE} does not exist, or is not executable"
  exit 1
fi

${MKDIR} -p ${WORK_ROOT}
cd ${WORK_ROOT}

# Make links to the WRF DAT files
for file in ${WRF_DAT_FILES[@]}; do
  ${ECHO} "${LN} -sf ${file}"
  ${LN} -sf ${file} ./
done

# Remove any old WRF outputs in the directory
${RM} -f wrfout_*

# Link WRF initial conditions from real.exe or GSI analysis depending on IF_CYCLING switch
dmn=1
while [ ${dmn} -le ${MAX_WRF_DOM} ]; do
  wrfinput_name=wrfinput_d0${dmn}
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${IF_CYCLING} = ${YES} && ${dmn} -le ${MAX_GSI_DOM} ]]; then
    if [[ ${dmn} = 1 ]]; then
      # obtain the input and boundary files from the lateral boundary update by WRFDA 
      wrfda_outname=${INPUT_DATAROOT}/wrfdaprd/lateral_bdy_update/wrfvar_out 
      ${LN} -sf ${wrfda_outname} ./${wrfinput_name}
      if [ ! -r ./${wrfinput_name} ]; then
        ${ECHO} "ERROR: ${WORK_ROOT}/${wrfinput_name} does not exist, or is not readable, check source ${wrfda_outname}"
        exit 1
      fi
    else
      # Nested domains have boundary conditions defined by parent, link from GSI analysis
      gsi_outname=${INPUT_DATAROOT}/gsiprd/d0${dmn}/wrfanl.d0${dmn}_${START_TIME}
      ${LN} -sf ${gsi_outname} ./${wrfinput_name}
      if [ ! -r ./${wrfinput_name} ]; then
        ${ECHO} "ERROR: ${WORK_ROOT}/${wrfinput_name} does not exist, or is not readable, check source ${gsi_outname}"
        exit 1
      fi
    fi
  else
    # else get initial conditions from real.exe
    real_outname=${INPUT_DATAROOT}/realprd/${wrfinput_name}
    ${LN} -sf ${real_outname} ./
    if [ ! -r ./${wrfinput_name} ]; then
      ${ECHO} "ERROR: ${WORK_ROOT}/${wrfinput_name} does not exist, or is not readable, check source ${real_outname}"
      exit 1
    fi
  fi
  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
    wrflowinp_name=wrflowinp_d0${dmn}
    real_outname=${INPUT_DATAROOT}/realprd/${wrflowinp_name}
    ${LN} -sf ${real_outname} ./
    if [ ! -s ${wrflowinp_name} ]; then
      ${ECHO} "ERROR: ${WORK_ROOT}/${wrflowinp_name} does not exist, or is not readable, check source ${real_outname}"
    fi
  fi
  (( dmn += 1 ))
done

if [[ ${IF_CYCLING} = ${YES} ]]; then
  # Link the wrfbdy_d01 file from the WRFDA updated BCs
  wrfda_outname=${INPUT_DATAROOT}/wrfdaprd/lateral_bdy_update/wrfbdy_d01
  ${LN} -sf ${wrfda_outname} ./wrfbdy_d01
  if [ ! -r ${WORK_ROOT}/wrfbdy_d01 ]; then
    ${ECHO} "ERROR: ${WORK_ROOT}/wrfbdy_d01 does not exist, or is not readable, check source in ${wrfda_outname}"
    exit 1
  fi
else
  # Link the wrfbdy_d01 file from real.exe
  real_outname=${INPUT_DATAROOT}/realprd/wrfbdy_d01
  ${LN} -sf ${real_outname} ./wrfbdy_01
  if [ ! -r ${WORK_ROOT}/wrfbdy_d01 ]; then
    ${ECHO} "ERROR: ${WORK_ROOT}/wrfbdy_d01 does not exist, or is not readable, check source in ${real_outname}"
    exit 1
  fi
fi

# Move existing rsl files to a subdir if there are any
${ECHO} "Checking for pre-existing rsl files"
if [ -f "rsl.out.0000" ]; then
  rsldir=rsl.wrf.`${LS} -l --time-style=+%Y%m%d%H%M%S rsl.out.0000 | ${CUT} -d" " -f 6`
  ${MKDIR} ${rsldir}
  ${ECHO} "Moving pre-existing rsl files to ${rsldir}"
  ${MV} rsl.out.* ${rsldir}
  ${MV} rsl.error.* ${rsldir}
else
  ${ECHO} "No pre-existing rsl files were found"
fi

#####################################################
#  Build WRF namelist
#####################################################
# Copy the wrf namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
${CP} ${STATIC_DATA}/namelists/namelist.input .

# Get the start and end time components
start_year=`${DATE} +%Y -d "${start_time}"`
start_month=`${DATE} +%m -d "${start_time}"`
start_day=`${DATE} +%d -d "${start_time}"`
start_hour=`${DATE} +%H -d "${start_time}"`
start_minute=`${DATE} +%M -d "${start_time}"`
start_second=`${DATE} +%S -d "${start_time}"`
end_year=`${DATE} +%Y -d "${end_time}"`
end_month=`${DATE} +%m -d "${end_time}"`
end_day=`${DATE} +%d -d "${end_time}"`
end_hour=`${DATE} +%H -d "${end_time}"`
end_minute=`${DATE} +%M -d "${end_time}"`
end_second=`${DATE} +%S -d "${end_time}"`

# Compute number of days and hours for the run
(( run_days = FCST_LENGTH / 24 ))
(( run_hours = FCST_LENGTH % 24 ))

# Update the run_days in wrf namelist.input
${CAT} namelist.input | ${SED} "s/\(${run}_${day}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${run_days}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update the run_hours in wrf namelist
${CAT} namelist.input | ${SED} "s/\(${run}_${hour}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${run_hours}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update the start time in wrf namelist (propagates settings to three domains)
${CAT} namelist.input | ${SED} "s/\(${start}_${year}\)${equal}[[:digit:]]\{4\}.*/\1 = ${start_year}, ${start_year}, ${start_year}/" \
   | ${SED} "s/\(${start}_${month}\)${equal}[[:digit:]]\{2\}.*/\1 = ${start_month}, ${start_month}, ${start_month}/" \
   | ${SED} "s/\(${start}_${day}\)${equal}[[:digit:]]\{2\}.*/\1 = ${start_day}, ${start_day}, ${start_day}/" \
   | ${SED} "s/\(${start}_${hour}\)${equal}[[:digit:]]\{2\}.*/\1 = ${start_hour}, ${start_hour}, ${start_hour}/" \
   | ${SED} "s/\(${start}_${minute}\)${equal}[[:digit:]]\{2\}.*/\1 = ${start_minute}, ${start_minute}, ${start_minute}/" \
   | ${SED} "s/\(${start}_${second}\)${equal}[[:digit:]]\{2\}.*/\1 = ${start_second}, ${start_second}, ${start_second}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update end time in namelist (propagates settings to three domains)
${CAT} namelist.input | ${SED} "s/\(${end}_${year}\)${equal}[[:digit:]]\{4\}.*/\1 = ${end_year}, ${end_year}, ${end_year}/" \
   | ${SED} "s/\(${end}_${month}\)${equal}[[:digit:]]\{2\}.*/\1 = ${end_month}, ${end_month}, ${end_month}/" \
   | ${SED} "s/\(${end}_${day}\)${equal}[[:digit:]]\{2\}.*/\1 = ${end_day}, ${end_day}, ${end_day}/" \
   | ${SED} "s/\(${end}_${hour}\)${equal}[[:digit:]]\{2\}.*/\1 = ${end_hour}, ${end_hour}, ${end_hour}/" \
   | ${SED} "s/\(${end}_${minute}\)${equal}[[:digit:]]\{2\}.*/\1 = ${end_minute}, ${end_minute}, ${end_minute}/" \
   | ${SED} "s/\(${end}_${second}\)${equal}[[:digit:]]\{2\}.*/\1 = ${end_second}, ${end_second}, ${end_second}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update the quilting settings to the parameters set in the workflow
${CAT} namelist.input | ${SED} "s/\(${nio}_${tasks}_${per}_${group}\)${equal}[[:digit:]]\{1,\}/\1 = ${NIO_TASKS_PER_GROUP}/" \
                      | ${SED} "s/\(${nio}_${group}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${NIO_GROUPS}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update data interval in namelist
(( data_interval_sec = DATA_INTERVAL * 3600 ))
${CAT} namelist.input | ${SED} "s/\(${interval}_${second}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${data_interval_sec}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
  # update the auxinput4_interval to the DATA_INTERVAL (propagates to three domains)
  (( auxinput4_minutes = DATA_INTERVAL * 60 ))
  ${CAT} namelist.input | ${SED} "s/\(${auxinput}4_${interval}\)${equal}[[:digit:]]\{1,\}.*/\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}/" \
     > namelist.input.new
  ${MV} namelist.input.new namelist.input
fi

# Update the max_dom in namelist
${CAT} namelist.input | ${SED} "s/\(max_dom\)${equal}[[:digit:]]\{1,\}/\1 = ${MAX_WRF_DOM}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

if [ "${WRITE_INPUT}" ]; then
${CAT} namelist.input | ${SED} "s/\(write_input\)${equal}.false./\1 = .true./" \
   > namelist.input.new
${MV} namelist.input.new namelist.input
(( history_begin_h = FCST_INTERVAL + 1))
${CAT} namelist.input | ${SED} "s/\(history_begin_h\)${equal}[[:digit:]]\{1,\}/\1 = ${history_begin_h}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input
fi

#####################################################
# Run WRF
#####################################################
# Print run parameters
${ECHO}
${ECHO} "WRF_ROOT       = ${WRF_ROOT}"
${ECHO} "STATIC_DATA    = ${STATIC_DATA}"
${ECHO} "INPUT_DATAROOT = ${INPUT_DATAROOT}"
${ECHO}
${ECHO} "FCST LENGTH    = ${FCST_LENGTH}"
${ECHO} "FCST INTERVAL  = ${FCST_INTERVAL}"
${ECHO} "MAX_WRF_DOM    = ${MAX_WRF_DOM}"
${ECHO} "MAX_GSI_DOM    = ${MAX_GSI_DOM}"
${ECHO} "IF_CYCLING     = ${IF_CYCLING}"
${ECHO} "IF_SST_UPDATE  = ${IF_SST_UPDATE}"
${ECHO}
${ECHO} "START TIME     = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${start_time}"`
${ECHO} "END TIME       = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
${ECHO}
now=`${DATE} +%Y%m%d%H%M%S`
${ECHO} "wrf started at ${now}"

${MPIRUN} ${WRF_EXE}

#####################################################
# Run time error check
#####################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.wrf.${now}
${MKDIR} ${rsldir}
${MV} rsl.out.* ${rsldir}
${MV} rsl.error.* ${rsldir}
${CP} namelist.* ${rsldir}

# Look for successful completion messages in rsl files, adjusted for quilting processes
nsuccess=`${CAT} ${rsldir}/rsl.* | ${AWK} '/SUCCESS COMPLETE WRF/' | ${WC} -l`
(( ntotal=(WRF_PROC - NIO_GROUPS * NIO_TASKS_PER_GROUP ) * 2 ))
${ECHO} "Found ${nsuccess} of ${ntotal} completion messages"
if [ ${nsuccess} -ne ${ntotal} ]; then
  ${ECHO} "ERROR: WRF did not complete sucessfully"
  if [ ${error} -ne 0 ]; then
    ${MPIRUN} ${EXIT_CALL} ${error}
    exit
  else
    ${MPIRUN} ${EXIT_CALL} 1
    exit
  fi
fi

if [[ ${IF_CYCLING} = ${YES} ]]; then
  # ensure that the cycle_io/date/bkg directory exists for starting next cycle
  cycle_intv=`${DATE} +%H -d "${CYCLE_INTV}"`
  datestr=`${DATE} +%Y%m%d%H -d "${start_time} ${cycle_intv} hours"`
  new_bkg=${datestr}/bkg
  ${MKDIR} -p ../../${new_bkg}
else
  current_bkg=${INPUT_DATAROOT}/bkg
  ${MKDIR} -p ${current_bkg}
fi

# Check for all wrfout files on FCST_INTERVAL and link files to the appropriate bkg directory
dmn=1
while [ ${dmn} -le ${MAX_WRF_DOM} ]; do
  fcst=0
  while [ ${fcst} -le ${FCST_LENGTH} ]; do
    datestr=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${start_time} ${fcst} hours"`
    if [ ! -s "wrfout_d0${dmn}_${datestr}" ]; then
      ${ECHO} "WRF failed to complete.  wrfout_d0${dmn}_${datestr} is missing or empty!"
      ${MPIRUN} ${EXIT_CALL} 1
      exit
    else
      if [[ ${IF_CYCLING} = ${YES} ]]; then
        ${LN} -sfr wrfout_d0${dmn}_${datestr} ../../${new_bkg}/
      else
        ${LN} -sfr wrfout_d0${dmn}_${datestr} ${current_bkg}/
      fi
    fi
    (( fcst += FCST_INTERVAL ))
  done
  (( dmn += 1 ))
done

# Remove links to the WRF DAT files
for file in ${WRF_DAT_FILES[@]}; do
    ${RM} -f `${BASENAME} ${file}`
done

${ECHO} "wrf.ksh completed successfully at `${DATE}`"

exit 0
