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
# Observation-Analysis-Forecast cycle with WRF for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the wrf.ksh
# WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.sh script to be sourced in the below.  Variable
# aliases in this script are based on conventions defined in the
# GSI_constants.sh and the control flow .xml driving this script.
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
# if_clean   = Yes : delete temporal files in working directory (default)
#              No  : leave running directory as is (this is for debug only)
# if_oneob   = Yes : Do single observation test
# grid_ratio = 1 default, still testing option for dual resolution
#
##################################################################################
# uncomment to run verbose for debugging / testing
set -x

# Background error set for WRF-ARW by default
bk_core_arw=".true."
bk_core_nmm=".false."
bk_core_nmmb=".false."
bk_if_netcdf=".true."
if_gfs_nemsio=".false."

# workflow debug settings
if_clean=clean
if_oneob=No

# In testing, not determined if can be used effectively
grid_ratio=1

# Read constants into the current shell
if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: \${CONSTANT} does not exist or is not executable."
  exit 1
fi

. ${CONSTANT}

##################################################################################
# Make checks for DA method settings
##################################################################################
# Options below are defined in control flow xml (case insensitive)
#
# WRF_CTR_DOM       = INT : GSI analyzes the control domain d0${dmn} for 
#                           dmn -le ${WRF_CTR_DOM}
# WRF_ENS_DOM       = INT : GSI utilizes ensemble perturbations on d0${dmn}
#                           for dmn -le ${WRF_ENS_DOM}
# IF_CTR_COLD_START = Yes : GSI analyzes wrfinput control file instead
#                           of wrfout control file
# IF_ENS_COLD_START = Yes : GSI uses ensemble perturbations from wrfinput files
#                           instead of wrfout files
#                     No  : GSI uses conventional data alone
#
# IF_HYBRID         = Yes : Run GSI as 3D/4D EnVAR
# IF_OBSERVER       = Yes : Only used as observation operator for EnKF
# N_ENS             = INT : Max ensemble index (00 for control alone)
#                           NOTE: this must be set when `IF_HYBRID=Yes` and
#                           when `IF_OBSERVER=Yes`
# MAX_BC_LOOP       = INT : Maximum number of times to iteratively generate
#                           variational bias correction files, loop zero starts
#                           with GDAS defaults
# IF_4DENVAR        = Yes : Run GSI as 4D EnVar
#
##################################################################################

if [ ! ${WRF_CTR_DOM} ]; then
  echo "ERROR: \${WRF_CTR_DOM} is not defined."
  exit 1
fi

if [ ! ${WRF_ENS_DOM} ]; then
  echo "ERROR: \${WRF_ENS_DOM} is not defined."
  exit 1
fi

if [[ ${IF_CTR_COLD_START} != ${YES} && ${IF_CTR_COLD_START} != ${NO} ]]; then
  msg="ERROR: \${IF_CTR_COLD_START} must equal "
  msg+="'Yes' or 'No' (case insensitive)."
  echo ${msg}
  exit 1
fi

if [[ ${IF_ENS_COLD_START} != ${YES} && ${IF_ENS_COLD_START} != ${NO} ]]; then
  echo "ERROR: \${IF_ENS_COLD_START} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${IF_OBSERVER} != ${YES} && ${IF_OBSERVER} != ${NO} ]]; then
  echo "ERROR: \${IF_OBSERVER} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${IF_HYBRID} = ${YES} ]]; then
  # ensembles are required for hybrid EnVAR
  if [ ! "${N_ENS}" ]; then
    msg="ERROR: \${N_ENS} must be specified to the number "
    msg+="of ensemble perturbations."
    echo
    exit 1
  fi
  if [ ${N_ENS} -lt 2 ]; then
    echo "ERROR: ensemble size \${N_ENS} + 1 must be three or greater."
    exit 1
  fi
  echo "GSI performs hybrid ensemble variational DA with ensemble size ${N_ENS}."
  ifhyb=".true."
elif [[ ${IF_HYBRID} = ${NO} ]]; then
  echo "GSI performs variational DA without ensemble."
  ifhyb=".false."
