#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the Rocoto workflow
# ungrib driver script of Christopher Harrop Licensed for modification /
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
#     Script Name: ungrib.ksh
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
# Make checks for ungrib settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID         = Ensemble ID index, 00 for control, i > 0 for perturbation
# STRT_TIME     = Simulation start time in YYMMDDHH
# BKG_STRT_TIME = Background data simulation start time in YYMMDDHH
# IF_DYN_LEN    = "Yes" or "No" switch to compute forecast length dynamically 
# FCST_HRS      = Total length of WRF forecast simulation in HH, IF_DYN_LEN=No
# EXP_VRF       = Verfication time for calculating forecast hours, IF_DYN_LEN=Yes
# BKG_INT       = Interval of background input data in HH
# BKG_DATA      = String case variable for supported inputs: GFS, GEFS currently
# IF_ECMWF_ML   = "Yes" or "No" switch to compute ECMWF coefficients for
#                 initializing with model level data, case insensitive
#
##################################################################################

if [ ! ${MEMID} ]; then
  echo "ERROR: ensemble index \${MEMID} is not defined."
  exit 1
else
  # ensure padding to two digits is included in memid variable
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
  echo "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive)"
  exit 1
fi

# define the end time based on forecast length control flow above
end_time=`date -d "${strt_time} ${fcst_len} hours"`

