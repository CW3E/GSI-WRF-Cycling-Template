#!/bin/ksh
#####################################################
# Description
#####################################################
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
# in a WPS_constants.ksh script to be sourced in the below.  Variables
# aliases in this script are based on conventions defined in the 
# companion WPS_constants.ksh with this driver.
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
#      Purpose: This is a complete rewrite of the metgrid portion of the 
#               wrfprep.pl script that is distributed with the WRF Standard 
#               Initialization.  This script may be run on the command line, or 
#               it may be submitted directly to a batch queueing system.
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

# assuming data preprocessed with metgrid in WPS
metgrid_prefix="met_em"

# assuming using serial netcdf -- this is not currently configured for parallel metgrid
metgrid_suffix="nc"

#####################################################

if [ ! -x "${CONSTANT}" ]; then
  ${ECHO} "ERROR: ${CONSTANT} does not exist or is not executable"
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

#####################################################
# Make checks for METGRID settings
#####################################################
# Options below are defined in cycling.xml
#
# FCST_LENGTH   = Total length of WRF forecast simulation in HH 
# DATA_INTERVAL = Interval of input data in HH
# START_TIME    = Simulation start time in YYMMDDHH
# MAX_DOM       = Max number of domains to use in namelist settings
#
#####################################################

if [ ! "${FCST_LENGTH}" ]; then
  ${ECHO} "ERROR: \$FCST_LENGTH is not defined"
  exit 1
fi

if [ ! "${DATA_INTERVAL}" ]; then
  ${ECHO} "ERROR: \$DATA_INTERVAL is not defined"
  exit 1
fi

if [ ! "${START_TIME}" ]; then
  ${ECHO} "ERROR: \$START_TIME is not defined!"
  exit 1
fi

# Convert START_TIME from 'YYYYMMDDHH' format to Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `${ECHO} "${START_TIME}" | ${AWK} '/^[[:digit:]]{10}$/'` ]; then
  START_TIME=`${ECHO} "${START_TIME}" | ${SED} 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  ${ECHO} "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi
START_TIME=`${DATE} -d "${START_TIME}"`
END_TIME=`${DATE} -d "${START_TIME} ${FCST_LENGTH} hours"`

if [ ! ${MAX_DOM} ]; then
  ${ECHO} "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

#####################################################
# Define METGRID workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# WPS_ROOT       = Root directory of a "clean" WPS build
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories obs, bkg, gfsens, wpsprd, realprd, wrfprd, gsiprd 
# MPIRUN         = MPI Command to execute METGRID
#
#####################################################

if [ ! "${WPS_ROOT}" ]; then
  ${ECHO} "ERROR: \$WPS_ROOT is not defined"
  exit 1
fi

if [ ! -d "${WPS_ROOT}" ]; then
  ${ECHO} "ERROR: WPS_ROOT directory ${WPS_ROOT} does not exist"
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
# Begin pre-METGRID setup
#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# WORK_ROOT      = Working directory where METGRID_EXE runs and outputs
# WPS_DAT_FILES  = All file contents of clean WPS directory 
#                  namelists and input data will be linked from other sources
# METGRID_EXE    = Path and name of working executable
# 
#####################################################

WORK_ROOT=${INPUT_DATAROOT}/wpsprd
set -A WPS_DAT_FILES ${WPS_ROOT}/*
METGRID_EXE=${WPS_ROOT}/metgrid.exe

if [ ! -x ${METGRID_EXE} ]; then
  ${ECHO} "ERROR: ${METGRID_EXE} does not exist, or is not executable"
  exit 1
fi

${MKDIR} -p ${WORK_ROOT}
cd ${WORK_ROOT}

# Make links to the WPS DAT files
for file in ${WPS_DAT_FILES[@]}; do
  ${ECHO} "${LN} -sf ${file}"
  ${LN} -sf ${file} ./
done

# Remove any previous geogrid static files
${RM} -f geo_em.d0*

# Check to make sure the geogrid input files (e.g. geo_em.d01.nc)
# are available and make links to them
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  geoinput_name=${STATIC_DATA}/geogrid/geo_em.d0${dmn}.nc
  if [ ! -r "${geoinput_name}" ]; then
    echo "ERROR: Input file '${geoinput_name}' is missing"
    exit 1
  fi
  ${LN} -sf ${geoinput_name} ./ 
  (( dmn = dmn + 1 ))
done

#####################################################
#  Build WPS namelist
#####################################################
# Copy the wrf namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
${CP} ${STATIC_DATA}/namelists/namelist.wps .

# Create patterns for updating the wps namelist (case independent)
equal=[[:blank:]]*=[[:blank:]]*
start=[Ss][Tt][Aa][Rr][Tt]
end=[Ee][Nn][Dd]
date=[Dd][Aa][Tt][Ee]
interval=[Ii][Nn][Tt][Ee][Rr][Vv][Aa][Ll]
seconds=[Ss][Ee][Cc][Oo][Nn][Dd][Ss]
prefix=[Pp][Rr][Ee][Ff][Ii][Xx]
fg_name=[Ff][Gg][_][Nn][Aa][Mm][Ee]
constants_name=[Cc][Oo][Nn][Ss][Tt][Aa][Nn][Tt][Ss][_][Nn][Aa][Mm][Ee]
yyyymmdd_hhmmss='[[:digit:]]\{4\}-[[:digit:]]\{2\}-[[:digit:]]\{2\}_[[:digit:]]\{2\}:[[:digit:]]\{2\}:[[:digit:]]\{2\}'

# define start / end time patterns for namelist.wps
start_yyyymmdd_hhmmss=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${START_TIME}"`
end_yyyymmdd_hhmmss=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${END_TIME}"`

