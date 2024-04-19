#!/bin/bash
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
#####################################################
# Preamble
#####################################################
# uncoment to make verbose for debugging
set -x

# define location of git clone
USR_HME="/cw3e/mead/projects/cwp106/scratch/cgrudzien"

# define control flow to analyze 
CTR_FLW="3dvar_treatment_run"

# define date range and increments
START_TIME=2021012200
END_TIME=2021012800
CYCLE_INT=24

# define vertical level range and increments
VERT_LEVS=(1)
LEV=0
MAX_LEV=50
VERT_INT=1

# define the domain to compute the increments
DMN=1

# set local environment for ncl and dependencies
module load ncl_ncarg

#####################################################
# Execute analyses
#####################################################
# define derived data paths
proj_home=${USR_HME}/GSI-WRF-Cycling-Template/Common-Case/3D-EnVAR
work_root=${proj_home}/data/analysis/${CTR_FLW}/GSI_analysis/analysis_incs
data_root=${proj_home}/data/simulation_io/${CTR_FLW}

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

while [[ ! ${timestr} > ${end_time} ]]; do
  # define wrfout date string
  wrfdate=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${fcst_hour} hours"`

  # define the data sources
  bkg="wrfout_d0${DMN}_${wrfdate}"
  bkg=${data_root}/${datestr}/bkg/ens_00/${bkg}

  anl="wrfanl_ens_00.${datestr}"
  anl=${data_root}/${datestr}/gsiprd/d0${DMN}/${anl}

  # define the output directory and move there for analysis
  outdir=${work_root}/${datestr}
  mkdir -p ${outdir}
  cd ${outdir}

  ln -sf ${bkg} ./wrfinput_d01.cdf
  ln -sf ${anl} ./wrf_inout.cdf

  for lev in "${VERT_LEVS[@]}"; do
    # copy analysis script for sed of parameters
    cp ${proj_home}/scripts/analysis/GSI_analysis/Analysis_increment.ncl ./

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
