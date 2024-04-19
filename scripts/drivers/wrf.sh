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
# Make checks for WRF settings
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
# DOWN_DOM     = First domain index to downscale ICs from d01, set parameter
#                less than MAX_DOM if downscaling to be used
# WRFOUT_INT   = Interval of wrfout in HH
# CYC_INT      = Interval in HH on which DA is cycled in a cycling control flow
# WRF_IC       = Defines where to source WRF initial and boundary conditions from
#                  WRF_IC = REALEXE : ICs / BCs from CYC_HME/realprd
#                  WRF_IC = CYCLING : ICs / BCs from GSI / WRFDA analysis
#                  WRF_IC = RESTART : ICs from restart file in CYC_HME/wrfprd
# IF_SST_UPDTE = Yes / No: whether WRF uses dynamic SST values 
# IF_FEEBACK   = Yes / No: whether WRF domains use 1- or 2-way nesting
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

if [ ${#CYC_DT} -ne 10 ]; then
  printf "ERROR: \${CYC_DT}, ${CYC_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # Convert CYC_DT from 'YYYYMMDDHH' format to cyc_dt Unix date format
  cyc_dt="${CYC_DT:0:8} ${CYC_DT:8:2}"
  cyc_dt=`date -d "${cyc_dt}"`
fi

if [[ ${IF_DYN_LEN} = ${NO} ]]; then 
  printf "Generating fixed length forecast forcing data.\n"
  if [ ! ${FCST_HRS} ]; then
    printf "ERROR: \${FCST_HRS} is not defined.\n"
    exit 1
  else
    # parse forecast hours as base 10 padded
    fcst_len=`printf %03d $(( 10#${FCST_HRS} ))`
    printf "Forecast length is ${fcst_len} hours.\n"
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


if [ ! ${BKG_INT} ]; then
  printf "ERROR: \${BKG_INT} is not defined.\n"
  exit 1
elif [ ! ${BKG_INT} -gt 0 ]; then
  printf "ERROR: \${BKG_INT} must be HH > 0 for the frequency of data inputs.\n"
  exit 1
fi

if [[ ${BKG_DATA} != GFS &&  ${BKG_DATA} != GEFS ]]; then
  msg="ERROR: \${BKG_DATA} must equal 'GFS' or 'GEFS'"
  msg+=" as currently supported inputs.\n"
  printf "${msg}"
  exit 1
fi

if [ ${#MAX_DOM} -ne 2 ]; then
  printf "ERROR: \${MAX_DOM}, ${MAX_DOM}, is not in DD format.\n"
  exit 1
elif [ ! ${MAX_DOM} -gt 00 ]; then
  printf "ERROR: \${MAX_DOM} must be an integer for the max WRF domain index > 00.\n"
  exit 1
fi

# define a sequence of all domains in padded syntax
dmns=`seq -f "%02g" 1 ${MAX_DOM}`

if [ ${#DOWN_DOM} -ne 2 ]; then
  printf "ERROR: \${DOWN_DOM}, ${DOWN_DOM}, is not in DD format.\n"
  exit 1
elif [ ! ${DOWN_DOM} -gt 01 ]; then
  msg="ERROR: \${DOWN_DOM} must be an integer for the first WRF domain index "
  msg+=" to be downscaled from parent ( > 01 )." 
  exit 1
fi

if [ ${#WRFOUT_INT} -ne 2 ]; then
  printf "ERROR: \${WRFOUT_INT} is not in HH format.\n"
  exit 1
elif [ ! ${WRFOUT_INT} -gt 00 ]; then
  printf "ERROR: \${WRFOUT_INT} must be an integer for the max WRF domain index > 0.\n"
  exit 1
fi

if [ ${#CYC_INT} -ne 2 ]; then
  printf "ERROR: \${CYC_INT}, ${CYC_INT}, is not in 'HH' format.\n"
  exit 1
elif [ ${CYC_INT} -le 0 ]; then
  printf "ERROR: \${CYC_INT} must be an integer for the number of cycle hours > 0.\n"
fi

if [[ ${WRF_IC} = ${REALEXE} ]]; then
  printf "WRF initial and boundary conditions sourced from real.exe.\n"
elif [[ ${WRF_IC} = ${CYCLING} ]]; then
  msg="WRF initial conditions and boundary conditions sourced from GSI / WRFDA "
  msg+=" analysis.\n"
  printf "${msg}"
elif [[ ${WRF_IC} = ${RESTART} ]]; then
  printf "WRF initial conditions sourced from restart files.\n"
else
  msg="ERROR: \${WRF_IC}, ${WRF_IC}, must equal REALEXE, CYCLING or RESTART "
  msg+=" (case insensitive).\n"
  printf "${msg}"
  exit 1
fi

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

if [[ ${IF_FEEDBACK} = ${YES} ]]; then
  printf "Two-way WRF nesting is turned on.\n"
  feedback=1
elif [[ ${IF_FEEDBACK} = ${NO} ]]; then
  printf "One-way WRF nesting is turned on.\n"
  feedback=0
else
  printf "ERROR: \${IF_FEEDBACK} must equal 'Yes' or 'No' (case insensitive).\n"
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
# CYC_HME    = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# MPIRUN     = MPI Command to execute WRF
# N_PROC     = The total number of processes to run wrf.exe with MPI
# NIO_GROUPS = Number of Quilting groups -- only used for NIO_TPG > 0
# NIO_TPG    = Quilting tasks per group, set=0 if no quilting IO is to be used
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
  printf "ERROR: \${EXP_CONFIG} directory\n ${EXP_CONFIG}\n does not exist.\n"
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
elif [ ! ${N_PROC} -gt 0 ]; then
  msg="ERROR: The variable \${N_PROC} must be set to the number"
  msg+=" of processors to run wrf.exe.\n"
  printf "${msg}"
  exit 1
fi

##################################################################################
# Begin pre-WRF setup
##################################################################################
# The following paths are relative to workflow supplied root paths
#
# work_root     = Working directory where WRF runs
# wrf_dat_files = All file contents of clean WRF/run directory
#                 namelists, boundary and input data will be linked
#                 from other sources
# wrf_exe       = Path and name of working executable
#
##################################################################################

work_root=${CYC_HME}/wrfprd/ens_${memid}
mkdir -p ${work_root}
cmd="cd ${work_root}"
printf "${cmd}\n"; eval "${cmd}"

wrf_dat_files=(${WRF_ROOT}/run/*)
wrf_exe=${WRF_ROOT}/main/wrf.exe

if [ ! -x ${wrf_exe} ]; then
  printf "ERROR:\n ${wrf_exe}\n does not exist, or is not executable.\n"
  exit 1
fi

# Make links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
  cmd="ln -sf ${file} ."
  printf "${cmd}\n"; eval "${cmd}"
done

if [[ ${WRF_IC} = ${REALEXE} || ${WRF_IC} = ${CYCLING} ]]; then
  # Remove any old WRF outputs in the directory from failed runs
  cmd="rm -f wrfout_*"
  printf "${cmd}\n"; eval "${cmd}"
  cmd="rm -f wrfrst_*"
  printf "${cmd}\n"; eval "${cmd}"
fi

# Link WRF initial conditions
for dmn in ${dmns[@]}; do
  wrfinput=wrfinput_d${dmn}
  dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt}"`
  # if cycling AND analyzing this domain, get initial conditions from last analysis
  if [[ ${WRF_IC} = ${CYCLING} && ${dmn} -lt ${DOWN_DOM} ]]; then
    if [[ ${dmn} = 01 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA 
      wrfanlroot=${CYC_HME}/wrfdaprd/lateral_bdy_update/ens_${memid}
      wrfbdy=${wrfanlroot}/wrfbdy_d01
      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      printf "${cmd}\n"; eval "${cmd}"
      if [ ! -r "./wrfbdy_d01" ]; then
        printf "ERROR: wrfinput\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi

    else
      # Nested domains have boundary conditions defined by parent
      if [ ${memid} -eq 00 ]; then
        # control solution is indexed 00, analyzed with GSI
        wrfanl_root=${CYC_HME}/gsiprd/d${dmn}
      else
        # ensemble perturbations are updated with EnKF step
        wrfanl_root=${CYC_HME}/enkfprd/d${dmn}
      fi
    fi

    # link the wrf inputs
    wrfanl=${wrfanlroot}/wrfanl_ens_${memid}_${dt_str}
    cmd="ln -sfr ${wrfanl} ${wrfinput}"
    printf "${cmd}\n"; eval "${cmd}"

    if [ ! -r ${wrfinput} ]; then
      printf "ERROR: wrfinput source\n ${wrfanl}\n does not exist or is not readable.\n"
      exit 1
    fi

  elif [[ ${WRF_IC} = ${RESTART} ]]; then
    # check for restart files at valid start time for each domain
    wrfrst=${work_root}/wrfrst_d${dmn}_${dt_str}
    if [ ! -r ${wrfrst} ]; then
      printf "ERROR: wrfrst source\n ${wrfrst}\n does not exist or is not readable.\n"
      exit 1
    fi

    if [[ ${dmn} = 01 ]]; then
      # obtain the boundary files from the lateral boundary update by WRFDA step
      # included for possible re-generation of BCs for longer extended forecast
      wrfanlroot=${CYC_HME}/wrfdaprd/lateral_bdy_update/ens_${memid}
      wrfbdy=${wrfanlroot}/wrfbdy_d01
      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      printf "${cmd}\n"; eval "${cmd}"
      if [ ! -r "./wrfbdy_d01" ]; then
        printf "ERROR: wrfinput\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi
    fi

  else
    # else get initial and boundary conditions from real for downscaled domains
    realroot=${CYC_HME}/realprd/ens_${memid}
    if [ ${dmn} = 01 ]; then
      # Link the wrfbdy_d01 file from real
      wrfbdy=${realroot}/wrfbdy_d01
      cmd="ln -sfr ${wrfbdy} wrfbdy_d01"
      printf "${cmd}\n"; eval "${cmd}";

      if [ ! -r wrfbdy_d01 ]; then
        printf "ERROR:\n ${wrfbdy}\n does not exist or is not readable.\n"
        exit 1
      fi
    fi
    realname=${realroot}/${wrfinput}
    cmd="ln -sfr ${realname} ."
    printf "${cmd}\n"; eval "${cmd}"

    if [ ! -r ${wrfinput} ]; then
      printf "ERROR: wrfinput\n ${realname}\n does not exist or is not readable.\n"
      exit 1
    fi
  fi

  # NOTE: THIS LINKS SST UPDATE FILES FROM REAL OUTPUTS REGARDLESS OF GSI CYCLING
  if [[ ${IF_SST_UPDTE} = ${YES} ]]; then
    wrflowinp=wrflowinp_d${dmn}
    realname=${CYC_HME}/realprd/ens_${memid}/${wrflowinp}
    cmd="ln -sfr ${realname} ."
    printf "${cmd}\n"; eval "${cmd}"
    if [ ! -r ${wrflowinp} ]; then
      printf "ERROR: wrflwinp\n ${wrflowinp}\n does not exist or is not readable.\n"
      exit 1
    fi
  fi
done

# Move existing rsl files to a subdir if there are any
printf "Checking for pre-existing rsl files.\n"
if [ -f rsl.out.0000 ]; then
  rsldir=rsl.wrf.`ls -l --time-style=+%Y-%m-%d_%H_%M%_S rsl.out.0000 | cut -d" " -f 6`
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
#  Build WRF namelist
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

# Update the max_dom in namelist
in_dom="\(MAX_DOM\)${EQUAL}MAX_DOM"
out_dom="\1 = ${MAX_DOM}"
cat namelist.input \
  | sed "s/${in_dom}/${out_dom}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the history interval in wrf namelist (minutes, propagates settings to three domains)
(( hist_int = ${WRFOUT_INT} * 60 ))
in_hist="\(HISTORY_INTERVAL\)${EQUAL}HISTORY_INTERVAL"
out_hist="\1 = ${hist_int}, ${hist_int}, ${hist_int}"
cat namelist.input \
  | sed "s/${in_hist}/${out_hist}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

in_hist="\(AUXHIST2_INTERVAL\)${EQUAL}AUXHIST2_INTERVAL"
cat namelist.input \
  | sed "s/${in_hist}/${out_hist}/" \
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
fcst_hrs=`printf $(( 10#${fcst_len} ))`
run_mins=$(( ${fcst_hrs} * 60 ))
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

# update the auxinput4_interval to the BKG_INT
(( auxinput4_minutes = BKG_INT * 60 ))
aux_in="\(AUXINPUT4_INTERVAL\)${EQUAL}AUXINPUT4_INTERVAL"
aux_out="\1 = ${auxinput4_minutes}, ${auxinput4_minutes}, ${auxinput4_minutes}"
cat namelist.input \
  | sed "s/${aux_in}/${aux_out}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update feedback option for nested domains
cat namelist.input \
  | sed "s/\(FEEDBACK\)${EQUAL}FEEDBACK/\1 = ${feedback}/"\
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

# Update the quilting settings to the parameters set in the workflow
cat namelist.input \
  | sed "s/\(NIO_TASKS_PER_GROUP\)${EQUAL}NIO_TASKS_PER_GROUP/\1 = ${NIO_TPG}/" \
  | sed "s/\(NIO_GROUPS\)${EQUAL}NIO_GROUPS/\1 = ${NIO_GROUPS}/" \
  > namelist.input.tmp
mv namelist.input.tmp namelist.input

##################################################################################
# Run WRF
##################################################################################
# Print run parameters
printf "\n"
printf "EXP_CONFIG   = ${EXP_CONFIG}\n"
printf "MEMID        = ${MEMID}\n"
printf "CYC_HME      = ${CYC_HME}\n"
printf "STRT_DT      = ${strt_iso}\n"
printf "END_DT       = ${end_iso}\n"
printf "WRFOUT_INT   = ${WRFOUT_INT}\n"
printf "BKG_DATA     = ${BKG_DATA}\n"
printf "MAX_DOM      = ${MAX_DOM}\n"
printf "WRF_IC       = ${WRF_IC}\n"
printf "IF_SST_UPDTE = ${IF_SST_UPDTE}\n"
printf "IF_FEEDBACK  = ${IF_FEEDBACK}\n"
printf
now=`date +%Y-%m-%d_%H_%M_%S`
printf "wrf started at ${now}.\n"
cmd="${MPIRUN} -n ${N_PROC} ${wrf_exe}"
printf "${cmd}\n"; eval "${cmd}"

##################################################################################
# Run time error check
##################################################################################
error=$?

# Save a copy of the RSL files
rsldir=rsl.wrf.${now}
mkdir ${rsldir}
cmd="mv rsl.out.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"
cmd="mv rsl.error.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"
cmd="mv namelist.* ${rsldir}"
printf "${cmd}\n"; eval "${cmd}"

if [ ${error} -ne 0 ]; then
  printf "ERROR:\n ${wrf_exe}\n exited with status ${error}.\n"
  exit ${error}
fi

# Look for successful completion messages adjusted for quilting processes
nsuccess=`cat ${rsldir}/rsl.* | awk '/SUCCESS COMPLETE WRF/' | wc -l`
ntotal=$(( (N_PROC - NIO_GROUPS * NIO_TPG ) * 2 ))
printf "Found ${nsuccess} of ${ntotal} completion messages.\n"
if [ ${nsuccess} -ne ${ntotal} ]; then
  msg="ERROR: ${wrf_exe} did not complete successfully, missing completion "
  msg+="messages in rsl.* files.\n"
  printf "${msg}"
fi

# ensure that the bkg directory exists in next ${CYC_HME}
dt_str=`date +%Y%m%d%H -d "${cyc_dt} ${CYC_INT} hours"`
new_bkg=${dt_str}/bkg/ens_${memid}
cmd="mkdir -p ${CYC_HME}/../${new_bkg}"
printf "${cmd}\n"; eval "${cmd}"

# Check for all wrfout files on WRFOUT_INT and link files to
# the appropriate bkg directory
for dmn in ${dmns[@]}; do
  for fcst in `seq -f "%03g" 0 ${WRFOUT_INT} ${fcst_len}`; do
    dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst} hours"`
    if [ ! -s wrfout_d${dmn}_${dt_str} ]; then
      msg="WRF failed to complete, wrfout_d${dmn}_${dt_str} "
      msg+="is missing or empty.\n"
      printf "${msg}"
      exit 1
    else
      cmd="ln -sfr wrfout_d${dmn}_${dt_str} ${CYC_HME}/../${new_bkg}"
      printf "${cmd}\n"; eval "${cmd}"
    fi
  done
  # Check for all wrfrst files for each domain at end of forecast and link files to
  # the appropriate bkg directory
  dt_str=`date +%Y-%m-%d_%H_%M_%S -d "${strt_dt} ${fcst_len} hours"`
  if [ ! -s wrfrst_d${dmn}_${dt_str} ]; then
    msg="WRF failed to complete, wrfrst_d${dmn}_${dt_str} is "
    msg+="missing or empty.\n"
    printf "${msg}"
    exit 1
  else
    cmd="ln -sfr wrfrst_d${dmn}_${dt_str} ${CYC_HME}/../${new_bkg}"
    printf "${cmd}\n"; eval "${cmd}"
  fi
done

# Remove links to the WRF DAT files
for file in ${wrf_dat_files[@]}; do
    cmd="rm -f `basename ${file}`"
    printf "${cmd}\n"; eval "${cmd}"
done

printf "wrf.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################
# end

exit 0
