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
  echo "ERROR: ${CONSTANT} does not exist or is not executable"
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

#####################################################
# Make checks for WRF settings
#####################################################
# Options below are defined in cycling.xml
#
# ENS_N       = Ensemble index (00 for control)
# FCST_LENGTH = Total length of WRF forecast simulation in HH
# FCST_INTERVAL = Interval of wrfout.d01 in HH
# DATA_INTERVAL = Interval of input data in HH
# START_TIME = Simulation start time in YYMMDDHH
# MAX_WRF_DOM = Max number of domains to use in namelist settings
# MAX_GSI_DOM = Number of domains GSI analyzes when cycling
# IF_CYCLING = Yes / No: whether to use ICs / BCs from GSI / WRFDA analysis or real.exe, case insensitive
#
#####################################################

if [ ! "${ENS_N}" ]; then
  echo "ERROR: \$ENS_N is not defined!"
  exit 1
fi

# ensure padding to two digits is included
ens_n=`printf %02d ${ENS_N}`

if [ ! ${FCST_LENGTH} ]; then
  echo "ERROR: \$FCST_LENGTH is not defined!"
  exit 1
fi

if [ ! ${FCST_INTERVAL} ]; then
  echo "ERROR: \$FCST_INTERVAL is not defined!"
  exit 1
fi

if [ ! "${DATA_INTERVAL}" ]; then
  echo "ERROR: \$DATA_INTERVAL is not defined"
  exit 1
fi

if [ ! "${START_TIME}" ]; then
  echo "ERROR: \$START_TIME is not defined"
  exit 1
fi

# Convert START_TIME from 'YYYYMMDDHH' format to start_time in Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `echo "${START_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  start_time=`echo "${START_TIME}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  echo "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi
start_time=`date -d "${start_time}"`
end_time=`date -d "${start_time} ${FCST_LENGTH} hours"`

if [ ! "${MAX_WRF_DOM}" ]; then
  echo "ERROR: \$MAX_WRF_DOM is not defined"
  exit 1
fi

if [ ! "${MAX_GSI_DOM}" ]; then
  echo "ERROR: \$MAX_GSI_DOM is not defined"
  exit 1
fi

if [[ ${IF_CYCLING} != ${YES} && ${IF_CYCLING} != ${NO} ]]; then
  echo "ERROR: \$IF_CYCLING must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_SST_UPDATE} != ${YES} && ${IF_SST_UPDATE} != ${NO} ]]; then
  echo "ERROR: \$IF_SST_UPDATE must equal 'Yes' or 'No' (case insensitive)"
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
#                  grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
# MPIRUN         = MPI Command to execute WRF
#
#####################################################

if [ ! "${WRF_ROOT}" ]; then
  echo "ERROR: \$WRF_ROOT is not defined"
  exit 1
fi

if [ ! -d ${WRF_ROOT} ]; then
  echo "ERROR: \$WRF_ROOT directory ${WRF_ROOT} does not exist"
  exit 1
fi

if [ ! "${WRF_PROC}" ]; then
  echo "ERROR: \$WRF_PROC is not defined"
  exit 1
fi

if [ -z "${WRF_PROC}" ]; then
  echo "ERROR: The variable \$WRF_PROC must be set to the number of processors to run WRF"
  exit 1
fi

if [ ! -d ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! -d ${INPUT_DATAROOT} ]; then
  echo "ERROR: \$INPUT_DATAROOT directory ${INPUT_DATAROOT} does not exist"
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
# work_root      = Working directory where WRF runs
# wrf_dat_files  = All file contents of clean WRF/run directory
#                  namelists, boundary and input data will be linked
#                  from other sources
# wrf_exe        = Path and name of working executable
#
#####################################################

