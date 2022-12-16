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
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
##################################################################################
# uncomment to run verbose for debugging / testing
set -x

##################################################################################
# Read in WRF constants for local environment
##################################################################################

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: ${CONSTANT} does not exist or is not executable"
  exit 1
fi

# Read constants into the current shell
. ${CONSTANT}

##################################################################################
# Make checks for WRFDA settings
##################################################################################
# Options below are defined in cycling.xml
#
# N_ENS             = Max ensemble index (use 00 for control alone)
# ANL_TIME          = Analysis time YYYYMMDDHH
# IF_ENS_COLD_START = Skip lower / lateral BC updates if "Yes"
# IF_LOWER          = 'Yes' if updating lower boundary conditions 
#                     'No' if updating lateral boundary conditions
# WRF_CTR_DOM       = Max domain index of control forecast
# WRF_ENS_DOM       = Max domain index of ensemble perturbations
#
# Below variabs are derived by cycling.xml variables for convenience
#
# date_str          = Defined by the ANL_TIME variable, to be used as path
#                     name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
##################################################################################

if [ ! "${N_ENS}" ]; then
  echo "ERROR: \$N_ENS is not defined!"
  exit 1
fi

if [ ! "${ANL_TIME}" ]; then
  echo "ERROR: \$ANL_TIME is not defined!"
  exit 1
fi

hh=`echo ${ANL_TIME} | cut -c9-10`
anal_date=`echo ${ANL_TIME} | cut -c1-8`
date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anal_date} ${hh} hours"`

if [ -z "${date_str}"]; then
  echo "ERROR: \$date_str is not defined correctly, check format of \$ANL_TIME!"
  exit 1
fi

if [[ ${IF_ENS_COLD_START} != ${YES} && ${IF_ENS_COLD_START} != ${NO} ]]; then
  echo "ERROR: \$IF_ENS_COLD_START must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_LOWER} != ${YES} && ${IF_LOWER} != ${NO} ]]; then
  echo "ERROR: \$IF_LOWER must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [ ! ${WRF_CTR_DOM} ]; then
  echo "ERROR: \$WRF_CTR_DOM is not defined!"
  exit 1
fi

if [ ! ${WRF_ENS_DOM} ]; then
  echo "ERROR: \$WRF_ENS_DOM is not defined!"
  exit 1
fi

##################################################################################
# Define REAL workflow dependencies
##################################################################################
# Below variables are defined in cycling.xml workflow variables
#
# WRFDA_ROOT     = Root directory of a WRFDA build 
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Start time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
#
##################################################################################

if [ ! "${WRFDA_ROOT}" ]; then
  echo "ERROR: \$WRFDA_ROOT is not defined"
  exit 1
fi

if [ ! -d "${WRFDA_ROOT}" ]; then
  echo "ERROR: WRFDA_ROOT directory ${WRFDA_ROOT} does not exist"
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

##################################################################################
# Begin pre-WRFDA setup
##################################################################################
# The following paths are relative to cycling.xml supplied root paths
#
# work_root      = Working directory where da_update_bc.exe runs and outputs updated files
# gsi_dir        = Working directory where GSI produces control analysis in the current cycle
# enkf_dir       = Working directory where EnKF produces the analysis ensemble perturbations
# real_dir       = Working directory real.exe runs and outputs IC and BC files for the current cycle
# bkg_dir        = Working directory with forecast data from WRF linked for the current cycle
# update_bc_exe  = Path and name of the update executable
#
##################################################################################

if [[ ${IF_ENS_COLD_START} = ${YES} ]]; then
  # skip the boundary updates for the ensemble, perform on control alone
  n_ens=0
else
  # perform over the entire ensemble
  n_ens=`printf $(( 10#${N_ENS} ))`
fi

ens_n=0

