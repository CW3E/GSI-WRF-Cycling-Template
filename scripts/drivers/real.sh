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
# in a WRF_constants.sh script to be sourced in the below.
#
##################################################################################
# License Statement:
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
#
# In addition to the License terms above, this software is
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
  printf "ERROR: constants file\n ${CNST}\n does not exist or is not executable.\n"
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  printf "${cmd}\n"; eval "${cmd}"
fi

##################################################################################
# Make checks for real settings
##################################################################################
# Options below are defined in workflow variables
#
# MEMID        = Ensemble ID index, 00 for control, i > 00 for perturbation
# STRT_DT      = Simulation start time in YYMMDDHH
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
  printf "ERROR: \${MEMID} is not defined.\n"
  exit 1
else
  # ensure padding to two digits is included
  memid=`printf %02d $(( 10#${MEMID} ))`
fi

if [ ${#STRT_DT} -ne 10 ]; then
  printf "ERROR: \${STRT_DT}, ${STRT_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert STRT_DT from 'YYYYMMDDHH' format to strt_dt Unix date format
  strt_dt="${STRT_DT:0:8} ${STRT_DT:8:2}"
  strt_dt=`date -d "${strt_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Generating fixed length forecast forcing data.\n"
  if [ ! ${FCST_HRS} ]; then
    printf "ERROR: \${FCST_HRS} is not defined.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_len=`printf %03d $(( 10#${FCST_HRS} ))`
  fi
elif [[ ${IF_DYN_LEN} = ${YES} ]]; then
  printf "Generating forecast forcing data until experiment validation time.\n"
  if [ ${#EXP_VRF} -ne 10 ]; then
    printf "ERROR: \${EXP_VRF}, ${EXP_VRF}, is not in 'YYYMMDDHH' format.\n"
    exit 1
  else
    # compute forecast length relative to start time and verification time
    exp_vrf="${EXP_VRF:0:8} ${EXP_VRF:8:2}"
    exp_vrf=`date +%s -d "${exp_vrf}"`
    fcst_len=$(( (${exp_vrf} - `date +%s -d "${strt_dt}"`) / 3600 ))
    fcst_len=`printf %03d $(( 10#${fcst_len} ))`
  fi
else
  printf "\${IF_DYN_LEN} must be set to 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# define the end time based on forecast length control flow above
end_dt=`date -d "${strt_dt} ${fcst_len} hours"`

# define a sequence of all forecast hours with background interval spacing
fcst_seq=`seq -f "%03g" 0 ${BKG_INT} ${fcst_len}`

if [ ! ${BKG_INT} ]; then
  printf "ERROR: \${BKG_INT} is not defined.\n"
  exit 1
elif [ ${BKG_INT} -le 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [[ ${BKG_DATA} != GFS && ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
fi

if [ ${#MAX_DOM} -ne 2 ]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not in DD format.\n"
  exit 1
elif [ ${MAX_DOM} -le 00 ]; then
  msg="ERROR: \${MAX_DOM} must be an integer for the max WRF "
  msg+="domain index > 00.\n"
  printf "${msg}"
  exit 1
fi

# define a sequence of all domains in padded syntax
dmns=`seq -f "%02g" 1 ${MAX_DOM}`

if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  printf "SST Update turned on.\n"
  sst_update=1
elif [[ ${IF_SST_UPDTE} = ${NO} ]]; then
  printf "SST Update turned off.\n"
  sst_update=0
else
  printf "ERROR: \${IF_SST_UPDTE} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define real workflow dependencies
##################################################################################
# Below variables are defined in workflow variables
#
# WRF_ROOT = Root directory of a "clean" WRF build WRF/run directory
# EXP_CNFG = Root directory containing sub-directories for namelists
#            vtables, geogrid data, GSI fix files, etc.
# CYC_HME  = Start time named directory for cycling data containing
#            bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# MPIRUN   = MPI multiprocessing evaluation call, machine specific
# N_PROC   = The total number of processes to run real.exe with MPI
#
##################################################################################

if [ ! ${WRF_ROOT} ]; then
  printf "ERROR: \${WRF_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WRF_ROOT} ]; then
  printf "ERROR: \${WRF_ROOT} directory\n ${WRF_ROOT}\n does not exist.\n"
  exit 1
fi

if [ ! ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} is not defined.\n"
  exit 1
elif [ ! -d ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} directory\n ${EXP_CNFG}\n does not exist.\n"
  exit 1
fi

if [ ! ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
elif [ ! -d ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [ ! ${MPIRUN} ]; then
  printf "ERROR: \${MPIRUN} is not defined.\n"
  exit 1
fi

if [ ! ${N_PROC} ]; then
  printf "ERROR: \${N_PROC} is not defined.\n"
  exit 1
elif [ ${N_PROC} -le 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processors to run real.exe.\n"
  printf "${msg}"
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

work_root=${CYC_HME}/realprd/ens_${memid}
mkdir -p ${work_root}
cmd="cd ${work_root}"
printf "${cmd}\n"; eval "${cmd}"

wrf_dat_files=(${WRF_ROOT}/run/*)
real_exe=${WRF_ROOT}/main/real.exe

if [ ! -x ${real_exe} ]; then
  printf "ERROR:\n ${real_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  printf "${cmd}\n"; eval "${cmd}"
done

# Remove IC/BC in the directory if old data present
cmd="rm -f wrfinput_d0*"
printf "${cmd}\n"; eval "${cmd}"

cmd="rm -f wrfbdy_d01"
printf "${cmd}\n"; eval "${cmd}"

# Check to make sure the real input files (e.g. met_em.d01.*)
# are available and make links to them
for dmn in ${dmns[@]}; do
  for fcst in ${fcst_seq[@]}; do
    dt_str=`date "+%Y-%m-%d_%H_%M_%S" -d "${strt_dt} ${fcst} hours"`
    realinput_name=met_em.d${dmn}.${dt_str}.nc
    wps_dir=${CYC_HME}/wpsprd/ens_${memid}
    if [ ! -r "${wps_dir}/${realinput_name}" ]; then
      printf "ERROR: Input file\n ${CYC_HME}/${realinput_name}\n is missing.\n"
      exit 1
    else
      cmd="ln -sfr ${wps_dir}/${realinput_name} ."
      printf "${cmd}\n"; eval "${cmd}"
    fi
  done
done

# Move existing rsl files to a subdir if there are any
printf "Checking for pre-existing rsl files.\n"
if [ -f rsl.out.0000 ]; then
  rsldir=rsl.`ls -l --time-style=+%Y-%m-%d_%H_%M_%S rsl.out.0000 | cut -d" " -f 6`
  mkdir ${rsldir}
  printf "Moving pre-existing rsl files to ${rsldir}.\n"
  cmd="mv rsl.out.* ${rsldir}"
  printf "${cmd}\n"; eval "${cmd}"
  cmd="mv rsl.error.* ${rsldir}"
  printf "${cmd}\n"; eval "${cmd}"
else
  printf "No pre-existing rsl files were found.\n"
fi

##################################################################################
#  Build real namelist
##################################################################################
# Remove any previous namelists
cmd="rm -f namelist.input"
printf "${cmd}\n"; eval "${cmd}"

# Copy the wrf namelist template, NOTE: THIS WILL BE MODIFIED DO NOT LINK TO IT
namelist_temp=${EXP_CNFG}/namelists/namelist.${BKG_DATA}
if [ ! -r ${namelist_temp} ]; then 
  msg="WRF namelist template\n ${namelist_temp}\n is not readable or "
  msg+="does not exist.\n"
  printf "${msg}"
  exit 1
else
  cmd="cp -L ${namelist_temp} ./namelist.input"
  printf "${cmd}\n"; eval "${cmd}"
fi

# Get the start and end time components
s_Y=`date +%Y -d "${strt_dt}"`
s_m=`date +%m -d "${strt_dt}"`
s_d=`date +%d -d "${strt_dt}"`
s_H=`date +%H -d "${strt_dt}"`
s_M=`date +%M -d "${strt_dt}"`
s_S=`date +%S -d "${strt_dt}"`
e_Y=`date +%Y -d "${end_dt}"`
e_m=`date +%m -d "${end_dt}"`
e_d=`date +%d -d "${end_dt}"`
e_H=`date +%H -d "${end_dt}"`
e_M=`date +%M -d "${end_dt}"`
e_S=`date +%S -d "${end_dt}"`

# define start / end time iso patterns
strt_iso=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
end_iso=`date +%Y-%m-%d_%H_%M_%S -d "${end_dt}"`

# Update max_dom in namelist
in_dom="\(MAX_DOM\)${EQUAL}MAX_DOM"
out_dom="\1 = ${MAX_DOM}"
cat namelist.input \
  | sed "s/${in_dom}/${out_dom}/" \
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

# update the auxinput4_interval to the BKG_INT
(( auxinput4_minutes = BKG_INT * 60 ))
aux_in="\(AUXINPUT4_INTERVAL\)${EQUAL}AUXINPUT4_INTERVAL"
aux_out="\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}"
cat namelist.input \
  | sed "s/${aux_in}/${aux_out}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Put dummy filler values in the template for the following (not used in real)
in_hist="\(HISTORY_INTERVAL\)${EQUAL}HISTORY_INTERVAL"
out_hist="\1 = 0,"
cat namelist.input \
  | sed "s/${in_hist}/${out_hist}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input
in_hist="\(AUXHIST2_INTERVAL\)${EQUAL}AUXHIST2_INTERVAL"
cat namelist.input \
  | sed "s/${in_hist}/${out_hist}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input
cat namelist.input \
  | sed "s/\(RESTART\)${EQUAL}RESTART/\1 = .false./" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input
cat namelist.input \
  | sed "s/\(RESTART_INTERVAL\)${EQUAL}RESTART_INTERVAL/\1 = 0/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input
cat namelist.input \
  | sed "s/\(FEEDBACK\)${EQUAL}FEEDBACK/\1 = 0/"\
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

##################################################################################
# Run REAL
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_CNFG     = ${EXP_CNFG}\n"
printf "MEMID        = ${MEMID}\n"
printf "CYC_HME      = ${CYC_HME}\n"
printf "STRT_DT      = ${strt_iso}\n"
printf "END_DT       = ${end_iso}\n"
printf "BKG_INT      = ${BKG_INT}\n"
printf "BKG_DATA     = ${BKG_DATA}\n"
printf "MAX_DOM      = ${MAX_DOM}\n"
printf "IF_SST_UPDTE = ${IF_SST_UPDTE}\n"
printf "\n"
now=`date +%Y-%m-%d_%H_%M_%S`
printf "real started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${real_exe}"
printf "${cmd}\n"; eval "${cmd}"

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.real.${now}
mkdir ${rsldir}
cmd="mv rsl.out.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv rsl.error.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"

cmd="mv namelist.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${real_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Look for successful completion messages in rsl files
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE REAL/' | wc -l`
(( ntotal = N_PROC * 2 ))
printf "Found ${nsuccess} of ${ntotal} completion messages.\n"
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR:\n ${real_exe}\n did not complete sucessfully, missing "
  msg+="completion messages in rsl.* files.\n"
  printf "${msg}"
  exit 1
fi

# check to see if the BC output is generated
if [ ! -s wrfbdy_d01 ]; then
  msg="ERROR:\n ${real_exe}\n failed to generate boundary conditions "
  msg+="wrfbdy_d01.\n"
  printf "${msg}"
  exit 1
fi

# check to see if the IC output is generated
for dmn in ${dmns[@]}; do
  ic_file=wrfinput_d${dmn}
  if [ ! -s ${ic_file} ]; then
    msg="ERROR:\n ${real_exe}\n failed to generate initial conditions ${ic_file} "
    msg+="for domain d${dmn}.\n"
    printf "${msg}"
    exit 1
  fi
done

# check to see if the SST update fields are generated
if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
  for dmn in ${dmns[@]}; do
    sst_file=wrflowinp_d${dmn}
    if [ ! -s ${sst_file} ]; then
      msg="ERROR:\n ${real_exe}\n failed to generate SST update file ${sst_file} "
      msg+="for domain d${dmn}.\n"
      printf "${msg}"
      exit 1
    fi
  done
fi

# Remove the real input files (e.g. met_em.d01.*)
cmd="rm -f ./met_em.*"
printf "${cmd}\n"; eval "${cmd}"

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    cmd="rm -f `basename ${file}`"
    printf "${cmd}\n"; eval "${cmd}"
done

printf "real.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