work_root=${INPUT_DATAROOT}/wrfprd/ens_${ens_n}
set -A wrf_dat_files ${WRF_ROOT}/run/*
wrf_exe=${WRF_ROOT}/main/wrf.exe

if [ ! -x ${wrf_exe} ]; then
  echo "ERROR: ${wrf_exe} does not exist, or is not executable"
  exit 1
fi

mkdir -p ${work_root}
cd ${work_root}

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  echo "ln -sf ${file}"
  ln -sf ${file} ./
done

# Remove any old WRF outputs in the directory
rm -f wrfout_*

# Link WRF initial conditions from real.exe or GSI analysis depending on IF_CYCLING switch
dmn=1
while [ ${dmn} -le ${MAX_WRF_DOM} ]; do
  wrfinput_name=wrfinput_d0${dmn}
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${IF_CYCLING} = ${YES} && ${dmn} -le ${MAX_GSI_DOM} ]]; then
    if [[ ${dmn} = 1 ]]; then
      # obtain the input and boundary files from the lateral boundary update by WRFDA 
      wrfda_outname=${INPUT_DATAROOT}/wrfdaprd/ens_${ens_n}/lateral_bdy_update/wrfvar_output 
      ln -sf ${wrfda_outname} ./${wrfinput_name}
      if [ ! -r ./${wrfinput_name} ]; then
        echo "ERROR: ${work_root}/${wrfinput_name} does not exist, or is not readable, check source ${wrfda_outname}"
        exit 1
      fi
    else
      # Nested domains have boundary conditions defined by parent, link from GSI analysis
      gsi_outname=${INPUT_DATAROOT}/gsiprd/d0${dmn}/wrfanl.d0${dmn}_${START_TIME}
      ln -sf ${gsi_outname} ./${wrfinput_name}
      if [ ! -r ./${wrfinput_name} ]; then
        echo "ERROR: ${work_root}/${wrfinput_name} does not exist, or is not readable, check source ${gsi_outname}"
        exit 1
      fi
    fi
  else
    # else get initial conditions from real.exe
    real_outname=${INPUT_DATAROOT}/realprd/ens_${ens_n}/${wrfinput_name}
    ln -sf ${real_outname} ./
    if [ ! -r ./${wrfinput_name} ]; then
      echo "ERROR: ${work_root}/${wrfinput_name} does not exist, or is not readable, check source ${real_outname}"
      exit 1
    fi
  fi
  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
    wrflowinp_name=wrflowinp_d0${dmn}
    real_outname=${INPUT_DATAROOT}/realprd/ens_${ens_n}/${wrflowinp_name}
    ln -sf ${real_outname} ./
    if [ ! -s ${wrflowinp_name} ]; then
      echo "ERROR: ${work_root}/${wrflowinp_name} does not exist, or is not readable, check source ${real_outname}"
    fi
  fi
  (( dmn += 1 ))
done

if [[ ${IF_CYCLING} = ${YES} ]]; then
  # Link the wrfbdy_d01 file from the WRFDA updated BCs
  wrfda_outname=${INPUT_DATAROOT}/wrfdaprd/ens_${ens_n}/lateral_bdy_update/wrfbdy_d01
  ln -sf ${wrfda_outname} ./wrfbdy_d01
  if [ ! -r ${work_root}/wrfbdy_d01 ]; then
    echo "ERROR: ${work_root}/wrfbdy_d01 does not exist, or is not readable, check source in ${wrfda_outname}"
    exit 1
  fi
else
  # Link the wrfbdy_d01 file from real.exe
  real_outname=${INPUT_DATAROOT}/realprd/ens_${ens_n}/wrfbdy_d01
  ln -sf ${real_outname} ./wrfbdy_d01
  if [ ! -r ${work_root}/wrfbdy_d01 ]; then
    echo "ERROR: ${work_root}/wrfbdy_d01 does not exist, or is not readable, check source in ${real_outname}"
    exit 1
  fi
fi

# Move existing rsl files to a subdir if there are any
echo "Checking for pre-existing rsl files"
if [ -f "rsl.out.0000" ]; then
  rsldir=rsl.wrf.`ls -l --time-style=+%Y%m%d%H%M%S rsl.out.0000 | cut -d" " -f 6`
  mkdir ${rsldir}
  echo "Moving pre-existing rsl files to ${rsldir}"
  mv rsl.out.* ${rsldir}
  mv rsl.error.* ${rsldir}
else
  echo "No pre-existing rsl files were found"
fi

#####################################################
#  Build WRF namelist
#####################################################
# Copy the wrf namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
cp ${STATIC_DATA}/namelists/namelist.input .

# Get the start and end time components
start_year=`date +%Y -d "${start_time}"`
start_month=`date +%m -d "${start_time}"`
start_day=`date +%d -d "${start_time}"`
start_hour=`date +%H -d "${start_time}"`
start_minute=`date +%M -d "${start_time}"`
start_second=`date +%S -d "${start_time}"`
end_year=`date +%Y -d "${end_time}"`
end_month=`date +%m -d "${end_time}"`
end_day=`date +%d -d "${end_time}"`
end_hour=`date +%H -d "${end_time}"`
end_minute=`date +%M -d "${end_time}"`
end_second=`date +%S -d "${end_time}"`

# Compute number of days and hours for the run
(( run_days = FCST_LENGTH / 24 ))
(( run_hours = FCST_LENGTH % 24 ))

# Update the run_days in wrf namelist.input
cat namelist.input | sed "s/\(${RUN}_${DAY}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${run_days}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update the run_hours in wrf namelist
cat namelist.input | sed "s/\(${RUN}_${HOUR}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${run_hours}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update the start time in wrf namelist (propagates settings to three domains)
cat namelist.input | sed "s/\(${START}_${YEAR}\)${EQUAL}[[:digit:]]\{4\}.*/\1 = ${start_year}, ${start_year}, ${start_year}/" \
   | sed "s/\(${START}_${MONTH}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${start_month}, ${start_month}, ${start_month}/" \
   | sed "s/\(${START}_${DAY}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${start_day}, ${start_day}, ${start_day}/" \
   | sed "s/\(${START}_${HOUR}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${start_hour}, ${start_hour}, ${start_hour}/" \
   | sed "s/\(${START}_${MINUTE}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${start_minute}, ${start_minute}, ${start_minute}/" \
   | sed "s/\(${START}_${SECOND}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${start_second}, ${start_second}, ${start_second}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update end time in namelist (propagates settings to three domains)
cat namelist.input | sed "s/\(${END}_${YEAR}\)${EQUAL}[[:digit:]]\{4\}.*/\1 = ${end_year}, ${end_year}, ${end_year}/" \
   | sed "s/\(${END}_${MONTH}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${end_month}, ${end_month}, ${end_month}/" \
   | sed "s/\(${END}_${DAY}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${end_day}, ${end_day}, ${end_day}/" \
   | sed "s/\(${END}_${HOUR}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${end_hour}, ${end_hour}, ${end_hour}/" \
   | sed "s/\(${END}_${MINUTE}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${end_minute}, ${end_minute}, ${end_minute}/" \
   | sed "s/\(${END}_${SECOND}\)${EQUAL}[[:digit:]]\{2\}.*/\1 = ${end_second}, ${end_second}, ${end_second}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update the quilting settings to the parameters set in the workflow
cat namelist.input | sed "s/\(${NIO}_${TASK}[Ss]_${PER}_${GROUP}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_TASKS_PER_GROUP}/" \
                      | sed "s/\(${NIO}_${GROUP}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${NIO_GROUPS}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

# Update data interval in namelist
(( data_interval_sec = DATA_INTERVAL * 3600 ))
cat namelist.input | sed "s/\(${INTERVAL}_${SECOND}[Ss]\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${data_interval_sec}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

if [[ ${IF_SST_UPDATE} = ${YES} ]]; then
  # update the auxinput4_interval to the DATA_INTERVAL (propagates to three domains)
  (( auxinput4_minutes = DATA_INTERVAL * 60 ))
  cat namelist.input | sed "s/\(${AUXINPUT}4_${INTERVAL}\)${EQUAL}[[:digit:]]\{1,\}.*/\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}/" \
     > namelist.input.new
  mv namelist.input.new namelist.input
fi

# Update the max_dom in namelist
cat namelist.input | sed "s/\(max_dom\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${MAX_WRF_DOM}/" \
   > namelist.input.new
mv namelist.input.new namelist.input

#####################################################
# Run WRF
#####################################################
# Print run parameters
echo
echo "WRF_ROOT       = ${WRF_ROOT}"
echo "STATIC_DATA    = ${STATIC_DATA}"
echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
echo
echo "FCST LENGTH    = ${FCST_LENGTH}"
echo "FCST INTERVAL  = ${FCST_INTERVAL}"
echo "MAX_WRF_DOM    = ${MAX_WRF_DOM}"
echo "MAX_GSI_DOM    = ${MAX_GSI_DOM}"
echo "IF_CYCLING     = ${IF_CYCLING}"
echo "IF_SST_UPDATE  = ${IF_SST_UPDATE}"
echo
echo "START TIME     = "`date +"%Y/%m/%d %H:%M:%S" -d "${start_time}"`
echo "END TIME       = "`date +"%Y/%m/%d %H:%M:%S" -d "${end_time}"`
echo
now=`date +%Y%m%d%H%M%S`
echo "wrf started at ${now}"

${MPIRUN} ${wrf_exe}

#####################################################
# Run time error check
#####################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.wrf.${now}
mkdir ${rsldir}
mv rsl.out.* ${rsldir}
mv rsl.error.* ${rsldir}
cp namelist.* ${rsldir}

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${wrf_exe} exited with status ${error}"
  exit ${error}
fi

# Look for successful completion messages in rsl files, adjusted for quilting processes
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE WRF/' | wc -l`
(( ntotal=(WRF_PROC - NIO_GROUPS * NIO_TASKS_PER_GROUP ) * 2 ))
echo "Found ${nsuccess} of ${ntotal} completion messages"
if [ ${nsuccess} -ne ${ntotal} ]; then
  echo "ERROR: ${wrf_exe} did not complet successfully, missing completion messages in RLS files"
fi

if [[ ${IF_CYCLING} = ${YES} ]]; then
  # ensure that the cycle_io/date/bkg directory exists for starting next cycle
  cycle_intv=`date +%H -d "${CYCLE_INTV}"`
  datestr=`date +%Y%m%d%H -d "${start_time} ${cycle_intv} hours"`
  new_bkg=${datestr}/bkg/ens_${ens_n}
  mkdir -p ../../${new_bkg}
else
  current_bkg=${INPUT_DATAROOT}/bkg/ens_${ens_n}
  mkdir -p ${current_bkg}
fi

# Check for all wrfout files on FCST_INTERVAL and link files to the appropriate bkg directory
dmn=1
while [ ${dmn} -le ${MAX_WRF_DOM} ]; do
  fcst=0
  while [ ${fcst} -le ${FCST_LENGTH} ]; do
    datestr=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${fcst} hours"`
    if [ ! -s "wrfout_d0${dmn}_${datestr}" ]; then
      echo "WRF failed to complete.  wrfout_d0${dmn}_${datestr} is missing or empty!"
      exit 1
    else
      if [[ ${IF_CYCLING} = ${YES} ]]; then
        ln -sfr wrfout_d0${dmn}_${datestr} ../../${new_bkg}/
      else
        ln -sfr wrfout_d0${dmn}_${datestr} ${current_bkg}/
      fi
    fi
    (( fcst += FCST_INTERVAL ))
  done
  (( dmn += 1 ))
done

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    rm -f `${basename} ${file}`
done

echo "wrf.ksh completed successfully at `date`"

exit 0
