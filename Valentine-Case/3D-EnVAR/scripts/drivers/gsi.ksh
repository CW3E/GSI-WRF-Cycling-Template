#!/bin/ksh
#####################################################
# Description
#####################################################
# This driver script is a major fork and rewrite of the standard GSI ksh
# driver script for 3DVAR used in the GSI tutorial
# https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php
#
# The purpose of this fork is to work in a Rocoto-based
# Observation-Analysis-Forecast cycle with WRF for data denial
# experiments. Naming conventions in this script have been smoothed
# to match a companion major fork of the wrf.ksh
# WRF driver script of Christopher Harrop.
#
# One should write machine specific options for the GSI environment
# in a GSI_constants.ksh script to be sourced in the below.  Variables
# aliases in this script are based on conventions defined in the
# companion GSI_constants.ksh with this driver.
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
# bk_core     = Which WRF core is used as background (NMM or ARW or NMMB)
# bkcv_option = Which background error covariance and parameter will be used
#              (GLOBAL or NAM)
#
# if_clean    = clean  : delete temporal files in working directory (default)
#               no     : leave running directory as is (this is for debug only)
# BYTE_ORDER  = Big_Endian or Little_Endian
#
#####################################################

# uncomment to run verbose for debugging / testing
set -x

bk_core=ARW
bkcv_option=NAM
if_clean=clean
BYTE_ORDER=Big_Endian

#####################################################
# Read in GSI constants for local environment
#####################################################

if [ ! -x "${CONSTANT}" ]; then
  ${ECHO} "ERROR: \$CONSTANT does not exist or is not executable!"
  exit 1
fi

. ${CONSTANT}

#####################################################
# Make checks for DA method settings
#####################################################
# Options below are defined in cycling.xml (case insensitive)
#
# MAX_DOM       = INT   : GSI analyzes the domain d0${dmn} for dmn -le ${MAX_DOM}
# IF_COLD_START = Yes   : GSI analyzes wrfinput_d0${dmn} file instead
#                         of wrfout_d0${dmn} file to start first DA cycle
# IF_SATRAD     = Yes   : GSI uses conventional data from prepbufr,
#                         satellite radiances, gpsro and radar data
#                 No    : GSI uses conventional data alone
#
# IF_HYBRID     = Yes   : Run GSI as 3D/4D EnVar
# IF_OBSERVER   = Yes   : Only used as observation operator for EnKF
# N_ENS         = INT   : Max ensemble index (00 for control alone) 
#                         NOTE this must be set when `IF_HYBRID=Yes` and when `IF_OBSERVER=Yes`
# IF_4DENVAR    = Yes   : Run GSI as 4D EnVar
#                         NOTE set `IF_HYBRID=Yes` first
# IF_NEMSIO     = Yes   : The GFS background files are in NEMSIO format
# IF_ONEOB      = Yes   : Do single observation test
#
#####################################################

if [ ! ${MAX_DOM} ]; then
  ${ECHO} "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

if [[ ${IF_COLD_START} != ${YES} && ${IF_COLD_START} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_COLD_START must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_SATRAD} != ${YES} && ${IF_SATRAD} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_SATRAD must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_OBSERVER} != ${YES} && ${IF_OBSERVER} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_OBSERVER must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_HYBRID} != ${YES} && ${IF_HYBRID} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_HYBRID must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_HYBRID} = ${YES} ]] ; then
  # ensembles are only required for hybrid EnVAR
  if [ ! "${N_ENS}" ]; then
    ${ECHO} "ERROR: \$N_ENS must be specified to the number of ensemble perturbations!"
    exit 1
  fi
fi

if [[ ${IF_OBSERVER} = ${YES} ]]; then
  if [[ ! ${IF_HYBRID} = ${YES} ]]; then
    ${ECHO} "ERROR: \$IF_HYBRID must equal Yes if \$IF_OBSERVER = Yes"
    exit 1
  fi
fi

if [[ ${IF_4DENVAR} != ${YES} && ${IF_4DENVAR} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_4DENVAR must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_NEMSIO} != ${YES} && ${IF_NEMSIO} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_NEMSIO must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_ONEOB} != ${YES} && ${IF_ONEOB} != ${NO} ]]; then
  ${ECHO} "ERROR: \$IF_ONEOB must equal 'Yes' or 'No' (case insensitive)"
  exit 1
fi

