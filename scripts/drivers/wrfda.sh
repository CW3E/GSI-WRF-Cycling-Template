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
# in a WRF_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# WRF_constants.sh and the control flow .xml driving this script.
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
##################################################################################
# Preamble
##################################################################################
# uncomment to run verbose for debugging / testing
set -x

if [ ! -x "${CNST}" ]; then
  echo "ERROR: constants file ${CNST} does not exist or is not executable."
  exit 1
fi

# Read constants into the current shell
. ${CNST}

##################################################################################
# Make checks for WRFDA settings
##################################################################################
# Options below are defined in control flow xml
#
# N_ENS        = Max ensemble index (use 00 for control alone)
# ANL_TIME     = Analysis time YYYYMMDDHH
# IF_ENS_UPDTE = Skip lower / lateral BC updates if "No"
# BOUNDARY     = 'LOWER' if updating lower boundary conditions 
#                'LATERAL' if updating lateral boundary conditions
# WRF_CTR_DOM  = Max domain index of control forecast
# WRF_ENS_DOM  = Max domain index of ensemble perturbations
#
# Below variabs are derived by control flow variables for convenience
#
# anl_iso      = Defined by the ANL_TIME variable, to be used as path
#                name variable in YYYY-MM-DD_HH_MM_SS format for wrfout
#
##################################################################################

if [ ! "${N_ENS}" ]; then
  echo "ERROR: \${N_ENS} is not defined."
  exit 1
fi

if [ ! "${ANL_TIME}" ]; then
  echo "ERROR: \${ANL_TIME} is not defined."
  exit 1
fi

# Convert ANL_TIME from 'YYYYMMDDHH' format to anl_iso iso format
if [ ${#ANL_TIME} -ne 10 ]; then
  echo "ERROR: \${ANL_TIME}, '${ANL_TIME}', is not in 'YYYYMMDDHH' format."
  exit 1
else
  anl_date=${ANL_TIME:0:8}
  hh=${ANL_TIME:8:2}
  anl_iso=`date +%Y-%m-%d_%H_%M_%S -d "${anl_date} ${hh} hours"`
fi

if [[ ${IF_ENS_UPDTE} != ${YES} && ${IF_ENS_UPDTE} != ${NO} ]]; then
  echo "ERROR: \${IF_ENS_UPDTE} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${BOUNDARY} != ${LOWER} && ${BOUNDARY} != ${LATERAL} ]]; then
  echo "ERROR: \${BOUNDARY} must equal 'LOWER' or 'LATERAL' (case insensitive)."
  exit 1
fi

if [ ! ${WRF_CTR_DOM} ]; then
  echo "ERROR: \${WRF_CTR_DOM} is not defined."
  exit 1
fi

if [ ! ${WRF_ENS_DOM} ]; then
  echo "ERROR: \${WRF_ENS_DOM} is not defined."
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
# CYCLE_HME  = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# ENS_ROOT   = Forecast ensemble located at ${ENS_ROOT}/ens_${ens_n}/wrfout* 
#
##################################################################################

if [ ! "${WRFDA_ROOT}" ]; then
  echo "ERROR: \${WRFDA_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${WRFDA_ROOT}" ]; then
  echo "ERROR: \${WRFDA_ROOT} directory ${WRFDA_ROOT} does not exist."
  exit 1
fi

if [ ! -d ${EXP_CNFG} ]; then
  echo "ERROR: \${EXP_CNFG} directory ${EXP_CNFG} does not exist."
  exit 1
fi

if [ -z ${CYCLE_HME} ]; then
  echo "ERROR: \${CYCLE_HME} directory name is not defined."
  exit 1
fi

if [ ! "${ENS_ROOT}" ]; then
  echo "ERROR: \${ENS_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${ENS_ROOT}" ]; then
  echo "ERROR: \${ENS_ROOT} directory ${ENS_ROOT} does not exist."
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

if [[ ${IF_ENS_UPDTE} = ${NO} ]]; then
  # skip the boundary updates for the ensemble, perform on control alone
  ens_max=0
else
  # perform over the entire ensemble (ensure base 10 for padded indices)
  ens_max=`printf $(( 10#${N_ENS} ))`
fi

ens_loop=0

