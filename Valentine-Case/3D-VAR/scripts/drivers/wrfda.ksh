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
#                 'No' if updating lateral boundary conditions
# MAX_DOM       = Max number of domains to update lower boundary conditions 
#                 (lateral boundary conditions for nested domains are always defined by the parent)
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
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories obs, bkg, gfsens, wpsprd, realprd, wrfprd, gsiprd
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

if [ ! -d ${STATIC_DATA} ]; then
  ${ECHO} "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! -d ${INPUT_DATAROOT} ]; then
  ${ECHO} "ERROR: \$INPUT_DATAROOT directory ${INPUT_DATAROOT} does not exist"
  exit 1
fi

#####################################################
# Begin pre-WRFDA setup
#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# WORK_ROOT      = Working directory where da_update_bc.exe runs and outputs updated files
# GSI_DIR        = Working directory where GSI runs and outputs analysis files for the current cycle
# REAL_DIR       = Working directory real.exe runs and outputs IC and BC files for the current cycle
# BKG_DIR        = Working directory with forecast data from WRF linked for the current cycle
# UPDATE_BC_EXE  = Path and name of the update executable
#
#####################################################

WORK_ROOT=${INPUT_DATAROOT}/wrfdaprd
GSI_DIR=${INPUT_DATAROOT}/gsiprd
REAL_DIR=${INPUT_DATAROOT}/realprd
BKG_DIR=${INPUT_DATAROOT}/bkg
UPDATE_BC_EXE=${WRFDA_ROOT}/var/da/da_update_bc.exe

if [[ ${IF_LOWER} = ${NO} ]]; then
  if [ ! -d ${GSI_DIR} ]; then
    ${ECHO} "ERROR: \$GSI_DIR directory ${GSI_DIR} does not exist"
    exit 1
  fi
fi

if [ ! -d ${REAL_DIR} ]; then
  ${ECHO} "ERROR: \$REAL_DIR directory ${REAL_DIR} does not exist"
  exit 1
fi

if [[ ${IF_LOWER} = ${YES} ]]; then
  if [ ! -d ${BKG_DIR} ]; then
    ${ECHO} "ERROR: \$BKG_DIR directory ${INPUT_DATAROOT} does not exist"
    exit 1
  fi
fi

if [ ! -x ${UPDATE_BC_EXE} ]; then
  ${ECHO} "ERROR: ${UPDATE_BC_EXE} does not exist, or is not executable"
  exit 1
fi

# create working directory and cd into it
${MKDIR} -p ${WORK_ROOT}
cd ${WORK_ROOT}

# Remove IC/BC in the directory if old data present
${RM} -f wrfout_*
${RM} -f wrfinput_d0*
${RM} -f wrfbdy_d01

# define domain variable to iterate on in lower boundary, fixed in lateral
dmn=1

if [[ ${IF_LOWER} = ${YES} ]]; then 
  # Check to make sure the input files are available and copy them
  while [ ${dmn} -le ${MAX_DOM} ]; do
    wrfout=wrfout_d0${dmn}_${DATE_STR}
    wrfinput=wrfinput_d0${dmn}

    if [ ! -r "${BKG_DIR}/${wrfout}" ]; then
      echo "ERROR: Input file '${wrfout}' is missing"
      exit 1
    else
      ${CP} ${BKG_DIR}/${wrfout} ./
    fi

    if [ ! -r "${REAL_DIR}/${wrfnput}" ]; then
      echo "ERROR: Input file '${wrfinput}' is missing"
      exit 1
    else
      ${CP} ${REAL_DIR}/${wrfinput} ./
    fi

    #####################################################
    #  Build da_update_bc namelist
    #####################################################
    # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
    ${CP} ${STATIC_DATA}/namelists/parame.in ./

    # Update the namelist for the domain id 
    ${CAT} parame.in | ${SED} "s/\(${da}_${file}\)${equal}.*/\1 = '\.\/${wrfout}'/" \
       > parame.in.new
    ${MV} parame.in.new parame.in

    ${CAT} parame.in | ${SED} "s/\(${wrf}_${input}\)${equal}.*/\1 = '\.\/${wrfinput}'/" \
       > parame.in.new
    ${MV} parame.in.new parame.in

    ${CAT} parame.in | ${SED} "s/\(${domain}_${id}\)${equal}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
       > parame.in.new
    ${MV} parame.in.new parame.in

    # Update the namelist for lower boundary update 
    ${CAT} parame.in | ${SED} "s/\(${update}_${low}_${bdy}\)${equal}.*/\1 = \.true\./" \
       > parame.in.new
    ${MV} parame.in.new parame.in

    ${CAT} parame.in | ${SED} "s/\(${update}_${lateral}_${bdy}\)${equal}.*/\1 = \.false\./" \
       > parame.in.new
    ${MV} parame.in.new parame.in

    #####################################################
    # Run UPDATE_BC_EXE
    #####################################################
    # Print run parameters
    ${ECHO}
    ${ECHO} "WRFDA_ROOT     = ${WRFDA_ROOT}"
    ${ECHO} "STATIC_DATA    = ${STATIC_DATA}"
    ${ECHO} "INPUT_DATAROOT = ${INPUT_DATAROOT}"
    ${ECHO}
    ${ECHO} "IF_LOWER       = ${IF_LOWER}"
    ${ECHO} "DOMAIN         = ${dmn}"
    ${ECHO}
    now=`${DATE} +%Y%m%d%H%M%S`
    ${ECHO} "da_update_bc.exe started at ${now}"
    ${UPDATE_BC_EXE}

    #####################################################
    # Run time error check
    #####################################################
    error=$?
    
    if [ ${error} -ne 0 ]; then
      ${ECHO} "ERROR: ${UNGRIB} exited with status: ${error}"
      exit ${error}
    fi

    # save the files where they can be accessed for GSI analysis
    lower_bdy_data=${WORK_ROOT}/lower_bdy_update
    ${MKDIR} -p ${lower_bdy_data}
    ${MV} ${wrfout} ${lower_bdy_data}/${wrfout}
    ${MV} ${wrfinput} ${lower_bdy_data}/${wrfinput}
    ${MV} parame.in ${lower_bdy_data}/parame.in_d0${dmn} 

    # move forward through domains
    (( dmn += 1 ))
  done

