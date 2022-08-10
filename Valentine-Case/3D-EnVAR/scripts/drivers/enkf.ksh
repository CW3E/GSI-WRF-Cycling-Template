#!/bin/ksh
#####################################################
# Description
#####################################################
# This driver script is a major fork and rewrite of the standard EnKF ksh
# driver script as discussed in the documentation:
# https://dtcenter.ucar.edu/EnKF/users/docs/enkf_users_guide/html_v1.3/enkf_ch3.html
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
#
#####################################################

# uncomment to run verbose for debugging / testing
set -x

#####################################################
# Read in GSI constants for local environment
#####################################################

if [ ! -x "${CONSTANT}" ]; then
  echo "ERROR: \$CONSTANT does not exist or is not executable!"
  exit 1
fi

. ${CONSTANT}

#####################################################
# Make checks for DA method settings
#####################################################
# Options below are defined in cycling.xml (case insensitive)
#
# MAX_DOM       = INT   : GSI analyzes the domain d0${dmn} for dmn -le ${MAX_DOM}
# N_ENS         = INT   : Max ensemble index (00 for control alone) 
# IF_COLD_START = Yes   : GSI analyzes wrfinput_d0${dmn} file instead
#                         of wrfout_d0${dmn} file to start first DA cycle
#
#####################################################

if [ ! ${MAX_DOM} ]; then
  echo "ERROR: \$MAX_DOM is not defined!"
  exit 1
fi

if [ ! "${N_ENS}" ]; then
  echo "ERROR: \$N_ENS must be specified to the number of ensemble perturbations!"
  exit 1
fi

if [[ ${IF_COLD_START} != ${YES} && ${IF_COLD_START} != ${NO} ]]; then
  echo "ERROR: \$IF_COLD_START must equal 'Yes' or 'No' (case insensitive)"
  exit 1
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
# date_str       = Defined by the ANAL_TIME variable, to be used as path
#                  name variable in YYYY-MM-DD_HH:MM:SS format for wrfout
#
#####################################################

if [ ! "${ANAL_TIME}" ]; then
  echo "ERROR: \$ANAL_TIME is not defined!"
  exit 1
fi

# Define directory path name variable date_str=YYMMDDHH from ANAL_TIME
hh=`echo ${ANAL_TIME} | cut -c9-10`
anal_date=`echo ${ANAL_TIME} | cut -c1-8`
date_str=`date +%Y-%m-%d_%H:%M:%S -d "${anal_date} ${hh} hours"`

if [ -z "${date_str}"]; then
  echo "ERROR: \$date_str is not defined correctly, check format of \$ANAL_TIME!"
  exit 1
fi

if [ ! "${GSI_ROOT}" ]; then
  echo "ERROR: \$GSI_ROOT is not defined!"
  exit 1
fi

if [ -z "${CRTM_VERSION}" ]; then
  echo "ERROR: The variable \$CRTM_VERSION must be set to version number for specifying binary path!"
  exit 1
fi