# Update the start and end date in namelist (propagates settings to three domains) 
${CAT} namelist.wps | ${SED} "s/\(${start}_${date}\)${equal}'${yyyymmdd_hhmmss}'.*/\1 = '${start_yyyymmdd_hhmmss}','${start_yyyymmdd_hhmmss}','${start_yyyymmdd_hhmmss}'/" \
                    | ${SED} "s/\(${end}_${date}\)${equal}'${yyyymmdd_hhmmss}'.*/\1 = '${end_yyyymmdd_hhmmss}','${end_yyyymmdd_hhmmss}','${end_yyyymmdd_hhmmss}'/" \
                      > namelist.wps.new
${MV} namelist.wps.new namelist.wps

# Update interval in namelist
(( data_interval_sec = DATA_INTERVAL * 3600 ))
${CAT} namelist.wps | ${SED} "s/\(${interval}_${seconds}\)${equal}[[:digit:]]\{1,\}/\1 = ${data_interval_sec}/" \
                      > namelist.wps.new 
${MV} namelist.wps.new namelist.wps

# Remove pre-existing metgrid files
${RM} -f ${metgrid_prefix}.d0*.*.${metgrid_suffix}

#####################################################
# Run METGRID
#####################################################
# Print run parameters
${ECHO}
${ECHO} "metgrid.ksh started at `${DATE}`"
${ECHO}
${ECHO} "WPS_ROOT       = ${WPS_ROOT}"
${ECHO} "STATIC_DATA    = ${STATIC_DATA}"
${ECHO} "INPUT_DATAROOT = ${INPUT_DATAROOT}"
${ECHO}
${ECHO} "FCST LENGTH    = ${FCST_LENGTH}"
${ECHO} "DATA INTERVAL  = ${DATA_INTERVAL}"
${ECHO} "MAX_DOM        = ${MAX_DOM}"
${ECHO}
${ECHO} "START TIME     = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${START_TIME}"`
${ECHO} "END TIME       = "`${DATE} +"%Y/%m/%d %H:%M:%S" -d "${END_TIME}"`
${ECHO}

now=`${DATE} +%Y%m%d%H%M%S`
${ECHO} "Running METGRID at ${now}"
${MPIRUN} ${METGRID_EXE}

#####################################################
# Run time error check
#####################################################
error=$?

# save metgrid logs
log_dir= metgrid_log.${now} 
${MKDIR} ${log_dir}
${MV} metgrid.log* ${log_dir}

if [ ${error} -ne 0 ]; then
  ${ECHO} "ERROR: ${METGRID} exited with status: ${error}"
  ${MPIRUN} ${EXIT_CALL} ${error}
  exit
else

# Check to see if metgrid outputs are generated 
fcst=0
dmn=1
while [ ${dmn} -le ${MAX_DOM} ]; do
  while [ ${fcst} -le ${FCST_LENGTH} ]; do
    time_str=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${START_TIME} ${fcst} hours"`
    if [ ! -e "${metgrid_prefix}.d0${dmn}.${time_str}.${metgrid_suffix}" ]; then
      ${ECHO} "${METGRID} for d0${dmn} failed to complete"
      ${MPIRUN} ${EXIT_CALL} 1
      exit
    fi
    (( fcst = fcst + DATA_INTERVAL ))
  done
  (( dmn = dmn + 1 ))
done

# Remove links to the WPS DAT files
for file in ${WPS_DAT_FILES[@]}; do
    ${RM} -f `${BASENAME} ${file}`
done

${ECHO} "metgrid.ksh completed successfully at `${DATE}`"

fi
