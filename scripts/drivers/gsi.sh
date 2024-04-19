#!/bin/bash
##################################################################################
# Description
##################################################################################
# This driver script is a major fork and rewrite of the standard GSI.ksh
# driver script for the GSI tutorial:
#
#   https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with WRF for data denial experiments.
# Naming conventions in this script have been smoothed to match a companion major
# fork of the wrf.ksh WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.sh script to be sourced in the below.
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
# Options below are hard-coded based on the type of experiment
# (i.e., these not expected to change within DA cycles).
#
# if_clean   = Yes : delete temporal files in working directory (default)
#              No  : leave running directory as is (this is for debug only)
# if_oneob   = Yes : Do single observation test
# grid_ratio = 1 default, still testing option for dual resolution
#
##################################################################################
# uncomment to run verbose for debugging / testing
#set -x

# Background error set for WRF-ARW by default
bk_core_arw=".true."
bk_core_nmm=".false."
bk_core_nmmb=".false."
bk_if_netcdf=".true."
if_gfs_nemsio=".false."

# workflow debug settings
if_clean=Yes
if_oneob=No

# In testing, not determined if can be used effectively
grid_ratio=1

# Read constants into the current shell
if [ ! -x ${CNST} ]; then
  printf "ERROR: constants file\n ${CNST}\n does not exist or is not executable.\n"
  exit 1
else
  # Read constants into the current shell
  cmd=". ${CNST}"
  printf "${cmd}\n"; eval ${cmd}
fi

##################################################################################
# Make checks for DA method settings
##################################################################################
# Options below are defined in control flow xml (case insensitive)
#
# ANL_DT      = Analysis time YYYYMMDDHH
# CYC_HME     = Start time named directory for cycling data containing
#               bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# IF_OBSERVER = Yes : Only used as observation operator for ensemble members
#             = No  : Analyzes control solution
# WRF_CTR_DOM = Analyze up to domain index format DD of control solution
# IF_HYBRID   = Yes : Run GSI with ensemble, required for IF_OBSERVER = Yes
# N_ENS       = Max ensemble pertubation index
# WRF_ENS_DOM = Utilize ensemble perturbations up to domain index DD
# BETA        = Scaling float in [0,1], 0 - full ensemble, 1 - full static
# S_ENS_H     = Homogeneous isotropic horizontal ensemble localization scale (km) 
# S_ENS_V     = Vertical localization scale (grid units)
# MAX_BC_LOOP = Maximum number of times to iteratively generate variational bias
#               correction files, loop zero starts with GDAS defaults
# IF_4DENVAR  = Yes : Run GSI as 4D EnVar
#
##################################################################################