while [ ${ens_loop} -le ${ens_max} ]; do
  # define two zero padded string for GEFS 
  memid=`printf %02d $(( 10#${ens_loop} ))`

  work_root=${CYCLE_HME}/wrfdaprd
  real_dir=${CYCLE_HME}/realprd/ens_${memid}
  gsi_dir=${CYCLE_HME}/gsiprd
  enkf_dir=${CYCLE_HME}/enkfprd
  update_bc_exe=${WRFDA_ROOT}/var/da/da_update_bc.exe
  
  if [ ! -d ${real_dir} ]; then
    echo "ERROR: \${real_dir} directory ${real_dir} does not exist."
    exit 1
  fi
  
  if [ ! -x ${update_bc_exe} ]; then
    echo "ERROR: ${update_bc_exe} does not exist, or is not executable."
    exit 1
  fi
  
  # define domain variable to iterate on in lower boundary, fixed in lateral
  dmn=1
  
  if [[ ${BOUNDARY} = ${LOWER} ]]; then 
    # create working directory and cd into it
    work_root=${work_root}/lower_bdy_update/ens_${memid}
    mkdir -p ${work_root}
    cmd="cd ${work_root}"
    echo ${cmd}
    eval ${cmd}
    
    # Remove IC/BC in the directory if old data present
    rm -f wrfout_*
    rm -f wrfinput_d0*
  
    if [ ${ens_loop} -eq 0 ]; then 
      # control background sourced from last cycle background
      bkg_dir=${CYCLE_HME}/bkg/ens_${memid}
      max_dom=${WRF_CTR_DOM}
    else
      # perturbation background sourced from ensemble root
      bkg_dir=${ENS_ROOT}/bkg/ens_${memid}
      max_dom=${WRF_ENS_DOM}
    fi

    # verify forecast data root
    if [ ! -d ${bkg_dir} ]; then
      echo "ERROR: \${bkg_dir} directory ${bkg_dir} does not exist."
      exit 1
    fi
    
    # Check to make sure the input files are available and copy them
    echo "Copying background and input files."
    while [ ${dmn} -le ${max_dom} ]; do
      # update the lower BC for the output file to pass to GSI
      wrfout=wrfout_d0${dmn}_${anl_iso}

      # wrfinput is always drawn from real step
      wrfinput=wrfinput_d0${dmn}
  
      if [ ! -r "${bkg_dir}/${wrfout}" ]; then
        echo "ERROR: Input file '${bkg_dir}/${wrfout}' is missing."
        exit 1
      else
        cmd="cp ${bkg_dir}/${wrfout} ./"
	echo ${cmd}; eval ${cmd}
	#NOTE FOR DEBUGGING
        exit 1
      fi
  
      if [ ! -r "${real_dir}/${wrfinput}" ]; then
        echo "ERROR: Input file '${real_dir}/${wrfinput}' is missing."
        exit 1
      else
        cmd="cp ${real_dir}/${wrfinput} ./"
	echo ${cmd}; eval ${cmd}
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cmd="cp ${EXP_CNFG}/namelists/parame.in ./"
      echo ${cmd}; eval ${cmd}
  
      # Update the namelist for the domain id 
      cat parame.in \
	 | sed "s/\(${DA}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfout}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in \
	 | sed "s/\(${WRF}_${INPUT}\)${EQUAL}.*/\1 = '\.\/${wrfinput}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in \
	 | sed "s/\(${DOMAIN}_${ID}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      # Update the namelist for lower boundary update 
      cat parame.in \
	 | sed "s/\(${UPDTE}_${LOW}_${BDY}\)${EQUAL}.*/\1 = \.true\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in \
	 | sed "s/\(${UPDTE}_${LATERAL}_${BDY}\)${EQUAL}.*/\1 = \.false\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      echo
      echo "ENS_N      = ${memid}"
      echo "BOUNDARY   = ${BOUNDARY}"
      echo "DOMAIN     = ${dmn}"
      echo "WRFDA_ROOT = ${WRFDA_ROOT}"
      echo "EXP_CNFG = ${EXP_CNFG}"
      echo "CYCLE_HME = ${CYCLE_HME}"
      echo "ENS_ROOT   = ${ENS_ROOT}"
      echo
      now=`date +%Y%m%d%H%M%S`
      echo "da_update_bc.exe started at ${now}."
      ${update_bc_exe}
  
      ##################################################################################
      # Run time error check
      ##################################################################################
      error=$?
      
      if [ ${error} -ne 0 ]; then
        echo "ERROR: ${update_bc_exe} exited with status ${error}."
        exit ${error}
      fi
      # move forward through domains
      (( dmn += 1 ))
    done
  
  else
    # create working directory and cd into it
    work_root=${work_root}/lateral_bdy_update/ens_${memid}
    mkdir -p ${work_root}
    cmd="cd ${work_root}"
    echo ${cmd}; eval ${cmd}
    
    # Remove IC/BC in the directory if old data present
    rm -f wrfout_*
    rm -f wrfinput_d0*
    rm -f wrfbdy_d01

    if [ ${ens_loop} -eq 0 ]; then
      if [ ! -d ${gsi_dir} ]; then
        echo "ERROR: \${gsi_dir} directory ${gsi_dir} does not exist."
        exit 1
      else
        wrfanl=${gsi_dir}/d01/wrfanl_ens_${memid}_${anl_iso}
      fi
    else
      if [ ! -d ${enkf_dir} ]; then
        echo "ERROR: \${enkf_dir} directory ${enkf_dir} does not exist."
        exit 1
      else
        # NOTE: ENKF SCRIPT NEED TO UPDATE OUTPUT NAMING CONVENTIONS
        wrfanl=${enkf_dir}/d01/wrfanl_ens_${memid}_${anl_iso}
      fi
    fi

    wrfbdy=${real_dir}/wrfbdy_d01
    wrfvar_outname=wrfanl_ens_${memid}_${anl_iso}
    wrfbdy_name=wrfbdy_d01
  
    if [ ! -r "${wrfanl}" ]; then
      echo "ERROR: Input file '${wrfanl}' is missing."
      exit 1
    else
      cmd="cp ${wrfanl} ${wrfvar_outname}"
      echo ${cmd}; eval ${cmd}
    fi
  
    if [ ! -r "${wrfbdy}" ]; then
      echo "ERROR: Input file '${wrfbdy}' is missing."
      exit 1
    else
      cmd="cp ${wrfbdy} ${wrfbdy_name}"
      echo ${cmd}; eval ${cmd}
    fi
  
    ##################################################################################
    #  Build da_update_bc namelist
    ##################################################################################
    # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
    cmd="cp ${EXP_CNFG}/namelists/parame.in ./"
    echo ${cmd}; eval ${cmd}
  
    # Update the namelist for the domain id 
    cat parame.in \
       | sed "s/\(${DA}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfvar_outname}'/" \
       > parame.in.new
    mv parame.in.new parame.in
  
    cat parame.in \
       | sed "s/\(${DOMAIN}_${ID}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
       > parame.in.new
    mv parame.in.new parame.in
  
    # Update the namelist for lower boundary update 
    cat parame.in \
       | sed "s/\(${WRF}_${BDY}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfbdy_name}'/" \
       > parame.in.new
    mv parame.in.new parame.in
  
    cat parame.in \
       | sed "s/\(${UPDATE}_${LOW}_${BDY}\)${EQUAL}.*/\1 = \.false\./" \
       > parame.in.new
    mv parame.in.new parame.in
  
    cat parame.in \
       | sed "s/\(${UPDATE}_${LATERAL}_${BDY}\)${EQUAL}.*/\1 = \.true\./" \
       > parame.in.new
    mv parame.in.new parame.in
  
    ##################################################################################
    # Run update_bc_exe
    ##################################################################################
    # Print run parameters
    echo
    echo "WRFDA_ROOT = ${WRFDA_ROOT}"
    echo "EXP_CNFG = ${EXP_CNFG}"
    echo "CYCLE_HME = ${CYCLE_HME}"
    echo "ENS_ROOT   = ${ENS_ROOT}"
    echo
    echo "BOUNDARY   = ${BOUNDARY}"
    echo "DOMAIN     = ${dmn}"
    echo "ENS_N      = ${ens_n}"
    echo
    now=`date +%Y%m%d%H%M%S`
    echo "da_update_bc.exe started at ${now}."
    ${update_bc_exe}
  
    ##################################################################################
    # Run time error check
    ##################################################################################
    error=$?
    
    if [ ${error} -ne 0 ]; then
      echo "ERROR: ${update_bc_exe} exited with status ${error}."
      exit ${error}
    fi
    
  fi

  (( ens_loop += 1 ))
done

echo "wrfda.sh completed successfully at `date`."

##################################################################################

exit 0
