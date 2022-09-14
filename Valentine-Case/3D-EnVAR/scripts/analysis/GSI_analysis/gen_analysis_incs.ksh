#!/bin/ksh
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 24:00:00
#SBATCH --job-name="gen_GSI_inc"
#SBATCH --export=ALL
#SBATCH --account=cwp130
#SBATCH --mail-user cgrudzien@ucsd.edu
#SBATCH --mail-type BEGIN
#SBATCH --mail-type END
#SBATCH --mail-type FAIL
#####################################################
# Description
#####################################################
# This driver script is designed as a companion to a minor
# re-write of the Analysis_increment.ncl script that comes
# with GSI in order to conveniently loop over multiple files
# in different date ranges and to produce plots of the analysis
# increments with dynamic naming.
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
# verbose for debugging
set -x

# define date range and increments
START_TIME=2019020800
END_TIME=2019021512
CYCLE_INT=6

# define vertical level range and increments
VERT_LEVS=(1)
LEV=0
MAX_LEV=70
VERT_INT=10

# define the domain to compute the increments
DMN=1

# set local environment for ncl and dependencies
eval `/bin/modulecmd ksh load ncl_ncarg`

# set local root paths
PROJ_HOME=/cw3e/mead/projects/cwp130/scratch/cgrudzien/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR
WORK_ROOT=${PROJ_HOME}/data/analysis/gsi_analysis_inc
DATA_ROOT=${PROJ_HOME}/data/cycle_io

#####################################################
# Execute analyses
#####################################################
# Convert START_TIME from 'YYYYMMDDHH' format to start_time in Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `echo "${START_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  start_time=`echo "${START_TIME}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  echo "ERROR: start time, '${START_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

start_time=`date -d "${start_time}"`

# Convert END_TIME from 'YYYYMMDDHH' format to end_time in isoformat YYYY:MM:DD_HH
if [ `echo "${END_TIME}" | awk '/^[[:digit:]]{10}$/'` ]; then
  end_time=`echo "${END_TIME}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  echo "ERROR: end time, '${END_TIME}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

end_time=`date +%Y:%m:%d_%H -d "${end_time}"`

# construct vertical level array for looping, incrementing with VERT_INT
while [[ ${LEV} -lt ${MAX_LEV} ]]; do
  (( LEV += ${VERT_INT} ))
  VERT_LEVS+=($LEV)
done

# loop through the date range
cycle_num=0
fcst_hour=0

# directory string
datestr=`date +%Y%m%d%H -d "${start_time} ${fcst_hour} hours"`

# loop condition
timestr=`date +%Y:%m:%d_%H -d "${start_time} ${fcst_hour} hours"`

while [[ ! ${datestr} > ${end_time} ]]; do
  # define wrfout date string
  wrfdate=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${fcst_hour} hours"`

  # define the data sources
  bkg="wrfout_d0${DMN}_${wrfdate}"
  bkg=${DATA_ROOT}/${datestr}/bkg/ens_00/${bkg}

  anl="wrfanl_ens_00.${datestr}"
  anl=${DATA_ROOT}/${datestr}/gsiprd/d0${DMN}/${anl}

  # define the output directory and move there for analysis
  outdir=${WORK_ROOT}/${datestr}
  mkdir -p ${outdir}
  cd ${outdir}

  ln -sf ${bkg} ./wrfinput_d01.cdf
  ln -sf ${anl} ./wrf_inout.cdf

  for lev in "${VERT_LEVS[@]}"; do
    # copy analysis script for sed of parameters
    cp ${PROJ_HOME}/scripts/analysis/GSI_analysis/Analysis_increment.ncl ./

    # update the vertical level 
    cat Analysis_increment.ncl | sed "s/\(kmax\)=VERTICAL_LEVEL_INDEX\{1,\}/\1 = ${lev}/" \
      > Analysis_increment.ncl.new
    mv Analysis_increment.ncl.new Analysis_increment.ncl

    fname="a_minus_b_${lev}"
    cat Analysis_increment.ncl | sed "s/\(xwks\)=PLOT_NAME\{1,\}/\1 = gsn_open_wks(\"png\",\"${fname}\")/" \
      > Analysis_increment.ncl.new
    mv Analysis_increment.ncl.new Analysis_increment.ncl

    # run analysis
    ncl Analysis_increment.ncl
  done

  # update the cycle number
  (( cycle_num += 1))
  (( fcst_hour = cycle_num * CYCLE_INT )) 

  # update the date string for directory names
  datestr=`date +%Y%m%d%H -d "${start_time} ${fcst_hour} hours"`

  # update time string for lexicographical comparison
  timestr=`date +%Y:%m:%d_%H -d "${start_time} ${fcst_hour} hours"`
done

#####################################################
# end

exit 0