if [[ ${IF_ONEOB} = ${YES} ]]; then
  if_oneobtest='.true.'
else
  if_oneobtest='.false.'
fi

#####################################################
# Define GSI workflow dependencies
#####################################################
# Below variables are defined in cycling.xml workflow variables
#
# ANAL_TIME      = Analysis time YYYYMMDDHH
# GSI_ROOT       = Directory for clean GSI build
# CRTM_VERSION   = Version number of CRTM to specify path to binaries
# STATIC_DATA    = Root directory containing sub-directories for constants, namelists
#                  grib data, geogrid data, obs tar files etc.
# INPUT_DATAROOT = Analysis time named directory for input data, containing
#                  subdirectories bkg, wpsprd, realprd, wrfprd, wrfdaprd, gsiprd
# MPIRUN         = MPI Command to execute GSI
#
# Below variables are derived by cycling.xml variables for convenience
#
# DATE_STR       = Defined by the ANAL_TIME variable, to be used as path
#                  name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
#####################################################

if [ ! "${ANAL_TIME}" ]; then
  ${ECHO} "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

# Define directory path name variable DATE_STR=YYMMDDHH from ANAL_TIME
HH=`${ECHO} $ANAL_TIME | cut -c9-10`
ANAL_DATE=`${ECHO} $ANAL_TIME | cut -c1-8`
DATE_STR=`${DATE} +%Y-%m-%d_%H:%M:%S -d "${ANAL_DATE} $HH hours"`

if [ -z "${DATE_STR}"]; then
  ${ECHO} "ERROR: \$DATE_STR is not defined correctly, check format of \$ANAL_DATE!"
  exit 1
fi

if [ ! "${GSI_ROOT}" ]; then
  ${ECHO} "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi

if [ -z "${CRTM_VERSION}" ]; then
  ${ECHO} "ERROR: The variable \$CRTM_VERSION must be set to version number for specifying binary path!"
  exit 1
fi


if [ ! ${STATIC_DATA} ]; then
  ${ECHO} "ERROR: \$STATIC_DATA is not defined!"
  exit 1
fi


if [ ! -d ${STATIC_DATA} ]; then
  ${ECHO} "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! "${INPUT_DATAROOT}" ]; then
  ${ECHO} "ERROR: \$INPUT_DATAROOT is not defined!"
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  ${ECHO} "ERROR: \$MPIRUN is not defined!"
  exit 1
fi

#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# WORK_ROOT    = Working directory where GSI runs, either to analyze the control or to be the observer for EnKF
# OBS_ROOT     = Path of observations files
# BKG_ROOT     = Path for root directory of controlm from WRFDA or REAL depending on cycling
# FIX_ROOT     = Path of fix files
# GSI_EXE      = Path and name of the gsi.x executable
# CRTM_ROOT    = Path of the CRTM root directory, contained in GSI_ROOT
# PREPBUFR     = Path of PreBUFR conventional obs
#
#####################################################

if [[ ${IF_OBSERVER} = ${NO} ]]; then
  WORK_ROOT=${INPUT_DATAROOT}/gsiprd
else
  WORK_ROOT=${INPUT_DATAROOT}/enkfprd
fi
OBS_ROOT=${STATIC_DATA}/obs_data

if [[ ${IF_COLDSTART} = ${NO} ]]; then
  # NOTE: the background files are taken from the WRFDA outputs when cycling, having updated the lower BCs
  BKG_ROOT=${INPUT_DATAROOT}/wrfdaprd
else
  # otherwise, the background files are take from wrfinput generated by real.exe
  BKG_ROOT=${INPUT_DATAROOT}/realprd
fi

FIX_ROOT=${GSI_ROOT}/fix

GSI_EXE=${GSI_ROOT}/build/bin/gsi.x
GSI_NAMELIST=${GSI_ROOT}/ush/comgsi_namelist.sh
CRTM_ROOT=${GSI_ROOT}/CRTM_v${CRTM_VERSION}
PREPBUFR_TAR=${OBS_ROOT}/prepbufr.${ANAL_DATE}.nr.tar.gz
PREPBUFR=${OBS_ROOT}/${ANAL_DATE}.nr/prepbufr.gdas.${ANAL_DATE}.t${HH}z.nr

if [ ! -d "${OBS_ROOT}" ]; then
  ${ECHO} "ERROR: OBS_ROOT directory '${OBS_ROOT}' does not exist!"
  exit 1
