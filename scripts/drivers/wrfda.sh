#!/bin/bash
##################################################################################
# Description
##################################################################################
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
# Make checks for WRFDA settings
##################################################################################
# Options below are defined in control flow xml
#
# ANL_DT       = Analysis time YYYYMMDDHH
# BOUNDARY     = 'LOWER' if updating lower boundary conditions 
#                'LATERAL' if updating lateral boundary conditions
# WRF_CTR_DOM  = Max domain index of control forecast to update BOUNDARY=LOWER
# IF_ENS_UPDTE = Skip lower / lateral BC updates if 'No'
# N_ENS        = Max ensemble index to apply update IF_ENS_UPDATE='Yes'
# ENS_ROOT     = Forecast ensemble located at ${ENS_ROOT}/ens_${memid}/wrfout* 
# WRF_ENS_DOM  = Max domain index of ensemble perturbations
#
##################################################################################

# Convert ANL_DT from 'YYYYMMDDHH' format to anl_iso iso format
if [ ${#ANL_DT} -ne 10 ]; then
  printf "ERROR: \${ANL_DT}, ${ANL_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  anl_date=${ANL_DT:0:8}
  hh=${ANL_DT:8:2}
  anl_iso=`date +%Y-%m-%d_%H_%M_%S -d "${anl_date} ${hh} hours"`
fi

if [[ ${BOUNDARY} = ${LOWER} ]]; then
  if [ ${#WRF_CTR_DOM} -ne 2 ]; then
    printf "ERROR: \${WRF_CTR_DOM}, ${WRF_CTR_DOM} is not in DD format.\n"
    exit 1
  fi
  msg="Updating lower boundary conditions for WRF control domains "
  msg+="d01 through d${WRF_CTR_DOM}.\n"
  printf "${msg}"
elif [[ ${BOUNDARY} = ${LATERAL} ]]; then
  printf "Updating WRF control lateral boundary conditions.\n"
else
  msg="ERROR: \${BOUNDARY}, ${BOUNDARY}, must equal 'LOWER' or 'LATERAL'"
  msg+="(case insensitive).\n"
  printf "${msg}"
  exit 1
fi

if [[ ${IF_ENS_UPDTE} = ${NO} ]]; then
  # skip the boundary updates for the ensemble, perform on control alone
  ens_max=0
elif [[ ${IF_ENS_UPDTE} = ${YES} ]]; then
  if [ ! ${N_ENS} ]; then
    printf "ERROR: \${N_ENS} is not defined.\n"
    exit 1
  fi
  if [ ! ${ENS_ROOT} ]; then
    printf "ERROR: \${ENS_ROOT} is not defined.\n"
    exit 1
  elif [ ! -d ${ENS_ROOT} ]; then
    printf "ERROR: \${ENS_ROOT} directory\n ${ENS_ROOT}\n does not exist.\n"
    exit 1
  elif [[ ${BOUNDARY} = LOWER && ${#WRF_ENS_DOM} -ne 2 ]]; then
    printf "ERROR: \${WRF_ENS_DOM}, ${WRF_ENS_DOM}, is not in DD format.\n"
    exit 1
  else
    # perform over the entire ensemble (ensure base 10 for padded indices)
    ens_max=`printf $(( 10#${N_ENS} ))`
    msg="Updating lower boundary conditions for WRF perturbation domains "
    msg+="d01 through d${WRF_ENS_DMN}."
    printf "${msg}"
  fi
else
  printf "ERROR: \${IF_ENS_UPDTE} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define wrfda dependencies
##################################################################################
# Below variables are defined in control flow variables
#
# WRFDA_ROOT = Root directory of a WRFDA build 
# EXP_CNFG   = Root directory containing sub-directories for namelists
#              vtables, geogrid data, GSI fix files, etc.
# CYC_HME    = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
#
##################################################################################

if [ ! ${WRFDA_ROOT} ]; then
  printf "ERROR: \${WRFDA_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${WRFDA_ROOT} ]; then
  printf "ERROR: \${WRFDA_ROOT} directory\n ${WRFDA_ROOT}\n does not exist.\n"
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
elif [ ! -d "${CYC_HME}" ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

##################################################################################
# Begin pre-WRFDA setup
##################################################################################
# The following paths are relative to control flow supplied root paths
#
# work_root      = Directory where da_update_bc.exe runs
# real_dir       = Directory real.exe runs and outputs IC and BC files for cycle
# ctr_dir        = Directory with control WRF forecast for lower boundary update 
# ens_dir        = Directory with ensemble WRF forecast for lower boundary update 
# gsi_dir        = Directory with GSI control analysis for lateral update
# enkf_dir       = Directory with EnKF analysis for ensemble lateral update
# update_bc_exe  = Path and name of the update executable
#
##################################################################################

for memid in `seq -f "%02g" 0 ${ens_max}`; do
  work_root=${CYC_HME}/wrfdaprd
  real_dir=${CYC_HME}/realprd/ens_${memid}
  gsi_dir=${CYC_HME}/gsiprd
  enkf_dir=${CYC_HME}/enkfprd
  update_bc_exe=${WRFDA_ROOT}/var/da/da_update_bc.exe
  
  if [ ! -d ${real_dir} ]; then
    printf "ERROR: \${real_dir} directory\n ${real_dir}\n does not exist.\n"
    exit 1
  fi
  
  if [ ! -x ${update_bc_exe} ]; then
    printf "ERROR:\n ${update_bc_exe}\n does not exist, or is not executable.\n"
    exit 1
  fi
  
  if [[ ${BOUNDARY} = ${LOWER} ]]; then 
    # create working directory and cd into it
    work_root=${work_root}/lower_bdy_update/ens_${memid}
    mkdir -p ${work_root}
    cmd="cd ${work_root}"
    printf "${cmd}\n"; eval "${cmd}"
    
    # Remove IC/BC in the directory if old data present
    cmd="rm -f wrfout_*"
    printf "${cmd}\n"; eval "${cmd}"
    
    cmd="rm -f wrfinput_d*"
    printf "${cmd}\n"; eval "${cmd}"
  
    if [ ${memid} = 00 ]; then 
      # control background sourced from last cycle background
      bkg_dir=${CYC_HME}/bkg/ens_${memid}
      max_dom=${WRF_CTR_DOM}
    else
      # perturbation background sourced from ensemble root
      bkg_dir=${ENS_ROOT}/bkg/ens_${memid}
      max_dom=${WRF_ENS_DOM}
    fi

    # verify forecast data root
    if [ ! -d ${bkg_dir} ]; then
      printf "ERROR: \${bkg_dir} directory\n ${bkg_dir}\n does not exist.\n"
      exit 1
    fi
    
    # Check to make sure the input files are available and copy them
    printf "Copying background and input files.\n"
    for dmn in `seq -f "%02g" 01 ${max_dom}`; do
      # update the lower BC for the output file to pass to GSI
      wrfout=wrfout_d${dmn}_${anl_iso}

      # wrfinput is always drawn from real step
      wrfinput=wrfinput_d${dmn}
  
      if [ ! -r "${bkg_dir}/${wrfout}" ]; then
        printf "ERROR: Input file\n ${bkg_dir}/${wrfout}\n is missing.\n"
        exit 1
      else
        cmd="cp -L ${bkg_dir}/${wrfout} ."
        printf "${cmd}\n"; eval "${cmd}"
      fi
  
      if [ ! -r "${real_dir}/${wrfinput}" ]; then
        printf "ERROR: Input file\n ${real_dir}/${wrfinput}\n is missing.\n"
        exit 1
      else
        cmd="cp -L ${real_dir}/${wrfinput} ."
        printf "${cmd}\n"; eval "${cmd}"
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cmd="cp -L ${EXP_CNFG}/namelists/parame.in ."
      printf "${cmd}\n"; eval "${cmd}"
  
      # Update the namelist for the domain id 
      cat parame.in \
        | sed "s/\(DA_FILE\)${EQUAL}DA_FILE/\1 = '\.\/${wrfout}'/" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      cat parame.in \
        | sed "s/\(WRF_INPUT\)${EQUAL}WRF_INPUT/\1 = '\.\/${wrfinput}'/" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      cat parame.in \
        | sed "s/\(DOMAIN_ID\)${EQUAL}DOMAIN_ID/\1 = ${dmn}/" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      # Update the namelist for lower boundary update 
      cat parame.in \
        | sed "s/\(UPDATE_LOW_BDY\)${EQUAL}UPDATE_LOW_BDY/\1 = \.true\./" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      cat parame.in \
        | sed "s/\(UPDATE_LATERAL_BDY\)${EQUAL}UPDATE_LATERAL_BDY/\1 = \.false\./" \
        > parame.in.tmp
      mv parame.in.tmp parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      printf "\n"
      printf "MEM_ID   = ${memid}\n"
      printf "BOUNDARY = ${BOUNDARY}\n"
      printf "DOMAIN   = ${dmn}\n"
      printf "ANL_DT   = ${anl_iso}\n"
      printf "EXP_CNFG = ${EXP_CNFG}\n"
      printf "CYC_HME  = ${CYC_HME}\n"
      printf "ENS_ROOT = ${ENS_ROOT}\n"
      printf "\n"
      now=`date +%Y-%m-%d_%H_%M_%S`
      printf "da_update_bc.exe started at ${now}.\n"
      cmd="${update_bc_exe}"
      printf "${cmd}\n"; eval "${cmd}"
  
      ##################################################################################
      # Run time error check
      ##################################################################################
      error=$?
      
      # NOTE: THIS CHECK NEEDS IMPROVEMENT, DOESN'T CATCH ERRORS IN THE PROGRAM LOG
      if [ ${error} -ne 0 ]; then
        printf "ERROR:\n ${update_bc_exe}\n exited with status ${error}.\n"
        exit ${error}
      fi
    done
  
  else
    # create working directory and cd into it
    work_root=${work_root}/lateral_bdy_update/ens_${memid}
    mkdir -p ${work_root}
    cmd="cd ${work_root}"
    printf "${cmd}\n"; eval "${cmd}"
    
    # Remove IC/BC in the directory if old data present
    cmd="rm -f wrfout_*"
    printf "${cmd}\n"; eval "${cmd}"

    cmd="rm -f wrfinput_d0*"
    printf "${cmd}\n"; eval "${cmd}"

    cmd="rm -f wrfbdy_d01"
    printf "${cmd}\n"; eval "${cmd}"

    if [ ${memid} = 00 ]; then
      if [ ! -d ${gsi_dir} ]; then
        printf "ERROR: \${gsi_dir} directory\n ${gsi_dir}\n does not exist.\n"
        exit 1
      else
        wrfanl=${gsi_dir}/d01/wrfanl_ens_${memid}_${anl_iso}
      fi
    else
      if [ ! -d ${enkf_dir} ]; then
        printf "ERROR: \${enkf_dir} directory\n ${enkf_dir}\n does not exist.\n"
        exit 1
      else
        # NOTE: ENKF SCRIPT NEED TO UPDATE OUTPUT NAMING CONVENTIONS
        wrfanl=${enkf_dir}/d01/wrfanl_ens_${memid}_${anl_iso}
      fi
    fi

    wrfbdy=${real_dir}/wrfbdy_d01
    wrfvar_outname=wrfanl_ens_${memid}_${anl_iso}
  
    if [ ! -r "${wrfanl}" ]; then
      printf "ERROR: Input file\n ${wrfanl}\n is missing.\n"
      exit 1
    else
      cmd="cp -L ${wrfanl} ${wrfvar_outname}"
      printf "${cmd}\n"; eval "${cmd}"
    fi
  
    if [ ! -r "${wrfbdy}" ]; then
      printf "ERROR: Input file \n${wrfbdy}\n is missing.\n"
      exit 1
    else
      cmd="cp -L ${wrfbdy} ."
      printf "${cmd}\n"; eval "${cmd}"
    fi
  
    ##################################################################################
    #  Build da_update_bc namelist
    ##################################################################################
    # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
    cmd="cp -L ${EXP_CNFG}/namelists/parame.in ."
    printf "${cmd}\n"; eval "${cmd}"
  
    # Update the namelist for lateral boundary update 
    cat parame.in \
      | sed "s/\(DA_FILE\)${EQUAL}DA_FILE/\1 = '\.\/${wrfvar_outname}'/" \
      > parame.in.tmp
    mv parame.in.tmp parame.in
  
    cat parame.in \
      | sed "s/\(DOMAIN_ID\)${EQUAL}DOMAIN_ID/\1 = 01/" \
      > parame.in.tmp
    mv parame.in.tmp parame.in
  
    # Update the namelist for lateral boundary update 
    cat parame.in \
      | sed "s/\(UPDATE_LOW_BDY\)${EQUAL}UPDATE_LOW_BDY/\1 = \.false\./" \
      > parame.in.tmp
    mv parame.in.tmp parame.in
  
    cat parame.in \
      | sed "s/\(UPDATE_LATERAL_BDY\)${EQUAL}UPDATE_LATERAL_BDY/\1 = \.true\./" \
      > parame.in.tmp
    mv parame.in.tmp parame.in

    cat parame.in \
       | sed "s/\(WRF_BDY_FILE\)${EQUAL}WRF_BDY_FILE/\1 = '\.\/${wrfbdy_name}'/" \
       > parame.in.tmp
    mv parame.in.tmp parame.in
  
    # fill with a dummy argument in namelist template
    cat parame.in \
      | sed "s/\(WRF_INPUT\)${EQUAL}WRF_INPUT/\1 = '\.\/wrfinput_d01'/" \
      > parame.in.tmp
    mv parame.in.tmp parame.in
  
    ##################################################################################
    # Run update_bc_exe
    ##################################################################################
    # Print run parameters
    printf "\n"
    printf "MEM_ID   = ${memid}\n"
    printf "BOUNDARY = ${BOUNDARY}\n"
    printf "DOMAIN   = ${dmn}\n"
    printf "ANL_DT   = ${anl_iso}\n"
    printf "EXP_CNFG = ${EXP_CNFG}\n"
    printf "CYC_HME  = ${CYC_HME}\n"
    printf "ENS_ROOT = ${ENS_ROOT}\n"
    printf "\n"
    now=`date +%Y-%m-%d_%H_%M_%S`
    printf "da_update_bc.exe started at ${now}.\n"
    cmd="${update_bc_exe}"
    printf "${cmd}\n"; eval "${cmd}"
  
    ##################################################################################
    # Run time error check
    ##################################################################################
    error=$?
    
    # NOTE: THIS CHECK NEEDS IMPROVEMENT, DOESN'T CATCH ERRORS IN THE PROGRAM LOG
    if [ ${error} -ne 0 ]; then
      printf "ERROR:\n ${update_bc_exe}\n exited with status ${error}.\n"
      exit ${error}
    fi
  fi
done

printf "wrfda.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################

exit 0
