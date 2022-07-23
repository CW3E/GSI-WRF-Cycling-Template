#!/bin/ksh
#####################################################
# Description
#####################################################
# This driver script utilizes WRFDA to update lower and lateral boundary
# conditions in conjunction with GSI updating the initial conditions.
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with GSI for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the standard gsi.ksh
# driver script provided in the GSI tutorials.
#
# One should write machine specific options for the WRFDA environment
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
# Make checks for WRFDA settings
#####################################################
# Options below are defined in cycling.xml
#
# ANAL_TIME     = Analysis time YYYYMMDDHH
# IF_LOWER      = 'Yes' if updating lower boundary conditions 
#                 'No' if updating lateral boundary conditions,
# MAX_DOM       = Max number of domains to update lower boundary conditions 
#
# Below variables are derived by cycling.xml variables for convenience
#
# DATE_STR      = Defined by the ANAL_TIME variable, to be used as path
#                 name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
#####################################################

if [ ! "${ANAL_TIME}" ]; then
  echo "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

# Define directory path name variable DATE_STR=YYMMDDHH from ANAL_TIME
HH=`echo $ANAL_TIME | cut -c9-10`
ANAL_DATE=`echo $ANAL_TIME | cut -c1-8`
DATE_STR=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${ANAL_DATE} $HH hours"`

if [ -z "${DATE_STR}"]; then
  echo "ERROR: \$DATE_STR is not defined correctly, check format of \$ANAL_DATE!"
  exit 1
fi

if [ ! ${MAX_DOM} ]; then
  ${ECHO} "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

if [[ ${IF_LOWER} != ${YES} && ${IF_LOWER} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_LOWER must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

#####################################################
# Define REAL workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# WRFDA_ROOT     = Root directory of a WRFDA build 
# WRFDA_PROC     = The total number of processes to run da_update_bc.exe with MPI
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories obs, bkg, gfsens, wpsprd, realprd, wrfprd, gsiprd
# MPIRUN         = MPI Command to execute REAL
#
#####################################################

if [ ! "${WRFDA_ROOT}" ]; then
  ${ECHO} "ERROR: \$WRFDA_ROOT is not defined"
  exit 1
fi

if [ ! -d "${WRFDA_ROOT}" ]; then
  ${ECHO} "ERROR: WRFDA_ROOT directory ${WRFDA_ROOT} does not exist"
  exit 1
fi

if [ ! "${WRFDA_PROC}" ]; then
  ${ECHO} "ERROR: \$WRFDA_PROC is not defined"
  exit 1
fi

if [ -z "${WRFDA_PROC}" ]; then
  ${ECHO} "ERROR: The variable \$WRFDA_PROC must be set to the number of processors to run real"
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
# Begin pre-WRFDA setup
#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# WORK_ROOT      = Working directory where REAL runs and outputs background files
# GSI_DIR        =
# REAL_DIR       =
# BKG_DIR        =
# UPDATE_BC_EXE  = Path and name of working executable
#
#####################################################

WORK_ROOT=${INPUT_DATAROOT}/wrfdaprd
GSI_DIR=${INPUT_DATAROOT}/gsiprd
REAL_DIR=${INPUT_DATAROOT}/realprd
BKG_DIR=${INPUT_DATAROOT}/wrfprd



UPDATE_BC_EXE=${WRFDA_ROOT}/var/da/da_update_bc.exe

if [ ! -x ${UPDATE_BC_EXE} ]; then
  ${ECHO} "ERROR: ${UPDATE_BC_EXE} does not exist, or is not executable"
  exit 1
fi

${MKDIR} -p ${WORK_ROOT}
cd ${WORK_ROOT}

${LN} -sf ${UPDATE_BC_EXE} ./

# Remove IC/BC in the directory if old data present
${RM} -f wrfinput_d0*
${RM} -f wrfbdy_d01

if [[ ${IF_LOWER} = ${YES} ]]; then 
  # Check to make sure the input files are available and copy them
  dmn=1
  while [ ${dmn} -le ${MAX_DOM} ]; do
    wrfout=${WRF_DIR}/wrfout_d0${dmn}_${DATE_STR}
    wrfinput=${REAL_DIR}/wrfinput_d0${dmn}

    if [ ! -r "${wrfout}" ]; then
      echo "ERROR: Input file '${wrfout}' is missing"
      exit 1
    else
      ${CP} ${wrfout} ./wrfout
    fi

    if [ ! -r "${wrfnput}" ]; then
      echo "ERROR: Input file '${wrfinput}' is missing"
      exit 1
    else
      ${CP} ${wrfinput} ./wrfinput
    fi
    # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
    ${CP} ${STATIC_DATA}/namelists/parame.in .

    # UPDATE THE NAMELIST for the lower boundary update settings 


    # run the boundary update

    # save the files where they can be accessed for GSI analysis

    (( dmn += 1 ))
  done
else
  wrfanl=${GSI_DIR}/d01/wrfanl.d01_${ANAL_TIME}
  wrfbdy=${REAL_DIR}/wrfbdy_d01

  if [ ! -r "${wrfanl}" ]; then
    echo "ERROR: Input file '${wrfanl}' is missing"
    exit 1
  else
    ${CP} ${wrfanl} ./wrfanl
  fi

  if [ ! -r "${wrfbdy}" ]; then
    echo "ERROR: Input file '${wrfbdy}' is missing"
    exit 1
  else
    ${CP} ${wrfbdy} ./wrfbdy
  fi
  # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
  ${CP} ${STATIC_DATA}/namelists/parame.in .

  # UPDATE the namelist for the lateral boundary setting

  # run the boundary update

  # save the files where they can be accessed for new WRF forecast
fi

#####################################################
#  Build da_update_bc namelist
#####################################################


# Create patterns for updating the wrf namelist (case independent)

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

# Update interval in namelist
(( data_interval_sec = DATA_INTERVAL * 3600 ))
${CAT} namelist.input | ${SED} "s/\(${interval}_${second}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${data_interval_sec}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

# Update the max_dom in namelist
${CAT} namelist.input | ${SED} "s/\(max_dom\)${equal}[[:digit:]]\{1,\}/\1 = ${MAX_DOM}/" \
   > namelist.input.new
${MV} namelist.input.new namelist.input

#####################################################
# Run REAL
#####################################################
# Print run parameters
${ECHO}
${ECHO} "WRFDA_ROOT       = ${WRFDA_ROOT}"
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
${ECHO} "real started at ${now}"
${MPIRUN} ${UPDATE_BC_EXE}

#####################################################
# Run time error check
#####################################################
error=$?

if [ ${error} -ne 0 ]; then
  ${MPIRUN} ${EXIT_CALL} ${error}
  exit
else
  ${MPIRUN} ${EXIT_CALL} 1
  exit
fi

${ECHO} "real_wps.ksh completed successfully at `${DATE}`"