else
  wrfanl=${GSI_DIR}/d01/wrfanl.d01_${ANAL_TIME}
  wrfbdy=${REAL_DIR}/wrfbdy_d01
  wrfvar_outname=wrfvar_output
  wrfbdy_name=wrfbdy_d01

  if [ ! -r "${wrfanl}" ]; then
    echo "ERROR: Input file '${wrfanl}' is missing"
    exit 1
  else
    ${CP} ${wrfanl} ${wrfvar_outname}
  fi

  if [ ! -r "${wrfbdy}" ]; then
    echo "ERROR: Input file '${wrfbdy}' is missing"
    exit 1
  else
    ${CP} ${wrfbdy} ${wrfbdy_name} 
  fi

  #####################################################
  #  Build da_update_bc namelist
  #####################################################
  # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
  ${CP} ${STATIC_DATA}/namelists/parame.in ./

  # Update the namelist for the domain id 
  ${CAT} parame.in | ${SED} "s/\(${da}_${file}\)${equal}.*/\1 = '\.\/${wrfvar_outname}'/" \
     > parame.in.new
  ${MV} parame.in.new parame.in

  ${CAT} parame.in | ${SED} "s/\(${domain}_${id}\)${equal}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
     > parame.in.new
  ${MV} parame.in.new parame.in

  # Update the namelist for lower boundary update 
  ${CAT} parame.in | ${SED} "s/\(${wrf}_${bdy}_${file}\)${equal}.*/\1 = '\.\/${wrfbdy_name}'/" \
     > parame.in.new
  ${MV} parame.in.new parame.in

  ${CAT} parame.in | ${SED} "s/\(${update}_${low}_${bdy}\)${equal}.*/\1 = \.false\./" \
     > parame.in.new
  ${MV} parame.in.new parame.in

  ${CAT} parame.in | ${SED} "s/\(${update}_${lateral}_${bdy}\)${equal}.*/\1 = \.true\./" \
     > parame.in.new
  ${MV} parame.in.new parame.in

  #####################################################
  # Run UPDATE_BC_EXE
  #####################################################
  # Print run parameters
  ${ECHO}
  ${ECHO} "WRFDA_ROOT     = ${WRFDA_ROOT}"
  ${ECHO} "STATIC_DATA    = ${STATIC_DATA}"
  ${ECHO} "INPUT_DATAROOT = ${INPUT_DATAROOT}"
  ${ECHO}
  ${ECHO} "IF_LOWER       = ${IF_LOWER}"
  ${ECHO} "DOMAIN         = ${dmn}"
  ${ECHO}
  now=`${DATE} +%Y%m%d%H%M%S`
  ${ECHO} "da_update_bc.exe started at ${now}"
  ${UPDATE_BC_EXE}

  #####################################################
  # Run time error check
  #####################################################
  error=$?
  
  if [ ${error} -ne 0 ]; then
    ${ECHO} "ERROR: ${UNGRIB} exited with status: ${error}"
    exit ${error}
  fi

  # save the files where they can be accessed for new WRF forecast
  lateral_bdy_data=${WORK_ROOT}/lateral_bdy_update
  ${MKDIR} -p ${lateral_bdy_data}
  ${MV} wrfvar_output ${lateral_bdy_data}/
  ${MV} wrfbdy_d01 ${lateral_bdy_data}/
  ${MV} parame.in ${lateral_bdy_data}/parame.in_d0${dmn} 
  ${MV} fort.* ${lateral_bdy_data}/

fi

${ECHO} "wrfda.ksh completed successfully at `${DATE}`"