if [ ${#BKG_STRT_TIME} -ne 10 ]; then
  echo "ERROR: \${BKG_STRT_TIME}, '${BKG_STRT_TIME}', is not in 'YYYYMMDDHH' format." 
  exit 1
else
  # define BKG_STRT_TIME date string wihtout HH
  bkg_strt_date=${BKG_STRT_TIME:0:8}
  bkg_strt_hh=${BKG_STRT_TIME:8:2}
fi

if [ ! ${BKG_INT} ]; then
  echo "ERROR: \${BKG_INT} is not defined."
  exit 1
elif [ ${BKG_INT} -le 0 ]; then
  echo "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs."
  exit 1
fi

if [ ${BKG_DATA} = GFS ]; then
  # GFS has single control trajectory
  fnames="gfs.0p25.${BKG_STRT_TIME}.f*"

  # compute the number of input files to ungrib (incld. first/last times)
  n_files=$(( ${fcst_len} / ${BKG_DATA_INT} + 1 ))

elif [ ${BKG_DATA} = GEFS ]; then
  if [ ${memid} = 00 ]; then
    # 00 perturbation is the control forecast
    fnames="gec${memid}.t${bkg_strt_hh}z.pgrb*"
  else
    # all other are control forecast perturbations
    fnames="gep${memid}.t${bkg_strt_hh}z.pgrb*"
  fi
  # GEFS comes in a/b files for each valid time
  n_files=$(( 2 * ${fcst_len} / ${BKG_DATA_INT} + 1 ))

else
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs."
  echo ${msg}
  exit 1
fi

if [[ ${IF_ECMWF_ML} != ${YES} && ${IF_ECMWF_ML} != ${NO} ]]; then
  echo "ERROR: \${IF_ECMWF_ML} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

##################################################################################
# Define ungrib workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WPS_ROOT  = Root directory of clean WPS build
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# CYCLE_HME = Cycle YYYYMMDDHH named directory for cycling data containing
#             bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# DATA_ROOT = Directory for all forcing data files, including grib files,
#             obs files, etc.
#
##################################################################################

if [ ! ${WPS_ROOT} ]; then
  echo "ERROR: \${WPS_ROOT} is not defined."
  exit 1
elif [ ! -d ${WPS_ROOT} ]; then
  echo "ERROR: WPS_ROOT directory '${WPS_ROOT}' does not exist."
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
  # NOTE: some ungrib jobs start cycling and this directory does not always exist
  echo "ERROR: \${CYCLE_HME}, '${CYCLE_HME}', is not in 'YYYYMMDDHH' format." 
  exit 1
fi

if [ ! ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} is not defined."
  exit 1
elif [ ! -d ${DATA_ROOT} ]; then
  echo "ERROR: \${DATA_ROOT} directory '${DATA_ROOT}' does not exist."
  exit 1
fi

##################################################################################
# Begin pre-unrib setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root     = Working directory where ungrib_exe runs and outputs
# wps_dat_files = All file contents of clean WPS directory
#                 namelists and input data will be linked from other sources
# ungrib_exe    = Path and name of working executable
# vtable        = Path and name of variable table
# grib_dataroot = Path to the raw data to be processed
#
##################################################################################

work_root=${CYCLE_HME}/wpsprd/ens_${memid}
mkdir -p ${work_root}
cmd="cd ${work_root}"
echo ${cmd}; eval ${cmd}

wps_dat_files=(${WPS_ROOT}/*)
ungrib_exe=${WPS_ROOT}/ungrib.exe

if [ ! -x ${ungrib_exe} ]; then
  echo "ERROR: ungrib.exe '${ungrib_exe}' does not exist, or is not executable."
  exit 1
fi

# Make links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  echo ${cmd}; eval ${cmd}
done

# Remove any previous Vtables
cmd="rm -f Vtable"
echo ${cmd}; eval ${cmd}

# Check to make sure the variable table is available
vtable=${EXP_CNFG}/variable_tables/Vtable.${BKG_DATA}
if [ ! -r ${vtable} ]; then
  msg="ERROR: Vtable at location '${vtable}' is not readable or does not exist."
  echo ${msg}
  exit 1
else
  cmd="ln -sf ${vtable} Vtable"
  echo ${cmd}; eval ${cmd}
fi

# check to make sure the grib_dataroot exists and is non-empty
grib_dataroot=${DATA_ROOT}/gribbed/${BKG_DATA}
if [! -d ${grib_dataroot} ]; then
  echo "ERROR: the directory ${grib_dataroot} does not exist."
  exit 1
elif [ `ls -l ${grib_dataroot} | wc -l` -le ${n_files} ]; then
  msg="ERROR: grib data directory '${grib_dataroot}' is missing bkg input files."
  echo ${msg}
  exit 1
else
  # link the grib data to the working directory
  cmd="./link_grib.csh ${grib_dataroot}/${bkg_strt_date}/${fnames}"
  echo ${cmd}; eval ${cmd}
fi

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

##################################################################################
# Run ungrib 
##################################################################################
# Print run parameters
echo
echo "EXP_CNFG      = ${EXP_CNFG}"
echo "MEMID         = ${MEMID}"
echo "CYCLE_HME     = ${CYCLE_HME}"
echo "STRT_TIME     = ${strt_dt}"
echo "END_TIME      = ${end_dt}"
echo "BKG_DATA      = ${BKG_DATA}"
echo "BKG_STRT_TIME = ${BKG_STRT_TIME}"
echo "BKG_INT       = ${BKG_INT}"
echo
now=`date +%Y-%m-%d_%H_%M_%S`
echo "ungrib started at ${now}."
cmd="./ungrib.exe"
echo ${cmd}; eval ${cmd}

##################################################################################
# Run time error check
##################################################################################
error=$?

# save ungrib logs
log_dir=ungrib_log.${now}
mkdir ${log_dir}
cmd="mv ungrib.log ${log_dir}"
echo ${cmd}; eval ${cmd}

cmd="mv namelist.wps ${log_dir}"
echo ${cmd}; eval ${cmd}

# check run error code
if [ ${error} -ne 0 ]; then
  echo "ERROR: ${ungrib_exe} exited with status ${error}."
  exit ${error}
fi

# verify all file outputs
for fcst in `seq -f "%03g" 0 ${BKG_INT}} ${fcst_len}`; do
  filename="FILE:`date +%Y-%m-%d_%H -d "${strt_time} ${fcst} hours"`"
  if [ ! -s ${filename} ]; then
    echo "ERROR: ${filename} is missing."
    exit 1
  fi
done

# If ungribbing ECMWF model level data, calculate additional coefficients
# NOTE: namelist.wps should account for the "PRES" file prefixes in fg_names
if [ ${IF_ECMWF_ML} = ${YES} ]; then
  cmd="ln -sf ${EXP_CNFG}/variable_tables/ecmwf_coeffs ."
  echo ${cmd}; eval ${cmd}
  cmd="./util/calc_ecmwf_p.exe"
  echo ${cmd}; eval ${cmd}

  # Check to see if we've got all the files we're expecting
  for fcst in `seq -f "%03g" 0 ${BKG_INT} ${fcst_len}`; do
    filename=PRES:`date +%Y-%m-%d_%H -d "${strt_time} ${fcst} hours"`
    if [ ! -s ${filename} ]; then
      echo "ERROR: ${filename} is missing."
      exit 1
    fi
  done
fi

# Remove links to the WPS DAT files
for file in ${wps_dat_files[@]}; do
    cmd="rm -f `basename ${file}`"
    echo ${cmd}; eval ${cmd}
done

# remove links to grib files
cmd="rm -f GRIBFILE.*"
echo ${cmd}; eval ${cmd}

echo "ungrib.sh completed successfully at `date`."

##################################################################################
# end

exit 0