# Convert ANL_DT from 'YYYYMMDDHH' format to anl_iso Unix date format
if [ ${#ANL_DT} -ne 10 ]; then
  printf "ERROR: \${ANL_DT}, ${ANL_DT}, is not in 'YYYYMMDDHH' format.\n"
  exit 1
else
  # define anl date components separately
  anl_date=${ANL_DT:0:8}
  hh=${ANL_DT:8:2}

  # Define file path name variable anl_iso from ANL_DT
  anl_iso=`date +%Y-%m-%d_%H_%M_%S -d "${anl_date} ${hh} hours"`
fi

if [ ! ${CYC_HME} ]; then
  printf "ERROR: \${CYC_HME} is not defined.\n"
  exit 1
elif [ ! -d "${CYC_HME}" ]; then
  printf "ERROR: \${CYC_HME} directory\n ${CYC_HME}\n does not exist.\n"
  exit 1
fi

if [[ ${IF_OBSERVER} = ${NO} ]]; then
  if [ ${#WRF_CTR_DOM} -ne 2 ]; then
    printf "ERROR: \${WRF_CTR_DOM}\n ${WRF_CTR_DOM}\n is not in DD format.\n"
    exit 1
  else
    printf "GSI updates control forecast.\n"
    nummiter=2
    if_read_obs_save=".false."
    if_read_obs_skip=".false."
    work_root=${CYC_HME}/gsiprd
    max_dom=${WRF_CTR_DOM}
  fi
elif [[ ${IF_OBSERVER} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    printf "ERROR: \${IF_HYBRID} must equal Yes if \${IF_OBSERVER} = Yes.\n"
    exit 1
  fi
  printf "GSI is observer for EnKF ensemble.\n"
  nummiter=0
  if_read_obs_save=".true."
  if_read_obs_skip=".false."
  work_root=${CYC_HME}/enkfprd
  max_dom=${WRF_ENS_DOM}
else
  printf "ERROR: \${IF_OBSERVER} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${IF_HYBRID} = ${YES} ]]; then
  # ensembles are required for hybrid EnVAR
  if [ ${#WRF_ENS_DOM} -ne 2 ]; then
    printf "ERROR: \${WRF_ENS_DOM} is not in DD format.\n"
    exit 1
  elif [ ! ${N_ENS} ]; then
    msg="ERROR: \${N_ENS} must be specified to the number "
    msg+="of ensemble perturbations.\n"
    printf "${msg}"
    exit 1
  elif [ ${N_ENS} -lt 2 ]; then
    printf "ERROR: ensemble size \${N_ENS} + 1 must be three or greater.\n"
    exit 1
  elif [ ! ${BETA} ]; then
    msg="ERROR: \${BETA} must be specified to the weight "
    msg+="between ensemble and static covariance.\n"
    printf "${msg}"
    exit 1
  elif [[ $(echo "${BETA} < 0" | bc -l ) -eq 1 || $(echo "${BETA} > 1" | bc -l ) -eq 1 ]]; then
    printf "ERROR:\n ${BETA}\n must be between 0 and 1.\n"
    exit 1
  else
    printf "GSI performs hybrid ensemble variational DA with ensemble size ${N_ENS}.\n"
    printf "Background covariance weight ${BETA}.\n"
    ifhyb=".true."
  fi
elif [[ ${IF_HYBRID} = ${NO} ]]; then
  printf "GSI performs variational DA without ensemble.\n"
  ifhyb=".false."
else
  printf "ERROR: \${IF_HYBRID} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

# create a sequence of member ids
mem_list=`seq -f "%02g" 1 ${N_ENS}`

if [ ! ${S_ENS_V} ]; then
  msg="ERROR: \${S_ENS_V} must be specified to the length of vertical "
  msg+="localization scale in grid units.\n"
  printf "${msg}"
  exit 1
  if [ ${S_ENS_V} -lt 0 ]; then
    printf "ERROR:\n ${S_ENS_V}\n must be greater than 0.\n"
    exit 1
  fi
fi

if [ ! ${S_ENS_H} ]; then
  msg="ERROR: \${S_ENS_H} must be specified to the length of horizontal "
  msg+="localization scale in km.\n"
  printf "${msg}"
  exit 1
  if [ ${S_ENS_H} -lt 0 ]; then
    printf "ERROR: ${S_ENS_H} must be greater than 0.\n"
    exit 1
  fi
fi

if [ ${#MAX_BC_LOOP} -ne 2 ]; then
  msg="ERROR: \${MAX_BC_LOOP} must be specified to the number of "
  msg+="variational bias correction iterations in format LL.\n"
  printf "${msg}"
  exit 1
elif [ ${MAX_BC_LOOP} -lt 0 ]; then
  msg="ERROR: the number of iterations of variational bias "
  msg+="correction must be non-negative.\n"
  printf "${msg}"
  exit 1
fi

if [[ ${IF_4DENVAR} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    printf "ERROR: \${IF_HYBRID} must equal Yes if \${IF_4DENVAR} = Yes.\n"
    exit 1
  else
    printf "GSI performs 4D hybrid ensemble variational DA.\n"
    if4d=".true."
  fi
elif [[ ${IF_4DENVAR} = ${NO} ]]; then
    if4d=".false."
else
  printf "ERROR: \${IF_4DENVAR} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

if [[ ${if_oneob} = ${YES} ]]; then
  printf "GSI performs single observation test.\n"
  if_oneobtest=".true."
elif [[ ${if_oneob} = ${NO} ]]; then
  if_oneobtest=".false."
else
  printf "ERROR: \${if_oneob} must equal 'Yes' or 'No' (case insensitive).\n"
  exit 1
fi

##################################################################################
# Define GSI workflow dependencies
##################################################################################
# Below variables are defined in cycling.xml workflow variables
#
# GSI_EXE   = Path of GSI executable
# CRTM_ROOT = Path of CRTM including byte order
# EXP_CNFG  = Root directory containing sub-directories for namelists
#             vtables, geogrid data, GSI fix files, etc.
# DATA_ROOT = Directory for all forcing data files, including grib files,
#             obs files, etc.
# ENS_ROOT  = Background ensemble located at ${ENS_ROOT}/ens_${ens_n}/wrfout* 
# MPIRUN    = MPI Command to execute GSI
# N_PROC    = Number of workers for MPI command to exectute on
#
# Below variables are derived from control flow variables for convenience
#
# anl_iso   = Defined by the ANL_DT variable, to be used as path
#             name variable in iso format for wrfout
#
##################################################################################

if [ ! ${GSI_EXE} ]; then
  printf "ERROR: \${GSI_EXE} is not defined.\n"
  exit 1
elif [ ! -x ${GSI_EXE} ]; then
  printf "ERROR: GSI executable\n ${GSI_EXE}\n is not executable.\n"
  exit 1
fi

if [ ! ${CRTM_ROOT} ]; then
  printf "ERROR: \${CRTM_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${CRTM_ROOT} ]; then
  printf "ERROR: CRTM_ROOT directory\n ${CRTM_ROOT}\n does not exist.\n"
  exit 1
fi

if [ ! ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} is not defined.\n"
  exit 1
elif [ ! -d ${EXP_CNFG} ]; then
  printf "ERROR: \${EXP_CNFG} directory\n ${EXP_CNFG}\n does not exist.\n"
  exit 1
fi

if [ ! ${DATA_ROOT} ]; then
  printf "ERROR: \${DATA_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${DATA_ROOT} ]; then
  printf "ERROR: \${DATA_ROOT} directory\n ${DATA_ROOT}\n does not exist.\n"
  exit 1
fi

if [ ! ${ENS_ROOT} ]; then
  printf "ERROR: \${ENS_ROOT} is not defined.\n"
  exit 1
elif [ ! -d ${ENS_ROOT} ]; then
  printf "ERROR: \${ENS_ROOT} directory\n ${ENS_ROOT}\n does not exist.\n"
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
  msg="ERROR: The variable \${N_PROC} must be set to the "
  msg+="number of processors to run GSI > 0.\n"
  printf "${msg}"
  exit 1
fi

##################################################################################
# The following paths are relative to the control flow supplied root paths
#
# obs_root     = Path of observations files
# fix_root     = Path of fix files
# gsi_namelist = Path and name of the gsi namelist constructor script
# prepbufr_tar = Path of PreBUFR conventional obs tar archive
# prepbufr_dir = Path of PreBUFR conventional obs tar archive extraction
# satlist      = Path to text file listing satellite observation prefixes used,
#                required file, if empty will skip all satellite data.
#
##################################################################################
obs_root=${DATA_ROOT}/obs_data
fix_root=${EXP_CNFG}/fix
satlist=${fix_root}/satlist.txt
gsi_namelist=${EXP_CNFG}/namelists/comgsi_namelist.sh
prepbufr_tar=${obs_root}/prepbufr.${anl_date}.nr.tar.gz
prepbufr_dir=${obs_root}/${anl_date}.nr

if [ ! -d ${obs_root} ]; then
  printf "ERROR: \${obs_root} directory\n ${obs_root}\n does not exist.\n"
  exit 1
fi

if [ ! -d ${fix_root} ]; then
  printf "ERROR: fix file directory\n ${fix_root}\n does not exist.\n"
  exit 1
fi

if [ ! -r ${satlist} ]; then
  printf "ERROR: satellite namelist\n ${satlist}\n is not readable.\n"
  exit 1
fi

if [ ! -x ${gsi_namelist} ]; then
  printf "ERROR:\n ${gsi_namelist}\n is not executable.\n"
  exit 1
fi

if [ ! -r ${prepbufr_tar} ]; then
  printf "ERROR: prepbufr tar file\n ${prepbufr_tar}\n is not readable.\n"
  exit 1
else
  # untar prepbufr data to predefined directory
  # define prepbufr directory
  mkdir -p ${prepbufr_dir}
  cmd="tar -xvf ${prepbufr_tar} -C ${prepbufr_dir}"
  printf "${cmd}\n"; eval ${cmd}

  # unpack nested directory structure
  prepbufr_nest=(`find ${prepbufr_dir} -type f`)
  for file in ${prepbufr_nest[@]}; do
    cmd="mv ${file} ${prepbufr_dir}"
    printf "${cmd}\n"; eval ${cmd}
  done
  cmd="rmdir ${prepbufr_dir}/*"
  printf "${cmd}\n"; eval ${cmd}

  prepbufr=${prepbufr_dir}/prepbufr.gdas.${anl_date}.t${hh}z.nr
  if [ ! -r ${prepbufr} ]; then
    printf "ERROR: file\n ${prepbufr}\n is not readable.\n"
    exit 1
  fi
fi

##################################################################################
# Begin pre-GSI setup, running one domain at a time
##################################################################################
# Create the work directory organized by domain analyzed and cd into it
for dmn in `seq -f "%02g" 1 ${max_dom}`; do
  # NOTE: Hybrid DA uses the control forecast as the EnKF forecast mean, not the
  # control analysis. Work directory for GSI is sub-divided based on domain index
  dmndir=${work_root}/d${dmn}
  printf "Create work root directory\n ${dmndir}.\n"

  if [ -d "${dmndir}" ]; then
    printf "Existing GSI work root\n ${dmndir}\n removing old data for new run.\n"
    cmd="rm -rf ${dmndir}"
    printf "${cmd}\n"; eval ${cmd}
  fi
  mkdir -p ${dmndir}

  for bc_loop in `seq -f "%02g" 0 ${MAX_BC_LOOP}`; do
    # each domain will generated a variational bias correction file iteratively
    # starting with GDAS defaults
    cd ${dmndir}

    if [ ! ${bc_loop} = ${MAX_BC_LOOP} ]; then
      # create storage for the outputs indexed on bc_loop except for final loop
      workdir=${dmndir}/bc_loop_${bc_loop}
      mkdir ${workdir}
      cmd="cd ${workdir}"
      printf "${cmd}\n"; eval ${cmd}

    else
      workdir=${dmndir}
    fi

    printf "Variational bias correction update loop ${bc_loop}.\n"
    printf "Working directory\n ${workdir}\n"
    printf "Linking observation bufrs to working directory.\n"

    # Link to the prepbufr conventional data
    cmd="ln -s ${prepbufr} prepbufr"
    printf "${cmd}\n"; eval ${cmd}

    # Link to satellite data -- note satlist is assumed two column with prefix
    # for GDAS and GSI conventions in first and second column respectively
    # leave file empty for no satellite assimilation
    srcobsfile=()
    gsiobsfile=()

    satlines=$(cat ${satlist})
    line_indx=0
    for line in ${satlines}; do
      if [ $(( ${line_indx} % 2 )) -eq 0 ]; then
        srcobsfile+=(${line})
      else
        gsiobsfile+=(${line})      
      fi
      (( line_indx += 1 ))
    done

    # loop over obs types
    for (( ii=0; ii < ${#srcobsfile[@]}; ii++ )); do 
      cmd="cd ${obs_root}"
      printf "${cmd}\n"; eval ${cmd}

      tar_file=${obs_root}/${srcobsfile[$ii]}.${anl_date}.tar.gz
      obs_dir=${obs_root}/${anl_date}.${srcobsfile[$ii]}
      mkdir -p ${obs_dir}
      if [ ! -r "${tar_file}" ]; then
        printf "ERROR: file\n ${tar_file}\n not found.\n"
        exit 1
      else
        # untar to specified directory
        cmd="tar -xvf ${tar_file} -C ${obs_dir}"
        printf "${cmd}\n"; eval ${cmd}

        # unpack nested directory structure, if exists
        obs_nest=(`find ${obs_dir} -type f`)
        for file in ${obs_nest[@]}; do
          cmd="mv ${file} ${obs_dir}"
          printf "${cmd}\n"; eval ${cmd}
        done

        cmd="rmdir ${obs_dir}/*"
        printf "${cmd}\n"; eval ${cmd}

        # NOTE: differences in data file types for "satwnd"
        if [ ${srcobsfile[$ii]} = satwnd ]; then
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.txt
        else
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.bufr
        fi

        if [ ! -r "${obs_file}" ]; then
           printf "ERROR: obs file\n ${srcobsfile[$ii]}\n not found.\n"
           exit 1
        else
           printf "Link source obs file\n ${obs_file}\n"
           cmd="cd ${workdir}"
           printf "${cmd}\n"; eval ${cmd}
           cmd="ln -sf ${obs_file} ./${gsiobsfile[$ii]}"
           printf "${cmd}\n"; eval ${cmd}
        fi
      fi
      cd ${workdir}
    done


    #############################################################################
    # Set fix files in the order below:
    #
    #  berror             = Forecast model background error statistics
    #  oberror            = Conventional obs error file
    #  anavinfo           = Information file to set control and analysis variables
    #  specoef            = CRTM spectral coefficients
    #  trncoef            = CRTM transmittance coefficients
    #  emiscoef           = CRTM coefficients for IR sea surface emissivity model
    #  aerocoef           = CRTM coefficients for aerosol effects
    #  cldcoef            = CRTM coefficients for cloud effects
    #  satinfo            = Text file with information about assimilation of brightness temperatures
    #  satangl            = Angle dependent bias correction file (fixed in time)
    #  pcpinfo            = Text file with information about assimilation of prepcipitation rates
    #  ozinfo             = Text file with information about assimilation of ozone data
    #  errtable           = Text file with obs error for conventional data (regional only)
    #  convinfo           = Text file with information about assimilation of conventional data
    #  lightinfo          = Text file with information about assimilation of GLM lightning data
    #  atms_beamwidth.txt = Text file with information about assimilation of ATMS data
    #  bufrtable          = Text file ONLY needed for single obs test (oneobstest=.true.)
    #  bftab_sst          = Bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
    #
    ############################################################################

    srcfixfile=()
    gsifixfile=()

    printf "Copy fix files from\n ${fix_root}\n"
    # files should be named the following in ${fix_root}, can be linked to these names
    # from various source files / background error options
    srcfixfile+=( ${fix_root}/berror_stats )
    srcfixfile+=( ${fix_root}/errtable )
    srcfixfile+=( ${fix_root}/anavinfo )
    srcfixfile+=( ${fix_root}/satangbias.txt )
    srcfixfile+=( ${fix_root}/satinfo.txt )
    srcfixfile+=( ${fix_root}/convinfo.txt )
    srcfixfile+=( ${fix_root}/ozinfo.txt )
    srcfixfile+=( ${fix_root}/pcpinfo.txt )
    srcfixfile+=( ${fix_root}/lightinfo.txt )
    srcfixfile+=( ${fix_root}/atms_beamwidth.txt )

    # linked names for GSI to read in
    gsifixfile+=( berror_stats )
    gsifixfile+=( errtable )
    gsifixfile+=( anavinfo )
    gsifixfile+=( satbias_angle )
    gsifixfile+=( satinfo )
    gsifixfile+=( convinfo )
    gsifixfile+=( ozinfo )
    gsifixfile+=( pcpinfo )
    gsifixfile+=( lightinfo )
    gsifixfile+=( atms_beamwidth.txt )

    # loop over fix files
    printf "Copy fix files to working directory:\n"
    for (( ii=0; ii < ${#srcfixfile[@]}; ii++ )); do
      if [ ! -r ${srcfixfile[$ii]} ]; then
        printf "ERROR: GSI fix file\n ${srcfixfile[$ii]}\n not readable.\n"
        exit 1
      else
        cmd="cp -L ${srcfixfile[$ii]} ./${gsifixfile[$ii]}"
        printf "${cmd}\n"; eval ${cmd}
      fi
    done

    # CRTM Spectral and Transmittance coefficients
    coeffs=()
    coeffs+=( Nalli.IRwater.EmisCoeff.bin )
    coeffs+=( NPOESS.IRice.EmisCoeff.bin )
    coeffs+=( NPOESS.IRland.EmisCoeff.bin )
    coeffs+=( NPOESS.IRsnow.EmisCoeff.bin )
    coeffs+=( NPOESS.VISice.EmisCoeff.bin )
    coeffs+=( NPOESS.VISland.EmisCoeff.bin )
    coeffs+=( NPOESS.VISsnow.EmisCoeff.bin )
    coeffs+=( NPOESS.VISwater.EmisCoeff.bin )
    coeffs+=( FASTEM6.MWwater.EmisCoeff.bin )
    coeffs+=( AerosolCoeff.bin )
    coeffs+=( CloudCoeff.bin )

    # loop over coeffs 
    printf "Link CRTM coefficient files:\n"
    for (( ii=0; ii < ${#coeffs[@]}; ii++ )); do
      coeff_file=${CRTM_ROOT}/${coeffs[$ii]}
      if [ ! -r ${coeff_file} ]; then
        printf "ERROR: CRTM coefficient file\n ${coeff_file}\n not readable.\n"
        exit 1
      else
        cmd="ln -s ${coeff_file} ."
        printf "${cmd}\n"; eval ${cmd}
      fi
    done

    # Copy CRTM coefficient files based on entries in satinfo file
    for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
     satinfo_coeffs=()
     satinfo_coeffs+=( ${CRTM_ROOT}/${file}.SpcCoeff.bin )
     satinfo_coeffs+=( ${CRTM_ROOT}/${file}.TauCoeff.bin )
     for coeff_file in ${satinfo_coeffs[@]}; do
       if [ ! -r ${coeff_file} ]; then
         printf "ERROR: CRTM coefficient file\n ${coeff_file}\n not readable.\n"
       else
         cmd="ln -s ${coeff_file} ."
         printf "${cmd}\n"; eval ${cmd}
       fi
     done
    done

    if [[ ${if_oneob} = ${YES} ]]; then
      # Only need this file for single obs test
      bufrtable=${fix_root}/prepobs_prep.bufrtable
      cmd="cp -L ${bufrtable} ./prepobs_prep.bufrtable"
      printf "${cmd}\n"; eval ${cmd}
    fi

    if [ ${bc_loop} = 00 ]; then
      # first bias correction loop uses combined bias correction files from GDAS
      tar_files=()
      tar_files+=(${obs_root}/abias.${anl_date}.tar.gz)
      tar_files+=(${obs_root}/abiaspc.${anl_date}.tar.gz)

      bias_dirs=()
      bias_dirs+=(${obs_root}/${anl_date}.abias)
      bias_dirs+=(${obs_root}/${anl_date}.abiaspc)

      bias_files=()
      bias_files+=(${bias_dirs[0]}/gdas.abias.t${hh}z.${anl_date}.txt)
      bias_files+=(${bias_dirs[1]}/gdas.abiaspc.t${hh}z.${anl_date}.txt)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      for ii in {0..1}; do
        tar_file=${tar_files[$ii]}
        bias_dir=${bias_dirs[$ii]}
        bias_file=${bias_files[$ii]}
        if [ ! -r ${tar_file} ]; then
          printf "Tar\n ${tar_file}\n of GDAS bias corrections not readable.\n"
          exit 1
        else
          # untar to specified directory
          mkdir -p ${bias_dir}
          cmd="tar -xvf ${tar_file} -C ${bias_dir}"
          printf "${cmd}\n"; eval ${cmd}
        
          # unpack nested directory structure
          bias_nest=(`find ${bias_dir} -type f`)
          for file in ${bias_nest[@]}; do
            cmd="mv ${file} ${bias_dir}"
            printf "${cmd}\n"; eval ${cmd}
          done

          cmd="rmdir ${bias_dir}/*"
          printf "${cmd}\n"; eval ${cmd}
        
          if [ ! -r ${bias_file} ]; then
           printf "GDAS bias correction file not readable at\n ${bias_file}\n"
           exit 1
          else
            msg="Link the GDAS bias correction file ${bias_file} "
            msg+="for loop zero of analysis.\n"
            printf "${msg}"
                  
            cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
            printf "${cmd}\n"; eval ${cmd}
          fi
        fi
      done
    else
      # use the bias correction file generated on the last GSI loop 
      bias_files=()
      lag_loop=$(( ${bc_loop} - 1 ))
      lag_loop=`printf %02d ${lag_loop}`
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_out)
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_pc.out)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      for (( ii=0; ii < ${#tar_files[@]}; ii++ )); do
	      bias_file=${bias_files[$ii]}
        if [ ! -r "${bias_file}" ]; then
          printf "Bias file\n ${bias_file}\n variational bias corrections not readable.\n"
          exit 1
        else
          msg="Linking variational bias correction file "
	        msg+="${bias_file} from last analysis.\n"
	        printf "${msg}"

          cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
	        printf "${cmd}\n"; eval ${cmd}
        fi
      done
    fi

    ##################################################################################
    # Prep GSI background 
    ##################################################################################
    # Below are defined depending on the ${dmn} -le ${max_dom}
    #
    # bkg_file = Path and name of background file
    #
    ##################################################################################
    bkg_dir=${CYC_HME}/wrfdaprd/lower_bdy_update/ens_00
    bkg_file=${bkg_dir}/wrfout_d${dmn}_${anl_iso}

    if [ ! -r ${bkg_file} ]; then
      printf "ERROR: background file\n ${bkg_file}\n does not exist.\n"
      exit 1
    else
      printf "Copy background file to working directory.\n"
      # Copy over background field -- THIS IS MODIFIED BY GSI DO NOT LINK TO IT
      cmd="cp -L ${bkg_file} wrf_inout"
      printf "${cmd}\n"; eval ${cmd}
    fi

    # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
    #if [[ ${IF_4DENVAR} = ${YES} ]] ; then
    # PDYa=`echo ${ANL_DT} | cut -c1-8`
    # cyca=`echo ${ANL_DT} | cut -c9-10`
    # gdate=`date -u -d "${PDYa} ${cyca} -6 hour" +%Y%m%d%H` #guess date is 6hr ago
    # gHH=`echo ${gdate} |cut -c9-10`
    # datem1=`date -u -d "${PDYa} ${cyca} -1 hour" +%Y-%m-%d_%H_%M_%S` #1hr ago
    # datep1=`date -u -d "${PDYa} ${cyca} 1 hour"  +%Y-%m-%d_%H_%M_%S`  #1hr later
    #  bkg_file_p1=${bkg_root}/wrfout_d${dmn}_${datep1}
    #  bkg_file_m1=${bkg_root}/wrfout_d${dmn}_${datem1}
    #fi

    ##################################################################################
    # Prep GSI ensemble 
    ##################################################################################

    if [[ ${IF_HYBRID} = ${YES} ]]; then
      if [ ${dmn} -le ${WRF_ENS_DOM} ]; then
        # copy WRF ensemble members
        printf " Copy ensemble perturbations to working directory.\n"
        for memid in ${mem_list[@]}; do
          ens_file=${ENS_ROOT}/bkg/ens_${memid}/wrfout_d${dmn}_${anl_iso}
          if [ !-r ${ens_file} ]; then
            printf "ERROR: ensemble file\n ${ens_file}\n does not exist.\n"
            exit 1
          else
            cmd="ln -sfr ${ens_file} ./wrf_ens_${memid}"
            printf "${cmd}\n"; eval ${cmd}
          fi
        done
        
        cmd="ls ./wrf_ens_* > filelist02"
        printf "${cmd}\n"; eval ${cmd}

        # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
        #if [[ ${IF_4DENVAR} = ${YES} ]]; then
        #  cp ${bkg_file_p1} ./wrf_inou3
        #  cp ${bkg_file_m1} ./wrf_inou1
        #  ls ${ENSEMBLE_FILE_mem_p1}* > filelist03
        #  ls ${ENSEMBLE_FILE_mem_m1}* > filelist01
        #fi

      else
        # run simple 3D-VAR without an ensemble 
        printf "WARNING:\n"
        printf "Dual resolution ensemble perturbations and control are not an option yet.\n"
        printf "Running nested domain d${dmn} as simple 3D-VAR update.\n"
        ifhyb=".false."
      fi

      # define namelist ensemble size
      nummem=${N_ENS}
    fi

    ##################################################################################
    # Build GSI namelist
    ##################################################################################
    printf "Build the namelist with parameters for NAM-ARW.\n"

    # default parameers taken from NAM
    vs_op='1.0,'
    hzscl_op='0.373,0.746,1.50,'

    # Build the GSI namelist on-the-fly
    cmd=". ${gsi_namelist}"
    printf "${cmd}\n"; eval ${cmd}

    # modify the anavinfo vertical levels based on wrf_inout for WRF ARW and NMM
    bklevels=`ncdump -h wrf_inout | grep "bottom_top =" | awk '{print $3}' `
    bklevels_stag=`ncdump -h wrf_inout | grep "bottom_top_stag =" | awk '{print $3}' `
    anavlevels=`cat anavinfo | grep ' sf ' | tail -1 | awk '{print $2}' ` # levels of sf, vp, u, v, t...
    anavlevels_stag=`cat anavinfo | grep ' prse ' | tail -1 | awk '{print $2}' `  # levels of prse
    sed -i 's/ '${anavlevels}'/ '${bklevels}'/g' anavinfo
    sed -i 's/ '${anavlevels_stag}'/ '${bklevels_stag}'/g' anavinfo

    ##################################################################################
    # Run GSI
    ##################################################################################
    # Print run parameters
    printf "\n"
    printf "ANL_DT      = ${ANL_DT}\n"
    printf "BKG         = ${bkg_file}\n"
    printf "IF_OBSERVER = ${IF_OBSERVER}\n"
    printf "IF_HYBRID   = ${IF_HYBRID}\n"
    printf "ENS_ROOT    = ${ENS_ROOT}\n"
    printf "BETA        = ${BETA}\n"
    printf "S_ENS_V     = ${S_ENS_V}\n"
    printf "S_ENS_H     = ${S_ENS_H}\n"
    printf "IF_4DENVAR  = ${IF_4DENVAR}\n"
    printf "\n"
    now=`date +%Y-%m-%d_%H_%M_%S`
    printf "gsi analysis started at ${now} on domain d${dmn}.\n"
    cmd="${MPIRUN} -n ${N_PROC} ${GSI_EXE} > stdout.anl.${anl_iso} 2>&1"
    printf "${cmd}\n"; eval ${cmd}

    ##################################################################################
    # Run time error check
    ##################################################################################
    error=$?

    if [ ${error} -ne 0 ]; then
      printf "ERROR:\n ${GSI_EXE}\n exited with status ${error}.\n"
      exit ${error}
    fi

    # Copy the output to cycling naming convention
    cmd="mv wrf_inout wrfanl_ens_00_${anl_iso}"
    printf "${cmd}\n"; eval ${cmd}

    ##################################################################################
    # Loop over first and last outer loops to generate innovation
    # diagnostic files for indicated observation types (groups)
    #
    # NOTE:  Since we set miter=2 in GSI namelist SETUP, outer
    #        loop 03 will contain innovations with respect to
    #        the analysis.  Creation of o-a innovation files
    #        is triggered by write_diag(3)=.true.  The setting
    #        write_diag(1)=.true. turns on creation of o-g
    #        innovation files.
    #
    ##################################################################################

    loops="01 03"
    for loop in ${loops}; do
      case ${loop} in
        01) string=ges;;
        03) string=anl;;
         *) string=${loop};;
      esac

      ##################################################################################
      #  Collect diagnostic files for obs types (groups) below
      #   listall="conv amsua_metop-a mhs_metop-a hirs4_metop-a hirs2_n14 msu_n14 \
      #          sndr_g08 sndr_g10 sndr_g12 sndr_g08_prep sndr_g10_prep sndr_g12_prep \
      #          sndrd1_g08 sndrd2_g08 sndrd3_g08 sndrd4_g08 sndrd1_g10 sndrd2_g10 \
      #          sndrd3_g10 sndrd4_g10 sndrd1_g12 sndrd2_g12 sndrd3_g12 sndrd4_g12 \
      #          hirs3_n15 hirs3_n16 hirs3_n17 amsua_n15 amsua_n16 amsua_n17 \
      #          amsub_n15 amsub_n16 amsub_n17 hsb_aqua airs_aqua amsua_aqua \
      #          goes_img_g08 goes_img_g10 goes_img_g11 goes_img_g12 \
      #          pcp_ssmi_dmsp pcp_tmi_trmm sbuv2_n16 sbuv2_n17 sbuv2_n18 \
      #          omi_aura ssmi_f13 ssmi_f14 ssmi_f15 hirs4_n18 amsua_n18 mhs_n18 \
      #          amsre_low_aqua amsre_mid_aqua amsre_hig_aqua ssmis_las_f16 \
      #          ssmis_uas_f16 ssmis_img_f16 ssmis_env_f16 mhs_metop_b \
      #          hirs4_metop_b hirs4_n19 amusa_n19 mhs_n19 goes_glm_16"
      ##################################################################################

      listall=`ls pe* | cut -f2 -d"." | awk '{print substr($0, 0, length($0)-3)}' | sort | uniq `
      for type in ${listall}; do
         count=`ls pe*${type}_${loop}* | wc -l`
         if [[ ${count} -gt 0 ]]; then
            cat pe*${type}_${loop}* > diag_${type}_${string}.${anl_iso}
         fi
      done
    done

    #  Clean working directory to save only important files
    ls -l * > list_run_directory

    if [[ ${if_clean} = ${YES} && ${IF_OBSERVER} = ${NO} ]]; then
      printf "Clean working directory after GSI run.\n"
      rm -f *Coeff.bin     # all CRTM coefficient files
      rm -f pe0*           # diag files on each processor
      rm -f obs_input.*    # observation middle files
      rm -f siganl sigf0?  # background middle files
      rm -f fsize_*        # delete temporal file for bufr size
    fi

    ##################################################################################
    # Calculate diag files for each member if EnKF observer
    ##################################################################################

    if [[ ${IF_OBSERVER} = ${YES} ]]; then
      string=ges
      for type in ${listall}; do
        if [[ -f diag_${type}_${string}.${anl_iso} ]]; then
           cmd="mv diag_${type}_${string}.${anl_iso} diag_${type}_${string}.ensmean"
           printf "${cmd}\n"; eval ${cmd}
        fi
      done
      cmd="cp -L wrfanl_ens_00_${anl_iso} wrf_inout_ensmean"
      printf "${cmd}\n"; eval ${cmd}

      # Build the GSI namelist on-the-fly for each member
      if_read_obs_save=".false."
      if_read_obs_skip=".true."
      cmd=". ${gsi_namelist}"
      printf "${cmd}\n"; eval ${cmd}

      # Loop through each member
      loop=01
      for memid in ${mem_list[@]}; do
        rm pe0*
        # get new background for each member
        if [[ -f wrf_inout ]]; then
          rm wrf_inout
        fi

        ens_file=wrf_ens_${memid}
        printf "Copying ${ens_file} for GSI observer.\n"
        cmd="cp -L ${ens_file} wrf_inout"
        printf "${cmd}\n"; eval ${cmd}

        # run GSI
        printf "Run GSI observer for member ${memid}.\n"
        cmd="${MPIRUN} ${GSI_EXE} > stdout_ens_${memid}.anl.${anl_iso} 2>&1"
	      printf "${cmd}\n"; eval ${cmd}

        # run time error check and save run time file status
        error=$?

        if [ ${error} -ne 0 ]; then
          printf "ERROR:\n ${GSI_EXE}\n exited with status ${error} for member ${memid}.\n"
          exit ${error}
        fi

        cmd="ls -l * > list_run_directory_mem${memid}"
        printf "${cmd}\n"; eval ${cmd}

        # generate diag files
        for type in ${listall}; do
          count=`ls pe*${type}_${loop}* | wc -l`
          if [[ ${count} -gt 0 ]]; then
            cmd="cat pe*${type}_${loop}* > diag_${type}_${string}.mem${memid}"
            printf "${cmd}\n"; eval ${cmd}
          fi
        done
      done
    fi
  done 
done

printf "gsi.sh completed successfully at `date +%Y-%m-%d_%H_%M_%S`.\n"

##################################################################################

exit 0