fi

if [ ! -d "${BKG_ROOT}" ]; then
  ${ECHO} "ERROR: \$BKG_ROOT directory '${BKG_ROOT}' does not exist!"
  exit 1
fi

if [ ! -d "${FIX_ROOT}" ]; then
  ${ECHO} "ERROR: FIX directory '${FIX_ROOT}' does not exist!"
  exit 1
fi

if [ ! -x "${GSI_EXE}" ]; then
  ${ECHO} "ERROR: ${GSI_EXE} does not exist!"
  exit 1
fi

if [ ! -x "${GSI_NAMELIST}" ]; then
  ${ECHO} "ERROR: ${GSI_NAMELIST} does not exist!"
  exit 1
fi

if [ ! -d "${CRTM_ROOT}" ]; then
  ${ECHO} "ERROR: CRTM directory '${CRTM_ROOT}' does not exist!"
  exit 1
fi

if [ ! -r "${PREPBUFR_TAR}" ]; then
  ${ECHO} "ERROR: file '${PREPBUFR_TAR}' does not exist!"
  exit 1
else
  cd ${OBS_ROOT}
  ${TAR} -xvf `${BASENAME} ${PREPBUFR_TAR}`
fi

if [ ! -r "${PREPBUFR}" ]; then
  ${ECHO} "ERROR: file '${PREPBUFR}' does not exist!"
  exit 1
fi

#####################################################
# Begin pre-GSI setup, running one domain at a time
#####################################################
# Create the work directory organized by domain analyzed and cd into it
dmn=1