else
  echo "ERROR: \${IF_HYBRID} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${IF_OBSERVER} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    echo "ERROR: \${IF_HYBRID} must equal Yes if \${IF_OBSERVER} = Yes."
    exit 1
  fi
fi

if [ ! "${MAX_BC_LOOP}" ]; then
  msg="ERROR: \${MAX_BC_LOOP} must be specified to the number of "
  msg+="variational bias correction iterations."
  echo ${msg}
  exit 1
  if [ ${MAX_BC_LOOP} -lt 0 ]; then
    msg="ERROR: the number of iterations of variational bias "
    msg+="correction must be non-negative."
    echo ${msg}
    exit 1
  fi
fi

if [[ ${IF_4DENVAR} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    echo "ERROR: \${IF_HYBRID} must equal Yes if \${IF_4DENVAR} = Yes."
    exit 1
  else
    echo "GSI performs 4D hybrid ensemble variational DA."
    if4d=".true."
  fi
elif [[ ${IF_4DENVAR} = ${NO} ]]; then
    if4d=".false."
else
  echo "ERROR: \${IF_4DENVAR} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

if [[ ${if_oneob} = ${YES} ]]; then
  echo "GSI performs single observation test."
  if_oneobtest=".true."
elif [[ ${if_oneob} = ${NO} ]]; then
  if_oneobtest=".false."
else
  echo "ERROR: \${if_oneob} must equal 'Yes' or 'No' (case insensitive)."
  exit 1
fi

##################################################################################
# Define GSI workflow dependencies
##################################################################################
# Below variables are defined in cycling.xml workflow variables
#
# ANL_TIME   = Analysis time YYYYMMDDHH
# GSI_EXE    = Path of GSI executable
# CRTM_ROOT  = Path of CRTM including byte order
# EXP_CONFIG = Root directory containing sub-directories for namelists
#              vtables, geogrid data, GSI fix files, etc.
# CYCLE_HOME = Start time named directory for cycling data containing
#              bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd, enkfprd
# DATA_ROOT  = Directory for all forcing data files, including grib files,
#              obs files, etc.
# MPIRUN     = MPI Command to execute GSI
# GSI_PROC   = Number of workers for MPI command to exectute on
#
# Below variables are derived by cycling.xml variables for convenience
#
# date_str   = Defined by the ANL_TIME variable, to be used as path
#              name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
##################################################################################

if [ ! "${ANL_TIME}" ]; then
  echo "ERROR: \${ANL_TIME} is not defined."
  exit 1
fi

# Convert ANL_TIME from 'YYYYMMDDHH' format to start_time Unix date format
if [ ${#ANL_TIME} -ne 10 ]; then
  echo "ERROR: start time, '${ANL_TIME}', is not in 'yyyymmddhh' format."
  exit 1
else
  # Define directory path name variable date_str=YYMMDDHH from ANL_TIME
  hh=${ANL_TIME:8:2}
  anl_date=${ANL_TIME:0:8}
  date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anl_date} ${hh} hours"`
fi

if [ ! "${GSI_EXE}" ]; then
  echo "ERROR: \${GSI_EXE} is not defined."
  exit 1
fi

if [ ! -x "${GSI_EXE}" ]; then
  echo "ERROR: ${GSI_EXE} is not executable."
  exit 1
fi

if [ ! "${CRTM_ROOT}" ]; then
  echo "ERROR: \${CRTM_ROOT} is not defined."
  exit 1
fi

if [ ! -d "${CRTM_ROOT}" ]; then
  echo "ERROR: CRTM_ROOT directory ${CRTM_ROOT} does not exist."
  exit 1
fi

if [ ! ${EXP_CONFIG} ]; then
  echo "ERROR: \${EXP_CONFIG} is not defined."
  exit 1
fi

if [ ! -d ${EXP_CONFIG} ]; then
  echo "ERROR: \${EXP_CONFIG} directory ${EXP_CONFIG} does not exist."
  exit 1
fi

if [ ! "${CYCLE_HOME}" ]; then
  echo "ERROR: \${CYCLE_HOME} is not defined."
  exit 1
fi

if [ ! -d "${CYCLE_HOME}" ]; then
  echo "ERROR: \${CYCLE_HOME} directory ${CYCLE_HOME} does not exist."
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \${MPIRUN} is not defined."
  exit 1
fi

if [ ! "${GSI_PROC}" ]; then
  echo "ERROR: \${GSI_PROC} is not defined."
  exit 1
fi

if [ -z "${GSI_PROC}" ]; then
  msg="ERROR: The variable \${GSI_PROC} must be set to the "
  msg+="number of processors to run GSI."
  echo 
  exit 1
fi

##################################################################################
# The following paths are relative to the control flow supplied root paths
#
# work_root    = Working directory where GSI runs, either to analyze the control
#                as the observer for EnKF
# bkg_root     = Path for root directory of control from WRFDA or real, depending
#                on cycling settings
# obs_root     = Path of observations files
# fix_root     = Path of fix files
# gsi_namelist = Path and name of the gsi namelist constructor script
# prepbufr     = Path of PreBUFR conventional obs
# satlist      = Path to text file listing satellite observation prefixes used,
#                required file, if empty will skip all satellite data.
#
##################################################################################

if [[ ${IF_OBSERVER} = ${NO} ]]; then
  echo "GSI updates control forecast."
  nummiter=2
  if_read_obs_save=".false."
  if_read_obs_skip=".false."
  work_root=${CYCLE_HOME}/gsiprd
  max_dom=${WRF_CTR_DOM}
else
  echo "GSI is observer for EnKF ensemble."
  nummiter=0
  if_read_obs_save=".true."
  if_read_obs_skip=".false."
  work_root=${CYCLE_HOME}/enkfprd
  max_dom=${WRF_ENS_DOM}
fi


# NOTE: NEED TO CASE THIS SWITCH IN ORDER TO ACCOMODATE STATIC ENSEMBLES
if [[ ${IF_CTR_COLD_START} = ${NO} ]]; then
  # NOTE: the background files are taken from the WRFDA outputs when cycling,
  # having updated the lower BCs
  bkg_root=${CYCLE_HOME}/wrfdaprd
else
  # otherwise, the background files are take from wrfinput generated by real.exe
  bkg_root=${CYCLE_HOME}/realprd
fi

obs_root=${DATA_ROOT}/obs_data
fix_root=${EXP_CONFIG}/fix
satlist=${fix_root}/satlist.txt
gsi_namelist=${EXP_CONFIG}/namelists/comgsi_namelist.sh
prepbufr_tar=${obs_root}/prepbufr.${anl_date}.nr.tar.gz
prepbufr_dir=${obs_root}/${anl_date}.nr
prepbufr=${prepbufr_dir}/prepbufr.gdas.${anl_date}.t${hh}z.nr

if [ ! -d "${obs_root}" ]; then
  echo "ERROR: \${obs_root} directory '${obs_root}' does not exist."
  exit 1
fi

if [ ! -d "${bkg_root}" ]; then
  echo "ERROR: \${bkg_root} directory '${bkg_root}' does not exist."
  exit 1
fi

if [ ! -d "${fix_root}" ]; then
  echo "ERROR: fix file directory '${fix_root}' does not exist."
  exit 1
fi

if [ ! -r "${satlist}" ]; then
  echo "ERROR: ${satlist} is not readable."
  exit 1
fi

if [ ! -x "${gsi_namelist}" ]; then
  echo "ERROR: ${gsi_namelist} is not executable."
  exit 1
fi

if [ ! -r "${prepbufr_tar}" ]; then
  echo "ERROR: file '${prepbufr_tar}' is not readable."
  exit 1
else
  # untar prepbufr data to predefined directory
  # define prepbufr directory
  mkdir -p ${prepbufr_dir}
  tar -xvf ${prepbufr_tar} -C ${prepbufr_dir}

  # unpack nested directory structure
  prepbufr_nest=(`find ${prepbufr_dir} -type f`)
  nest_indx=0
  while [ ${nest_indx} -le ${#prepbufr_nest[@]} ]; do
    mv ${prepbufr_nest[${nest_indx}]} ${prepbufr_dir}
    (( nest_indx += 1))
  done
  rmdir ${prepbufr_dir}/*

  if [ ! -r "${prepbufr}" ]; then
    echo "ERROR: file '${prepbufr}' is not readable."
    exit 1
  fi
fi

##################################################################################
# Begin pre-GSI setup, running one domain at a time
##################################################################################
# Create the work directory organized by domain analyzed and cd into it
dmn=1

while [ ${dmn} -le ${max_dom} ]; do
  # each domain will generated a variational bias correction file iteratively
  # starting with GDAS defaults
  bc_loop=0

  # NOTE: Hybrid DA uses the control forecast as the EnKF forecast mean, not the
  # control analysis. Work directory for GSI is sub-divided based on domain index
  dmndir=${work_root}/d0${dmn}
  echo "Create work root directory ${dmndir}."

  if [ -d "${dmndir}" ]; then
    rm -rf ${dmndir}
  fi
  mkdir -p ${dmndir}

  while [ ${bc_loop} -le ${MAX_BC_LOOP} ]; do
    cd ${dmndir}

    if [ ${bc_loop} -ne ${MAX_BC_LOOP} ]; then
      # create storage for the outputs indexed on bc_loop except for final loop
      workdir=${dmndir}/bc_loop_${bc_loop}
      mkdir ${workdir}
      cd ${workdir}

    else
      workdir=${dmndir}
    fi

    echo "Variational bias correction update loop ${bc_loop}."
    echo "Working directory ${workdir}."
    echo "Linking observation bufrs to working directory."

    # Link to the prepbufr conventional data
    cmd="ln -s ${prepbufr} ./prepbufr"
    echo ${cmd}; eval ${cmd}

    # Link to satellite data -- note satlist is assumed two column with prefix
    # for GDAS and GSI conventions in first and second column respectively
    # leave empty for no satellite assimilation
    srcobsfile=()
    gsiobsfile=()

    satlines=$(cat ${satlist})
    line_indx=0
    for line in ${satlines}; do
      if [[ $(( ${line_indx} % 2 )) ==  0 ]]; then
        srcobsfile+=("${line}")
      else
        gsiobsfile+=("${line}")      
      fi
      (( line_indx += 1 ))
    done

    # loop over obs types
    len=${#srcobsfile[@]}
    ii=0

    while [[ ${ii} -lt ${len} ]]; do
      cd ${obs_root}
      tar_file=${obs_root}/${srcobsfile[$ii]}.${anl_date}.tar.gz
      obs_dir=${obs_root}/${anl_date}.${srcobsfile[$ii]}
      mkdir -p ${obs_dir}

      if [ -r "${tar_file}" ]; then
        # untar to specified directory
        tar -xvf ${tar_file} -C ${obs_dir}

        # unpack nested directory structure, if exists
        obs_nest=(`find ${obs_dir} -type f`)
        nest_indx=0
        while [ ${nest_indx} -le ${#obs_nest[@]} ]; do
          mv ${obs_nest[${nest_indx}]} ${obs_dir}
          (( nest_indx += 1))
        done
        rmdir ${obs_dir}/*
        # NOTE: differences in data file types for "satwnd"
        if [[ ${srcobsfile[$ii]} = "satwnd" ]]; then
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.txt
        else
          obs_file=${obs_dir}/gdas.${srcobsfile[$ii]}.t${hh}z.${anl_date}.bufr
        fi

        if [ -r "${obs_file}" ]; then
           echo "Link source obs file ${obs_file}."
           cd ${workdir}
           ln -sf ${obs_file} ./${gsiobsfile[$ii]}

        else
           echo "ERROR: obs file ${srcobsfile[$ii]} not found."
           exit 1
        fi

      else
        echo "ERROR: file ${tar_file} not found."
        exit 1
      fi

      cd ${workdir}
      (( ii += 1 ))
    done
    

    echo "Copy fix files and link CRTM coefficient files to working directory."

    #############################################################################
    # Set fix files in the order below:
    #
    #   berror    = Forecast model background error statistics
    #   oberror   = Conventional obs error file
    #   anavinfo  = Information file to set control and analysis variables
    #   specoef   = CRTM spectral coefficients
    #   trncoef   = CRTM transmittance coefficients
    #   emiscoef  = CRTM coefficients for IR sea surface emissivity model
    #   aerocoef  = CRTM coefficients for aerosol effects
    #   cldcoef   = CRTM coefficients for cloud effects
    #   satinfo   = Text file with information about assimilation of brightness temperatures
    #   satangl   = Angle dependent bias correction file (fixed in time)
    #   pcpinfo   = Text file with information about assimilation of prepcipitation rates
    #   ozinfo    = Text file with information about assimilation of ozone data
    #   errtable  = Text file with obs error for conventional data (regional only)
    #   convinfo  = Text file with information about assimilation of conventional data
    #   lightinfo = Text file with information about assimilation of GLM lightning data
    #   bufrtable = Text file ONLY needed for single obs test (oneobstest=.true.)
    #   bftab_sst = Bufr table for sst ONLY needed for sst retrieval (retrieval=.true.)
    #
    ############################################################################

    srcfixfile=()
    gsifixfile=()

    echo "Use NAM-ARW background error covariance fix files."
    srcfixfile+=( "${fix_root}/nam_nmmstat_na.gcv" )
    srcfixfile+=( "${fix_root}/nam_errtable.r3dv" )
    srcfixfile+=( "${fix_root}/anavinfo_arw_netcdf" )

    # the following files filter observation types
    srcfixfile+=( "${fix_root}/global_satangbias.txt" )
    srcfixfile+=( "${fix_root}/global_satinfo.txt" )
    srcfixfile+=( "${fix_root}/global_convinfo.txt" )
    srcfixfile+=( "${fix_root}/global_ozinfo.txt" )
    srcfixfile+=( "${fix_root}/global_pcpinfo.txt" )
    srcfixfile+=( "${fix_root}/global_lightinfo.txt" )

    gsifixfile+=( "berror_stats" )
    gsifixfile+=( "errtable" )
    gsifixfile+=( "anavinfo" )
    gsifixfile+=( "satbias_angle" )
    gsifixfile+=( "satinfo" )
    gsifixfile+=( "convinfo" )
    gsifixfile+=( "ozinfo" )
    gsifixfile+=( "pcpinfo" )
    gsifixfile+=( "lightinfo" )

    # loop over fix files
    len=${#srcfixfile[@]}
    ii=0
    echo "Copy fix files to working directory"
    while [[ ${ii} -lt ${len} ]]; do
      if [ -r ${srcfixfile[$ii]} ]; then
        cmd="cp ${srcfixfile[$ii]} ./${gsifixfile[$ii]}"
        echo ${cmd}; eval ${cmd}
      else
        echo "ERROR: GSI fix file ${srcfixfile[ii]} not readable."
        exit 1
      fi
      (( ii += 1 ))
    done

    # CRTM Spectral and Transmittance coefficients
    coefs=()
    coefs+=( "Nalli.IRwater.EmisCoeff.bin" )
    coefs+=( "NPOESS.IRice.EmisCoeff.bin" )
    coefs+=( "NPOESS.IRland.EmisCoeff.bin" )
    coefs+=( "NPOESS.IRsnow.EmisCoeff.bin" )
    coefs+=( "NPOESS.VISice.EmisCoeff.bin" )
    coefs+=( "NPOESS.VISland.EmisCoeff.bin" )
    coefs+=( "NPOESS.VISsnow.EmisCoeff.bin" )
    coefs+=( "NPOESS.VISwater.EmisCoeff.bin" )
    coefs+=( "FASTEM6.MWwater.EmisCoeff.bin" )
    coefs+=( "AerosolCoeff.bin" )
    coefs+=( "CloudCoeff.bin" )

    # loop over coefs 
    len=${#srcobsfile[@]}
    ii=0
    echo "Link CRTM coefficient files"
    while [[ ${ii} -lt ${len} ]]; do
      coef_file=${CRTM_ROOT}/${coeffs[$ii]}
      if [ -r ${coef_file} ]; then
        cmd="ln -s ${coeff_file}  ./"
	echo ${cmd}; eval ${cmd}
      else
        echo "ERROR: CRTM coefficient file ${coef_file} not readable."
	exit 1
      fi
      (( ii += 1 ))
    done

    # Copy CRTM coefficient files based on entries in satinfo file
    for file in `awk '{if($1!~"!"){print $1}}' ./satinfo | sort | uniq` ;do
     satinfo_coeffs=()
     satinfo_coeffs+=( "${CRTM_ROOT}/${file}.SpcCoeff.bin" )
     satinfo_coeffs+=( "${CRTM_ROOT}/${file}.TauCoeff.bin" )
     for coef_file in ${satinfo_coeffs}; do
       if [ -r ${coef_file} ]; then
         cmd="ln -s ${coef_file} ./"
	 echo ${cmd}; eval ${cmd}
       else
         echo "ERROR: CRTM coefficient file ${coef_file} not readable."
       fi
     done
    done

    if [[ ${if_oneob} = ${YES} ]]; then
      # Only need this file for single obs test
      bufrtable=${fix_root}/prepobs_prep.bufrtable
      cmd="cp ${bufrtable} ./prepobs_prep.bufrtable"
      echo ${cmd}; eval ${cmd}
    fi

    if [ ${bc_loop} -eq 0 ]; then
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
      ii=0
      while [[ ${ii} -lt 2 ]]; do
	tar_file=${tar_files[$ii]}
	bias_dir=${bias_dirs[$ii]}
	bias_file=${bias_files[$ii]}
        if [ -r "${tar_file}" ]; then
	  # untar to specified directory
	  mkdir -p ${bias_dir}
          tar -xvf ${tar_file} -C ${bias_dir}

	  # unpack nested directory structure
	  bias_nest=(`find ${bias_dir} -type f`)
          nest_indx=0
          while [ ${nest_indx} -le ${#bias_nest[@]} ]; do
            mv ${bias_nest[${nest_indx}]} ${bias_dir}
            (( nest_indx += 1))
          done
	  rmdir ${bias_dir}/*

          if [ -r "${bias_file}" ]; then
            msg="Link the GDAS bias correction file ${bias_file} "
	    msg+="for loop zero of analysis."
            echo ${msg}
            
	    cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
	    echo ${cmd}; eval ${cmd}
          else
            echo "GDAS bias correction file not readable at ${bias_file}."
            exit 1
          fi
        else
          echo "Tar ${tar_file} of GDAS bias corrections not readable."
            exit 1
        fi
	(( ii +=1 ))
      done
    else
      # use the bias correction file generated on the last GSI loop 
      bias_files=()
      (( lag_loop = ${bc_loop} - 1 ))
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_out)
      bias_files+=(${dmndir}/bc_loop_${lag_loop}/satbias_pc.out)

      bias_in_files=()
      bias_in_files+=(satbias_in)
      bias_in_files+=(satbias_pc_in)

      # loop over bias files
      len=${#tar_files[@]}
      ii=0

      while [[ ${ii} -lt ${len} ]]; do
	bias_file=${bias_files[$ii]}
        if [ -r "${bias_file}" ]; then
          msg="Linking variational bias correction file "
	  msg+="${bias_file} from last analysis."
	  echo ${msg}

          cmd="ln -sf ${bias_file} ./${bias_in_files[$ii]}"
	  echo ${cmd}; eval ${cmd}
        else
          echo "Bias file ${bias_file} variational bias corrections not readable."
            exit 1
        fi
	(( ii +=1 ))
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

    if [[ ${IF_CTR_COLD_START} = ${NO} ]]; then
      bkg_file=${bkg_root}/ens_00/lower_bdy_update/wrfout_d0${dmn}_${date_str}
    else
      bkg_file=${bkg_root}/ens_00/wrfinput_d0${dmn}
    fi

    if [ ! -r "${bkg_file}" ]; then
      echo "ERROR: background file ${bkg_file} does not exist."
      exit 1
    fi

    echo " Copy background file(s) to working directory."
    # Copy over background field -- THIS IS MODIFIED BY GSI DO NOT LINK TO IT
    cmd="cp ${bkg_file} ./wrf_inout"
    echo ${cmd}; eval ${cmd}

    # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
    #if [[ ${IF_4DENVAR} = ${YES} ]] ; then
    # PDYa=`echo ${ANL_TIME} | cut -c1-8`
    # cyca=`echo ${ANL_TIME} | cut -c9-10`
    # gdate=`date -u -d "${PDYa} ${cyca} -6 hour" +%Y%m%d%H` #guess date is 6hr ago
    # gHH=`echo ${gdate} |cut -c9-10`
    # datem1=`date -u -d "${PDYa} ${cyca} -1 hour" +%Y-%m-%d_%H:%M:%S` #1hr ago
    # datep1=`date -u -d "${PDYa} ${cyca} 1 hour"  +%Y-%m-%d_%H:%M:%S`  #1hr later
    #  bkg_file_p1=${bkg_root}/wrfout_d0${dmn}_${datep1}
    #  bkg_file_m1=${bkg_root}/wrfout_d0${dmn}_${datem1}
    #fi

    ##################################################################################
    # Prep GSI ensemble 
    ##################################################################################

    if [[ ${IF_HYBRID} = ${YES} ]]; then

      if [[ ${IF_ENS_COLD_START} = ${NO} ]]; then
        # NOTE: the background files are taken from the WRFDA outputs when cycling, having updated the lower BCs
        ens_root=${CYCLE_HOME}/wrfdaprd
      else
        # otherwise, the background files are take from wrfinput generated by real.exe
        ens_root=${CYCLE_HOME}/realprd
      fi

      if [ ${dmn} -le ${WRF_ENS_DOM} ]; then
        # take ensemble generated by WRF members
        echo " Copy ensemble perturbations to working directory."
        ens_n=1

        while [ ${ens_n} -le ${N_ENS} ]; do
          # two zero padding for GEFS
          iimem=`printf %02d $(( 10#${ens_n} ))`

          if [[ ${IF_ENS_COLD_START} = ${NO} ]]; then
            ens_file=${ens_root}/ens_${iimem}/lower_bdy_update/wrfout_d0${dmn}_${date_str}
          else
            ens_file=${ens_root}/ens_${iimem}/wrfinput_d0${dmn}
          fi

          if [ -r ${ens_file} ]; then
            cmd="ln -sf ${ens_file} ./wrf_en${iimem}"
	    echo ${cmd}; eval ${cmd}
          else
            echo "ERROR: ensemble file ${ens_file} does not exist."
            exit 1
          fi
          (( ens_n += 1 ))
        done

        ls ./wrf_en* > filelist02

        # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
        #if [[ ${IF_4DENVAR} = ${YES} ]]; then
        #  cp ${bkg_file_p1} ./wrf_inou3
        #  cp ${bkg_file_m1} ./wrf_inou1
        #  ls ${ENSEMBLE_FILE_mem_p1}* > filelist03
        #  ls ${ENSEMBLE_FILE_mem_m1}* > filelist01
        #fi

      else
        # run simple 3D-VAR without an ensemble 
	echo "WARNING"
	echo "Dual resolution ensemble perturbations and control are not an option yet."
	echo "Running nested domain d0${dmn} as simple 3D-VAR update."
        ifhyb=".false."
      fi

      # define namelist ensemble size
      nummem=${N_ENS}
    fi

    ##################################################################################
    # Build GSI namelist
    ##################################################################################
    echo "Build the namelist with default NAM-ARW."

    # default is NAM
    vs_op='1.0,'
    hzscl_op='0.373,0.746,1.50,'

    # Build the GSI namelist on-the-fly
    . ${gsi_namelist}

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
    echo
    echo "IF_CTR_COLD_START = ${IF_CTR_COLD_START}"
    echo "IF_ENS_COLD_START = ${IF_ENS_COLD_START}"
    echo "IF_HYBRID         = ${IF_HYBRID}"
    echo "N_ENS             = ${N_ENS}"
    echo "IF_OBSERVER       = ${IF_OBSERVER}"
    echo "IF_4DENVAR        = ${IF_4DENVAR}"
    echo "WRF_CTR_DOM       =${WRF_CTR_DOM}"
    echo "WRF_ENS_DOM       =${WRF_ENS_DOM}"
    echo
    echo "ANL_TIME          = ${ANL_TIME}"
    echo "GSI_EXE           = ${GSI_EXE}"
    echo "CRTM_ROOT         = ${CRTM_ROOT}"
    echo "EXP_CONFIG        = ${EXP_CONFIG}"
    echo "CYCLE_HOME        = ${CYCLE_HOME}"
    echo "DATA_ROOT         = ${DATA_ROOT}"
    echo
    now=`date +%Y%m%d%H%M%S`
    echo "gsi analysis started at ${now} on domain d0${dmn}."
    cmd="${MPIRUN} -n ${GSI_PROC} ${GSI_EXE} > stdout_ens_00.anl.${ANL_TIME} 2>&1"
    echo ${cmd}; eval ${cmd}

    ##################################################################################
    # Run time error check
    ##################################################################################
    error=$?

    if [ ${error} -ne 0 ]; then
      echo "ERROR: ${GSI_EXE} exited with status ${error}."
      exit ${error}
    fi

    # Rename the output to more understandable names
    cmd="cp wrf_inout wrfanl_ens_00.${ANL_TIME}"
    echo ${cmd}; eval ${cmd}

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
            cat pe*${type}_${loop}* > diag_${type}_${string}.${ANL_TIME}
         fi
      done
    done

    #  Clean working directory to save only important files
    ls -l * > list_run_directory

    if [[ ${if_clean} = ${YES} && ${IF_OBSERVER} = ${NO} ]]; then
      echo " Clean working directory after GSI run."
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
        if [[ -f diag_${type}_${string}.${ANL_TIME} ]]; then
           cmd="mv diag_${type}_${string}.${ANL_TIME} diag_${type}_${string}.ensmean"
           echo ${cmd}; eval ${cmd}
        fi
      done
      cmd="mv wrf_inout wrf_inout_ensmean"
      echo ${cmd}; eval ${cmd}

      # Build the GSI namelist on-the-fly for each member
      if_read_obs_save=".false."
      if_read_obs_skip=".true."
      . ${gsi_namelist}

      # Loop through each member
      loop="01"
      ens_n=1

      while [[ ${ens_n} -le ${N_ENS} ]]; do
        rm pe0*
        echo "\${ens_n} is ${ens_n}."
        iimem=`printf %02d $(( 10#${ens_n} ))`

        # get new background for each member
        if [[ -f wrf_inout ]]; then
          rm wrf_inout
        fi

        ens_file="./wrf_en${iimem}"
        echo "Copying ${ens_file} for GSI observer."
        cmd="cp ${ens_file} wrf_inout"
	echo ${cmd}; eval ${cmd}

        # run GSI
        echo "Run GSI observer for member ${iimem}."
        cmd="${MPIRUN} ${GSI_EXE} > stdout_ens_${iimem}.anl.${ANL_TIME} 2>&1"
	echo ${cmd}; eval ${cmd}

        # run time error check and save run time file status
        error=$?

        if [ ${error} -ne 0 ]; then
          echo "ERROR: ${GSI_EXE} exited with status ${error} for member ${iimem}."
          exit ${error}
        fi

        ls -l * > list_run_directory_mem${iimem}

        # generate diag files
        for type in ${listall}; do
          count=`ls pe*${type}_${loop}* | wc -l`
          if [[ ${count} -gt 0 ]]; then
            cat pe*${type}_${loop}* > diag_${type}_${string}.mem${iimem}
          fi
        done
        # next member
        (( ens_n += 1 ))
      done
    fi

    # next variational bias correction loop
    (( bc_loop += 1 ))
  done 

  # Next domain
  (( dmn += 1 ))
done

echo "gsi.sh completed successfully at `date`."

##################################################################################

exit 0