while [ ${ens_n} -le ${n_ens} ]; do
  # define two zero padded string for GEFS 
  iimem=`printf %02d $(( 10#${ens_n} ))`

  # define three zero padded string for GSI
  iiimem=`printf %03d $(( 10#${ens_n} ))`
  
  work_root=${INPUT_DATAROOT}/wrfdaprd/ens_${iimem}
  gsi_dir=${INPUT_DATAROOT}/gsiprd
  enkf_dir=${INPUT_DATAROOT}/enkfprd
  real_dir=${INPUT_DATAROOT}/realprd/ens_${iimem}
  bkg_dir=${INPUT_DATAROOT}/bkg/ens_${iimem}
  update_bc_exe=${WRFDA_ROOT}/var/da/da_update_bc.exe
  
  if [ ! -d ${real_dir} ]; then
    echo "ERROR: \$real_dir directory ${real_dir} does not exist"
    exit 1
  fi
  
  if [ ! -x ${update_bc_exe} ]; then
    echo "ERROR: ${update_bc_exe} does not exist, or is not executable"
    exit 1
  fi
  
  # create working directory and cd into it
  mkdir -p ${work_root}
  cd ${work_root}
  
  # Remove IC/BC in the directory if old data present
  rm -f wrfout_*
  rm -f wrfinput_d0*
  rm -f wrfbdy_d01
  
  # define domain variable to iterate on in lower boundary, fixed in lateral
  dmn=1
  
  if [[ ${IF_LOWER} = ${YES} ]]; then 

    if [ ! -d ${bkg_dir} ]; then
      echo "ERROR: \$bkg_dir directory ${bkg_dir} does not exist"
      exit 1
    fi
    
    if [ ${ens_n} -eq 0 ]; then 
      max_dom=${WRF_CTR_DOM}
    else
      max_dom=${WRF_ENS_DOM}
    fi

    # Check to make sure the input files are available and copy them
    while [ ${dmn} -le ${max_dom} ]; do
      # update the lower BC for the output file to pass to GSI
      wrfout=wrfout_d0${dmn}_${date_str}

      # wrfinput is always drawn from real step
      wrfinput=wrfinput_d0${dmn}
  
      if [ ! -r "${bkg_dir}/${wrfout}" ]; then
        echo "ERROR: Input file '${wrfout}' is missing"
        exit 1
      else
        cp ${bkg_dir}/${wrfout} ./
      fi
  
      if [ ! -r "${real_dir}/${wrfnput}" ]; then
        echo "ERROR: Input file '${wrfinput}' is missing"
        exit 1
      else
        cp ${real_dir}/${wrfinput} ./
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cp ${STATIC_DATA}/namelists/parame.in ./
  
      # Update the namelist for the domain id 
      cat parame.in | sed "s/\(${DA}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfout}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${WRF}_${INPUT}\)${EQUAL}.*/\1 = '\.\/${wrfinput}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${DOMAIN}_${ID}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      # Update the namelist for lower boundary update 
      cat parame.in | sed "s/\(${UPDATE}_${LOW}_${BDY}\)${EQUAL}.*/\1 = \.true\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${UPDATE}_${LATERAL}_${BDY}\)${EQUAL}.*/\1 = \.false\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      echo
      echo "ENS_N          = ${iimem}"
      echo "WRFDA_ROOT     = ${WRFDA_ROOT}"
      echo "STATIC_DATA    = ${STATIC_DATA}"
      echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
      echo
      echo "IF_LOWER       = ${IF_LOWER}"
      echo "DOMAIN         = ${dmn}"
      echo "ENS_N          = ${ens_n}"
      echo
      now=`date +%Y%m%d%H%M%S`
      echo "da_update_bc.exe started at ${now}"
      ${update_bc_exe}
  
      ##################################################################################
      # Run time error check
      ##################################################################################
      error=$?
      
      if [ ${error} -ne 0 ]; then
        echo "ERROR: ${update_bc_exe} exited with status ${error}"
        exit ${error}
      fi
  
      # save the files where they can be accessed for GSI analysis
      lower_bdy_data=${work_root}/lower_bdy_update
      mkdir -p ${lower_bdy_data}
      mv ${wrfout} ${lower_bdy_data}/${wrfout}
      mv ${wrfinput} ${lower_bdy_data}/${wrfinput}
      mv parame.in ${lower_bdy_data}/parame.in_d0${dmn} 
  
      # move forward through domains
      (( dmn += 1 ))
    done
  
  else
    if [ ${ens_n} -eq 0 ]; then
      if [ ! -d ${gsi_dir} ]; then
        echo "ERROR: \$gsi_dir directory ${gsi_dir} does not exist"
        exit 1
      fi

      wrfanl=${gsi_dir}/d01/wrfanl_ens_00.${ANL_TIME}
      wrfbdy=${real_dir}/wrfbdy_d01
      wrfvar_outname=wrfvar_output
      wrfbdy_name=wrfbdy_d01
  
      if [ ! -r "${wrfanl}" ]; then
        echo "ERROR: Input file '${wrfanl}' is missing"
        exit 1
      else
        cp ${wrfanl} ${wrfvar_outname}
      fi
  
      if [ ! -r "${wrfbdy}" ]; then
        echo "ERROR: Input file '${wrfbdy}' is missing"
        exit 1
      else
        cp ${wrfbdy} ${wrfbdy_name} 
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cp ${STATIC_DATA}/namelists/parame.in ./
  
      # Update the namelist for the domain id 
      cat parame.in | sed "s/\(${DA}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfvar_outname}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${DOMAIN}_${ID}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      # Update the namelist for lower boundary update 
      cat parame.in | sed "s/\(${WRF}_${BDY}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfbdy_name}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${UPDATE}_${LOW}_${BDY}\)${EQUAL}.*/\1 = \.false\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${UPDATE}_${LATERAL}_${BDY}\)${EQUAL}.*/\1 = \.true\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      echo
      echo "WRFDA_ROOT     = ${WRFDA_ROOT}"
      echo "STATIC_DATA    = ${STATIC_DATA}"
      echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
      echo
      echo "IF_LOWER       = ${IF_LOWER}"
      echo "DOMAIN         = ${dmn}"
      echo "ENS_N          = ${ens_n}"
      echo
      now=`date +%Y%m%d%H%M%S`
      echo "da_update_bc.exe started at ${now}"
      ${update_bc_exe}
  
      ##################################################################################
      # Run time error check
      ##################################################################################
      error=$?
      
      if [ ${error} -ne 0 ]; then
        echo "ERROR: ${update_bc_exe} exited with status ${error}"
        exit ${error}
      fi
  
      # save the files where they can be accessed for new WRF forecast
      lateral_bdy_data=${work_root}/lateral_bdy_update
      mkdir -p ${lateral_bdy_data}
      mv wrfvar_output ${lateral_bdy_data}/
      mv wrfbdy_d01 ${lateral_bdy_data}/
      mv parame.in ${lateral_bdy_data}/parame.in_d0${dmn} 
      mv fort.* ${lateral_bdy_data}/

    else
      if [ ! -d ${enkf_dir} ]; then
        echo "ERROR: \$enkf_dir directory ${enkf_dir} does not exist"
        exit 1
      fi

      wrfanl=${enkf_dir}/d01/analysis.mem${iiimem}
      wrfbdy=${real_dir}/wrfbdy_d01
      wrfvar_outname=wrfvar_output
      wrfbdy_name=wrfbdy_d01
  
      if [ ! -r "${wrfanl}" ]; then
        echo "ERROR: Input file '${wrfanl}' is missing"
        exit 1
      else
        cp ${wrfanl} ${wrfvar_outname}
      fi
  
      if [ ! -r "${wrfbdy}" ]; then
        echo "ERROR: Input file '${wrfbdy}' is missing"
        exit 1
      else
        cp ${wrfbdy} ${wrfbdy_name} 
      fi
  
      ##################################################################################
      #  Build da_update_bc namelist
      ##################################################################################
      # Copy the namelist from the static dir -- THIS WILL BE MODIFIED DO NOT LINK TO IT
      cp ${STATIC_DATA}/namelists/parame.in ./
  
      # Update the namelist for the domain id 
      cat parame.in | sed "s/\(${DA}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfvar_outname}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${DOMAIN}_${ID}\)${EQUAL}[[:digit:]]\{1,\}/\1 = ${dmn}/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      # Update the namelist for lower boundary update 
      cat parame.in | sed "s/\(${WRF}_${BDY}_${FILE}\)${EQUAL}.*/\1 = '\.\/${wrfbdy_name}'/" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${UPDATE}_${LOW}_${BDY}\)${EQUAL}.*/\1 = \.false\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      cat parame.in | sed "s/\(${UPDATE}_${LATERAL}_${BDY}\)${EQUAL}.*/\1 = \.true\./" \
         > parame.in.new
      mv parame.in.new parame.in
  
      ##################################################################################
      # Run update_bc_exe
      ##################################################################################
      # Print run parameters
      echo
      echo "WRFDA_ROOT     = ${WRFDA_ROOT}"
      echo "STATIC_DATA    = ${STATIC_DATA}"
      echo "INPUT_DATAROOT = ${INPUT_DATAROOT}"
      echo
      echo "IF_LOWER       = ${IF_LOWER}"
      echo "DOMAIN         = ${dmn}"
      echo "ENS_N          = ${ens_n}"
      echo
      now=`date +%Y%m%d%H%M%S`
      echo "da_update_bc.exe started at ${now}"
      ${update_bc_exe}
  
      ##################################################################################
      # Run time error check
      ##################################################################################
      error=$?
      
      if [ ${error} -ne 0 ]; then
        echo "ERROR: ${update_bc_exe} exited with status ${error}"
        exit ${error}
      fi
  
      # save the files where they can be accessed for new WRF forecast
      lateral_bdy_data=${work_root}/lateral_bdy_update
      mkdir -p ${lateral_bdy_data}
      mv wrfvar_output ${lateral_bdy_data}/
      mv wrfbdy_d01 ${lateral_bdy_data}/
      mv parame.in ${lateral_bdy_data}/parame.in_d0${dmn} 
      mv fort.* ${lateral_bdy_data}/
    fi
  fi

  (( ens_n += 1 ))
done

echo "wrfda.sh completed successfully at `date`"

exit 0