while [ ${dmn} -le ${MAX_DOM} ]; do
  # NOTE: Hybrid-VAR uses the control forecast as the EnKF forecast mean, not the control analysis 
  # work directory for GSI is sub-divided based on domain index
  workdir=${WORK_ROOT}/d0${dmn}
  ${ECHO} " Create working directory:" ${workdir}

  if [ -d "${workdir}" ]; then
    ${RM} -rf ${workdir}
  fi
  mkdir -p ${workdir}
  cd ${workdir}

  ${ECHO} " Link observation bufr to working directory"

  # Link to the prepbufr conventional data
  ${LN} -s ${PREPBUFR} ./prepbufr

  # Link to satellite data
  ii=1

  if [[ ${IF_SATRAD} = ${YES} ]] ; then
     srcobsfile=()
     gsiobsfile=()

     # tested
     srcobsfile+=("1bamua")
     gsiobsfile+=("amsuabufr")

     # not available for dates
     #srcobsfile+=("1bamub")
     #gsiobsfile+=("amsubbufr")

     # available, not tested
     #srcobsfile+=("1bhrs4")
     #gsiobsfile+=("hirs4bufr")

     # available, not tested
     #srcobsfile+=("1bmhs")
     #gsiobsfile+=("mhsbufr")

     # available, not tested
     #srcobsfile+=("airsev")
     #gsiobsfile+=("airsbufr")

     # not available for dates
     #srcobsfile+=("amsr2")
     #gsiobsfile+=("amsrebufr")

     # available, not tested
     #srcobsfile+=("atms")
     #gsiobsfile+=("atmsbufr")

     # not available for dates
     #srcobsfile+=("esamua")
     #gsiobsfile+=("amsuabufrears")

     # available, not tested
     #srcobsfile+=("eshrs3")
     #gsiobsfile+=("hirs3bufrears")

     # available, not tested
     #srcobsfile+=("esmhs")
     #gsiobsfile+=("mhsbufrears")

     # available, not tested
     #srcobsfile+=("geoimr")
     #gsiobsfile+=("gimgrbufr")

     # not available for dates
     #srcobsfile+=("goesfv")
     #gsiobsfile+=("gsnd1bufr")

     # available, not tested
     #srcobsfile+=("gome")
     #gsiobsfile+=("gomebufr")

     # not available for dates
     #srcobsfile+=("lgycld")
     #gsiobsfile+=("larcglb")

     # not available for dates
     #srcobsfile+=("nexrad")
     #gsiobsfile+=("l2rbufr")

     # not available for dates
     #srcobsfile+=("omi")
     #gsiobsfile+=("omibufr")

     # tested
     srcobsfile+=("gpsro")
     gsiobsfile+=("gpsrobufr")

     # tested
     srcobsfile+=("mtiasi")
     gsiobsfile+=("iasibufr")

     # available, not tested
     #srcobsfile+=("osbuv8")
     #gsiobsfile+=("sbuvbufr")

     # tested
     srcobsfile+=("satwnd")
     gsiobsfile+=("satwndbufr")

     # available, not tested
     #srcobsfile+=("ssmisu")
     #gsiobsfile+=("ssmirrbufr")

     # available, not tested
     # not recommended by Minghua
     #srcobsfile+=("sevcsr")
     #gsiobsfile+=("seviribufr")

     len=${#srcobsfile[@]}

     while [[ $ii -le ${len} ]]; do
	tar_file=${OBS_ROOT}/${srcobsfile[$ii]}.${ANAL_DATE}.tar.gz
	if [ -r "${tar_file}" ]; then
	  cd ${OBS_ROOT}
	  ${TAR} -xvf `${BASENAME} ${tar_file}`
	  if [[ ${srcobsfile[$ii]} = "satwnd" ]]; then
	    obs_file=${OBS_ROOT}/${ANAL_DATE}.${srcobsfile[$ii]}/gdas.${srcobsfile[$ii]}.t${HH}z.${ANAL_DATE}.txt
	  else
	    obs_file=${OBS_ROOT}/${ANAL_DATE}.${srcobsfile[$ii]}/gdas.${srcobsfile[$ii]}.t${HH}z.${ANAL_DATE}.bufr
	  fi
          if [ -r "${obs_file}" ]; then
             ${ECHO} "link source obs file ${obs_file}"
	     cd ${workdir}
             ${LN} -sf ${obs_file} ./${gsiobsfile[$ii]}
	  else
             ${ECHO} "Source obs file ${srcobsfile[$ii]} not found, skipping ${gsiobsfile[$ii]} data"
          fi
	else
	  ${ECHO} "${srctarfile[$ii]} not found, skipping ${gisobsfile[$ii]} data"
	fi
	cd ${workdir}
        (( ii += 1 ))
     done
  fi

  ${ECHO} " Copy fixed files and link CRTM coefficient files to working directory"

  #####################################################
  # Set fixed files
  #
  #   berror    = Forecast model background error statistics
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
  #####################################################

  if [ ${bkcv_option} = GLOBAL ] ; then
    ${ECHO} ' Use global background error covariance'
    BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_glb_berror.f77.gcv
    OBERROR=${FIX_ROOT}/prepobs_errtable.global
    if [ ${bk_core} = NMM ] ; then
       ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf_glbe
    fi
    if [ ${bk_core} = ARW ] ; then
      ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf_glbe
    fi
    if [ ${bk_core} = NMMB ] ; then
      ANAVINFO=${FIX_ROOT}/anavinfo_nems_nmmb_glb
    fi
  else
    ${ECHO} ' Use NAM background error covariance'
    BERROR=${FIX_ROOT}/${BYTE_ORDER}/nam_nmmstat_na.gcv
    OBERROR=${FIX_ROOT}/nam_errtable.r3dv
    if [ ${bk_core} = NMM ] ; then
       ANAVINFO=${FIX_ROOT}/anavinfo_ndas_netcdf
    fi
    if [ ${bk_core} = ARW ] ; then
       ANAVINFO=${FIX_ROOT}/anavinfo_arw_netcdf
    fi
    if [ ${bk_core} = NMMB ] ; then
       ANAVINFO=${FIX_ROOT}/anavinfo_nems_nmmb
    fi
  fi

  SATANGL=${FIX_ROOT}/global_satangbias.txt
  SATINFO=${FIX_ROOT}/global_satinfo.txt
  CONVINFO=${FIX_ROOT}/global_convinfo.txt
  OZINFO=${FIX_ROOT}/global_ozinfo.txt
  PCPINFO=${FIX_ROOT}/global_pcpinfo.txt
  LIGHTINFO=${FIX_ROOT}/global_lightinfo.txt

  # copy Fixed fields to working directory
  ${CP} $ANAVINFO anavinfo
  ${CP} $BERROR   berror_stats
  ${CP} $SATANGL  satbias_angle
  ${CP} $SATINFO  satinfo
  ${CP} $CONVINFO convinfo
  ${CP} $OZINFO   ozinfo
  ${CP} $PCPINFO  pcpinfo
  ${CP} $LIGHTINFO lightinfo
  ${CP} $OBERROR  errtable

  # CRTM Spectral and Transmittance coefficients
  CRTM_ROOT_ORDER=${CRTM_ROOT}/${BYTE_ORDER}
  emiscoef_IRwater=${CRTM_ROOT_ORDER}/Nalli.IRwater.EmisCoeff.bin
  emiscoef_IRice=${CRTM_ROOT_ORDER}/NPOESS.IRice.EmisCoeff.bin
  emiscoef_IRland=${CRTM_ROOT_ORDER}/NPOESS.IRland.EmisCoeff.bin
  emiscoef_IRsnow=${CRTM_ROOT_ORDER}/NPOESS.IRsnow.EmisCoeff.bin
  emiscoef_VISice=${CRTM_ROOT_ORDER}/NPOESS.VISice.EmisCoeff.bin
  emiscoef_VISland=${CRTM_ROOT_ORDER}/NPOESS.VISland.EmisCoeff.bin
  emiscoef_VISsnow=${CRTM_ROOT_ORDER}/NPOESS.VISsnow.EmisCoeff.bin
  emiscoef_VISwater=${CRTM_ROOT_ORDER}/NPOESS.VISwater.EmisCoeff.bin
  emiscoef_MWwater=${CRTM_ROOT_ORDER}/FASTEM6.MWwater.EmisCoeff.bin
  aercoef=${CRTM_ROOT_ORDER}/AerosolCoeff.bin
  cldcoef=${CRTM_ROOT_ORDER}/CloudCoeff.bin

  ${LN} -s $emiscoef_IRwater ./Nalli.IRwater.EmisCoeff.bin
  ${LN} -s $emiscoef_IRice ./NPOESS.IRice.EmisCoeff.bin
  ${LN} -s $emiscoef_IRsnow ./NPOESS.IRsnow.EmisCoeff.bin
  ${LN} -s $emiscoef_IRland ./NPOESS.IRland.EmisCoeff.bin
  ${LN} -s $emiscoef_VISice ./NPOESS.VISice.EmisCoeff.bin
  ${LN} -s $emiscoef_VISland ./NPOESS.VISland.EmisCoeff.bin
  ${LN} -s $emiscoef_VISsnow ./NPOESS.VISsnow.EmisCoeff.bin
  ${LN} -s $emiscoef_VISwater ./NPOESS.VISwater.EmisCoeff.bin
  ${LN} -s $emiscoef_MWwater ./FASTEM6.MWwater.EmisCoeff.bin
  ${LN} -s $aercoef  ./AerosolCoeff.bin
  ${LN} -s $cldcoef  ./CloudCoeff.bin

  # Copy CRTM coefficient files based on entries in satinfo file
  for file in `${AWK} '{if($1!~"!"){print $1}}' ./satinfo | ${SORT} | uniq` ;do
     ${LN} -s ${CRTM_ROOT_ORDER}/${file}.SpcCoeff.bin ./
     ${LN} -s ${CRTM_ROOT_ORDER}/${file}.TauCoeff.bin ./
  done

  # NOTE: manual linking taken from Minghua's example driver, IASI CRTM coefficients do not follow
  # the above dynamic linking pattern and must be set manually, airs linking below doesn't exist in
  # standard CRTM, may need to follow up later
  #${LN} -sf ${CRTM_ROOT_ORDER}/airs281SUBSET_aqua.SpcCoeff.bin ./airs_aqua.SpcCoeff.bin    
  #${LN} -sf ${CRTM_ROOT_ORDER}/airs281SUBSET_aqua.TauCoeff.bin ./airs_aqua.TauCoeff.bin
  ${LN} -sf ${CRTM_ROOT_ORDER}/iasi616_metop-a.SpcCoeff.bin ./iasi_metop-a.SpcCoeff.bin
  ${LN} -sf ${CRTM_ROOT_ORDER}/iasi616_metop-a.TauCoeff.bin ./iasi_metop-a.TauCoeff.bin
  ${LN} -sf ${CRTM_ROOT_ORDER}/iasi616_metop-b.SpcCoeff.bin ./iasi_metop-b.SpcCoeff.bin
  ${LN} -sf ${CRTM_ROOT_ORDER}/iasi616_metop-b.TauCoeff.bin ./iasi_metop-b.TauCoeff.bin

  # Only need this file for single obs test
  bufrtable=${FIX_ROOT}/prepobs_prep.bufrtable
  ${CP} $bufrtable ./prepobs_prep.bufrtable

  # for satellite bias correction
  # NOTE: may need to use own satbias files for appropriate bias correction
  ${CP} ${GSI_ROOT}/fix/comgsi_satbias_in ./satbias_in
  ${CP} ${GSI_ROOT}/fix/comgsi_satbias_pc_in ./satbias_pc_in

  #####################################################
  # Set background depending on the first analysis or cycling and analysis domain
  #####################################################
  # Below are defined depending on the ${dmn} -le ${MAX_DOM}
  #
  # BKG_FILE     = Path and name of background file
  #
  #####################################################


  if [[ ${IF_COLD_START} = ${NO} ]]; then
    BKG_FILE=${BKG_ROOT}/ens_00/lower_bdy_update/wrfout_d0${dmn}_${DATE_STR}
  else
    BKG_FILE=${BKG_ROOT}/ens_00/wrfinput_d0${dmn}
  fi

  if [ ! -r "${BKG_FILE}" ]; then
    ${ECHO} "ERROR: background file ${BKG_FILE} does not exist!"
    exit 1
  fi

  #####################################################
  # Prep steps for GSI 3D/4D hybrid EnVAR
  #####################################################

  ifhyb=.false.

  if [[ ${IF_HYBRID} = ${YES} ]] ; then
    ifhyb=.true.
    ${ECHO} " GSI hybrid uses n_ens=${N_ENS} ensemble perturbations"
    PDYa=`${ECHO} $ANAL_TIME | cut -c1-8`
    cyca=`${ECHO} $ANAL_TIME | cut -c9-10`
    gdate=`${DATE} -u -d "$PDYa $cyca -6 hour" +%Y%m%d%H` #guess date is 6hr ago
    gHH=`${ECHO} $gdate |cut -c9-10`
    datem1=`${DATE} -u -d "$PDYa $cyca -1 hour" +%Y-%m-%d_%H:%M:%S` #1hr ago
    datep1=`${DATE} -u -d "$PDYa $cyca 1 hour"  +%Y-%m-%d_%H:%M:%S`  #1hr later
    if [[ ${IF_NEMSIO} = ${YES} ]]; then
      if_gfs_nemsio='.true.'
    else
      if_gfs_nemsio='.false.'
    fi

    #if [[ ${IF_4DENVAR} = ${YES} ]] ; then
    #  # NOTE: THE FOLLOWING DIRECTORIES WILL NEED TO BE REVISED
    #  BKG_FILE_P1=${BKG_ROOT}/wrfout_d0${dmn}_${datep1}
    #  BKG_FILE_M1=${BKG_ROOT}/wrfout_d0${dmn}_${datem1}
    #fi
  fi

  if4d=.false.
  #if [[ ${ifhyb} = .true. && ${IF_4DENVAR} = ${YES} ]] ; then
  #  if4d=.true.
  #fi

  ${ECHO} " Copy background file(s) to working directory"
  # Copy over background field -- THIS IS MODIFIED BY GSI DO NOT LINK TO IT
  ${CP} ${BKG_FILE} ./wrf_inout

  if [[ ${IF_HYBRID} = ${YES} ]]; then
    ${ECHO} " Copy ensemble perturbations to working directory"
    ens_n=1

    while [ ${ens_n} -le ${N_ENS} ]; do
      # two zero padding for GEFS
      iimem=`printf %02d ${ens_n}`

      # three zero padding for GSI
      iiimem=`printf %03d ${ens_n}`

      if [[ ${IF_COLD_START} = ${NO} ]]; then
        ENS_FILE=${BKG_ROOT}/ens_${iimem}/lower_bdy_update/wrfout_d0${dmn}_${DATE_STR}
      else
        ENS_FILE=${BKG_ROOT}/ens_${iimem}/wrfinput_d0${dmn}
      fi

      if [ ! -r "${ENS_FILE}" ]; then
        ${ECHO} "ERROR: ensemble file ${ENS_FILE} does not exist!"
        exit 1
      else
        ${LN} -sf ${ENS_FILE} ./wrf_en${iiimem}
      fi
      (( ens_n += 1 ))
    done

    # successfully linked ensemble members, define namelist ensemble size
    nummem=${N_ENS}

    #if [[ ${IF_4DENVAR} = ${YES} ]] ; then
    #  ${CP} ${BKG_FILE_P1} ./wrf_inou3
    #  ${CP} ${BKG_FILE_M1} ./wrf_inou1
    #fi
  fi

  #####################################################
  # Build GSI namelist
  #####################################################
  ${ECHO} " Build the namelist "

  # default is NAM
  #   as_op='1.0,1.0,0.5 ,0.7,0.7,0.5,1.0,1.0,'
  vs_op='1.0,'
  hzscl_op='0.373,0.746,1.50,'

  if [ ${bkcv_option} = GLOBAL ] ; then
  #   as_op='0.6,0.6,0.75,0.75,0.75,0.75,1.0,1.0'
     vs_op='0.7,'
     hzscl_op='1.7,0.8,0.5,'
  fi

  if [ ${bk_core} = NMMB ] ; then
     vs_op='0.6,'
  fi

  # default is NMM
  bk_core_arw='.false.'
  bk_core_nmm='.true.'
  bk_core_nmmb='.false.'
  bk_if_netcdf='.true.'

  if [ ${bk_core} = ARW ] ; then
     bk_core_arw='.true.'
     bk_core_nmm='.false.'
     bk_core_nmmb='.false.'
     bk_if_netcdf='.true.'
  fi

  if [ ${bk_core} = NMMB ] ; then
     bk_core_arw='.false.'
     bk_core_nmm='.false.'
     bk_core_nmmb='.true.'
     bk_if_netcdf='.false.'
  fi

  if [[ ${IF_OBSERVER} = ${YES} ]] ; then
    nummiter=0
    if_read_obs_save='.true.'
    if_read_obs_skip='.false.'
  else
    nummiter=2
    if_read_obs_save='.false.'
    if_read_obs_skip='.false.'
  fi

  # Build the GSI namelist on-the-fly
  . $GSI_NAMELIST

  # modify the anavinfo vertical levels based on wrf_inout for WRF ARW and NMM
  if [ ${bk_core} = ARW ] || [ ${bk_core} = NMM ] ; then
    bklevels=`ncdump -h wrf_inout | ${GREP} "bottom_top =" | ${AWK} '{print $3}' `
    bklevels_stag=`ncdump -h wrf_inout | ${GREP} "bottom_top_stag =" | ${AWK} '{print $3}' `
    anavlevels=`${CAT} anavinfo | ${GREP} ' sf ' | ${TAIL} -1 | ${AWK} '{print $2}' ` # levels of sf, vp, u, v, t...
    anavlevels_stag=`${CAT} anavinfo | ${GREP} ' prse ' | ${TAIL} -1 | ${AWK} '{print $2}' `  # levels of prse
    ${SED} -i 's/ '$anavlevels'/ '$bklevels'/g' anavinfo
    ${SED} -i 's/ '$anavlevels_stag'/ '$bklevels_stag'/g' anavinfo
  fi

  #####################################################
  # Run GSI
  #####################################################
  # Print run parameters
  ${ECHO}
  ${ECHO} "IF_COLD_START  = ${IF_COLD_START}"
  ${ECHO} "IF_SATRAD      = ${IF_SATRAD}"
  ${ECHO} "IF_HYBRID      = ${IF_HYBRID}"
  ${ECHO} "N_ENS          = ${N_ENS}"
  ${ECHO} "IF_OBSERVER    = ${IF_OBSERVER}"
  ${ECHO} "IF_4DENVAR     = ${IF_4DENVAR}"
  ${ECHO} "IF_NEMSIO      = ${IF_NEMSIO}"
  ${ECHO} "IF_ONEOB       = ${IF_ONEOB}"
  ${ECHO}
  ${ECHO} "ANAL_TIME      = ${ANAL_TIME}"
  ${ECHO} "GSI_ROOT       = ${GSI_ROOT}"
  ${ECHO} "CRTM_VERSION   = ${CRTM_VERSION}"
  ${ECHO} "INPUT_DATAROOT = ${INPUT_DATAROOT}"
  ${ECHO}
  now=`${DATE} +%Y%m%d%H%M%S`
  ${ECHO} "gsi started at ${now} with ${bk_core} background on domain d0${dmn}"
  ${MPIRUN} ${GSI_EXE} > stdout_ens_00.anl.d0${dmn}_${ANAL_TIME} 2>&1

  #####################################################
  # Run time error check
  #####################################################
  error=$?

  if [ ${error} -ne 0 ]; then
    ${ECHO} "ERROR: ${GSI} crashed  Exit status=${error}"
    exit ${error}
  fi

  #####################################################
  # GSI updating satbias_in
  #####################################################
  # GSI updating satbias_in (only for cycling assimilation)

  # Rename the output to more understandable names
  ${CP} wrf_inout   wrfanl_ens_00.d0${dmn}_${ANAL_TIME}
  ${CP} fort.201    fit_p1_ens_00.d0${dmn}_${ANAL_TIME}
  ${CP} fort.202    fit_w1_ens_00.d0${dmn}_${ANAL_TIME}
  ${CP} fort.203    fit_t1_ens_00.d0${dmn}_${ANAL_TIME}
  ${CP} fort.204    fit_q1_ens_00.d0${dmn}_${ANAL_TIME}
  ${CP} fort.207    fit_rad1_ens_00.d0${dmn}_${ANAL_TIME}

  #####################################################
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
  #####################################################

  loops="01 03"
  for loop in ${loops}; do
    case ${loop} in
      01) string=ges;;
      03) string=anl;;
       *) string=${loop};;
    esac

    #####################################################
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
    #####################################################

    listall=`${LS} pe* | cut -f2 -d"." | ${AWK} '{print substr($0, 0, length($0)-3)}' | ${SORT} | uniq `
    for type in ${listall}; do
       count=`${LS} pe*${type}_${loop}* | ${WC} -l`
       if [[ ${count} -gt 0 ]]; then
          ${CAT} pe*${type}_${loop}* > diag_${type}_${string}.d0${dmn}_${ANAL_TIME}
       fi
    done
  done

  #  Clean working directory to save only important files
  ${LS} -l * > list_run_directory

  if [[ ${if_clean} = clean && ${IF_OBSERVER} != ${YES} ]]; then
    ${ECHO} ' Clean working directory after GSI run'
    ${RM} -f *Coeff.bin     # all CRTM coefficient files
    ${RM} -f pe0*           # diag files on each processor
    ${RM} -f obs_input.*    # observation middle files
    ${RM} -f siganl sigf0?  # background middle files
    ${RM} -f fsize_*        # delete temperal file for bufr size
  fi

  #####################################################
  # start to calculate diag files for each member
  #####################################################

  if [[ ${IF_OBSERVER} = ${YES} ]]; then
    string=ges
    for type in $listall; do
      count=0
      if [[ -f diag_${type}_${string}.${ANAL_TIME} ]]; then
         ${MV} diag_${type}_${string}.${ANAL_TIME} diag_${type}_${string}.ensmean
      fi
    done
    ${MV} wrf_inout wrf_inout_ensmean

    # Build the GSI namelist on-the-fly for each member
    nummiter=0
    if_read_obs_save='.false.'
    if_read_obs_skip='.true.'
    . $GSI_NAMELIST

    # Loop through each member
    loop="01"
    ens_n=1

    while [[ ${ens_n} -le ${N_ENS} ]]; do
      ${RM} pe0*
      print "\$ens_n is ${ens_n}"
      iimem=`printf %02d ${ens_n}`
      iiimem=`printf %03d ${ens_n}`

      # get new background for each member
      if [[ -f wrf_inout ]]; then
        ${RM} wrf_inout
      fi

      ENS_FILE="./wrf_en${iiimem}"
      ${ECHO} ${ENS_FILE}
      ${CP} ${ENS_FILE} wrf_inout

      # run GSI
      ${ECHO} " Run GSI observer with ${bk_core} for member ${iiimem}"
      ${MPIRUN} ${GSI_EXE} > stdout_ens_${iimem}.anl.d0${dmn}_${ANAL_TIME} 2>&1

      # run time error check and save run time file status
      error=$?

      if [ ${error} -ne 0 ]; then
        ${ECHO} "ERROR: ${GSI} crashed for member ${iiimem} Exit status=${error}"
        exit ${error}
      fi

      ${LS} -l * > list_run_directory_mem${iimem}
      # generate diag files

      for type in ${listall}; do
            count=`${LS} pe*${type}_${loop}* | ${WC} -l`
         if [[ ${count} -gt 0 ]]; then
            ${CAT} pe*${type}_${loop}* > diag_${type}_${string}.mem${ens_n}
         fi
      done
      # next member
      (( ens_n += 1 ))
    done
  fi
  (( dmn += 1 ))
done

${ECHO} "gsi.ksh completed successfully at `${DATE}`"

exit 0