if [ ! ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA is not defined!"
  exit 1
fi


if [ ! -d ${STATIC_DATA} ]; then
  echo "ERROR: \$STATIC_DATA directory ${STATIC_DATA} does not exist"
  exit 1
fi

if [ ! "${INPUT_DATAROOT}" ]; then
  echo "ERROR: \$INPUT_DATAROOT is not defined!"
  exit 1
fi

if [ ! "${MPIRUN}" ]; then
  echo "ERROR: \$MPIRUN is not defined!"
  exit 1
fi

#####################################################
# The following paths are relative to cycling.xml supplied root paths
#
# work_root    = Working directory where GSI runs, either to analyze the control or to be the observer for EnKF
# obs_root     = Path of observations files
# bkg_root     = Path for root directory of controlm from WRFDA or REAL depending on cycling
# fix_root     = Path of fix files
# gsi_exe      = Path and name of the gsi.x executable
# crtm_root    = Path of the CRTM root directory, contained in GSI_ROOT
# prepbufr     = Path of PreBUFR conventional obs
#
#####################################################

work_root=${INPUT_DATAROOT}/enkfprd

if [[ ${IF_COLD_START} = ${NO} ]]; then
  # NOTE: the background files are taken from the WRFDA outputs when cycling, having updated the lower BCs
  bkg_root=${INPUT_DATAROOT}/wrfdaprd
else
  # otherwise, the background files are take from wrfinput generated by real.exe
  bkg_root=${INPUT_DATAROOT}/realprd
fi

fix_root=${GSI_ROOT}/fix
gsi_exe=${GSI_ROOT}/build/bin/gsi.x
gsi_namelist=${STATIC_DATA}/namelists/comgsi_namelist.sh
crtm_root=${GSI_ROOT}/CRTM_v${CRTM_VERSION}
prepbufr_tar=${obs_root}/prepbufr.${anal_date}.nr.tar.gz
prepbufr=${obs_root}/${anal_date}.nr/prepbufr.gdas.${anal_date}.t${hh}z.nr

if [ ! -d "${obs_root}" ]; then
  echo "ERROR: obs_root directory '${obs_root}' does not exist!"
  exit 1
fi

if [ ! -d "${bkg_root}" ]; then
  echo "ERROR: \$bkg_root directory '${bkg_root}' does not exist!"
  exit 1
fi

if [ ! -d "${fix_root}" ]; then
  echo "ERROR: FIX directory '${fix_root}' does not exist!"
  exit 1
fi

if [ ! -x "${gsi_exe}" ]; then
  echo "ERROR: ${gsi_exe} does not exist!"
  exit 1
fi

if [ ! -x "${gsi_namelist}" ]; then
  echo "ERROR: ${gsi_namelist} does not exist!"
  exit 1
fi

if [ ! -d "${crtm_root}" ]; then
  echo "ERROR: CRTM directory '${crtm_root}' does not exist!"
  exit 1
fi

if [ ! -r "${prepbufr_tar}" ]; then
  echo "ERROR: file '${prepbufr_tar}' does not exist!"
  exit 1
else
  cd ${obs_root}
  tar -xvf `basename ${prepbufr_tar}`
fi

if [ ! -r "${prepbufr}" ]; then
  echo "ERROR: file '${prepbufr}' does not exist!"
  exit 1
fi

#
# GSIPROC = processor number used for GSI analysis
#------------------------------------------------
  GSIPROC=32
  ARCH='LINUX_LSF'

#####################################################
# case set up (users should change this part)
#####################################################
#
# ANAL_TIME= analysis time  (YYYYMMDDHH)
# work_root= working directory, where GSI runs
# PREPBURF = path of PreBUFR conventional obs
# ENKF_EXE  = path and name of the EnKF executable 
  ANAL_TIME=2014021300  #used by comenkf_namelist.sh
     #normally you put run scripts here and submit jobs form here, require a copy of enkf_wrf.x at this directory
  OBS_ROOT=the_directory_where_observation_files_are_located
  diag_ROOT=the_observer_directory_where_diag_files_exist
  ENKF_EXE=/enkf_wrf.x
  fix_root=${GSI_ROOT}/fix
  enkf_namelist=${STATIC_DATA}/namelists/comenkf_namelist.sh

# ensemble parameters
#
  NMEM_ENKF=20
  BK_FILE_mem=${bkg_root}/wrfarw
  NLONS=129
  NLATS=70 
  NLEVS=50
  IF_ARW=.true.
  IF_NMM=.false.
  list="conv"
#  list="conv amsua_n18 mhs_n18 hirs4_n19"
#
# Given the analysis date, compute the date from which the
# first guess comes.  Extract cycle and set prefix and suffix
# for guess and observation data files
gdate=$ANAL_TIME
YYYYMMDD=`echo $adate | cut -c1-8`
HH=`echo $adate | cut -c9-10`

# Fixed files
# CONVINFO=${fix_root}/global_convinfo.txt
# SATINFO=${fix_root}/global_satinfo.txt
# SCANINFO=${fix_root}/global_scaninfo.txt
# OZINFO=${fix_root}/global_ozinfo.txt
ANAVINFO=${diag_ROOT}/anavinfo
CONVINFO=${diag_ROOT}/convinfo
SATINFO=${diag_ROOT}/satinfo
SCANINFO=${diag_ROOT}/scaninfo
OZINFO=${diag_ROOT}/ozinfo
# LOCINFO=${fix_root}/global_hybens_locinfo.l64.txt

# Set up workdir
rm -rf $work_root
mkdir -p $work_root
cd $work_root

cp $ENKF_EXE enkf.x

cp $ANAVINFO        ./anavinfo
cp $CONVINFO        ./convinfo
cp $SATINFO         ./satinfo
cp $SCANINFO        ./scaninfo
cp $OZINFO          ./ozinfo
# cp $LOCINFO         ./hybens_locinfo

cp $diag_ROOT/satbias_in ./satbias_in
cp $diag_ROOT/satbias_pc ./satbias_pc

# get mean
ln -s ${BK_FILE_mem}.ensmean ./firstguess.ensmean
for type in $list; do
   ln -s $diag_ROOT/diag_${type}_ges.ensmean .
done

# get each member
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
   member="mem"`printf %03i $imem`
   ln -s ${BK_FILE_mem}.${member} ./firstguess.${member}
   for type in $list; do
      ln -s $diag_ROOT/diag_${type}_ges.${member} .
   done
   (( imem = $imem + 1 ))
done

# Build the GSI namelist on-the-fly
. ${enkf_namelist}

# make analysis files
cp firstguess.ensmean analysis.ensmean
# get each member
imem=1
while [[ $imem -le $NMEM_ENKF ]]; do
   member="mem"`printf %03i $imem`
   cp firstguess.${member} analysis.${member}
   (( imem = $imem + 1 ))
done

#
###################################################
#  run  EnKF
###################################################
echo ' Run EnKF'

${RUN_COMMAND} ./enkf.x < enkf.nml > stdout 2>&1

##################################################################
#  run time error check
##################################################################
error=$?

if [ ${error} -ne 0 ]; then
  echo "ERROR: ${ENKF_EXE} crashed  Exit status=${error}"
  exit ${error}
fi

exit 0
