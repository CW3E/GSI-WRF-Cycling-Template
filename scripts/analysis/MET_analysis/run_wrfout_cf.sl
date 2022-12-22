#!/bin/bash
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 24:00:00
#SBATCH --job-name="wrfout_cf"
#SBATCH --export=ALL
#SBATCH --account=cwp130
#SBATCH --mail-user cgrudzien@ucsd.edu
#SBATCH --mail-type BEGIN
#SBATCH --mail-type END
#SBATCH --mail-type FAIL
#################################################################################
# Description
#################################################################################
# This driver script is designed as a companion to the WRF preprocessing script
# wrfout_to_cf.ncl to ready WRF outputs for MET. This script is based on original
# source code provided by Rachel Weihs and Caroline Papadopoulos.  This is
# re-written to homogenize project structure and to include flexibility with
# processing date ranges of data.
#
#################################################################################
# License Statement
#################################################################################
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
#################################################################################
# SET GLOBAL PARAMETERS 
#################################################################################
# uncoment to make verbose for debugging
#set -x

# set local environment for ncl and dependencies
module load ncl_ncarg

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp106/scratch/GSI-WRF-Cycling-Template"

# define control flow to analyze 
CTR_FLW="deterministic_forecast_b25"

# define the case-wise sub-directory
CSE="VD"

# define date range and forecast cycle interval
START_DT="2019021100"
END_DT="2019021400"
CYCLE_INT="24"

# WRF ISO date times defining range of data processed
ANL_START="2019-02-14_00:00:00"
ANL_END="2019-02-15_00:00:00"

# verification domain for the forecast data
DMN="2"

#################################################################################
# Process data
#################################################################################
# define derived data paths
cse="${CSE}/${CTR_FLW}"
out_root="${USR_HME}/data/analysis/${cse}/MET_analysis"
in_root="${USR_HME}/data/simulation_io/${cse}"
scripts_home="${USR_HME}/scripts/analysis/MET_analysis"

# change to scripts directory
cmd="cd ${scripts_home}"
echo ${cmd}
eval ${cmd}

# Convert START_DT from 'YYYYMMDDHH' format to start_dt Unix date format
start_dt="${START_DT:0:8} ${START_DT:8:2}"
start_dt=`date -d "${start_dt}"`

# Convert END_DT from 'YYYYMMDDHH' format to end_dt iso format 
end_dt="${END_DT:0:8} ${END_DT:8:2}"
end_dt=`date -d "${end_dt}"`
end_dt=`date +%Y:%m:%d_%H -d "${end_dt}"`

# loop through the date range
cycle_num=0
fcst_hour=0

# directory string
datestr=`date +%Y%m%d%H -d "${start_dt} ${fcst_hour} hours"`

# loop condition
timestr=`date +%Y:%m:%d_%H -d "${start_dt} ${fcst_hour} hours"`

while [[ ! ${timestr} > ${end_dt} ]]; do
  # set input paths
  input_path="${in_root}/${datestr}/wrfprd/ens_00"
  
  # set input file names
  file_1="wrfout_d0${DMN}_${ANL_START}"
  file_2="wrfout_d0${DMN}_${ANL_END}"
  
  # set output path
  output_path="${out_root}/${datestr}"
  mkdir -p ${output_path}
  
  # set output file name
  output_file="wrf_post_${ANL_START}_to_${ANL_END}.nc"
  
  cmd="ncl 'file_in=\"${input_path}/${file_2}\"' 'file_prev=\"${input_path}/${file_1}\"'" 
  cmd="${cmd} 'file_out=\"${output_path}/${output_file}\"' wrfout_to_cf.ncl "
  
  echo ${cmd}
  eval ${cmd}

  # update the cycle number
  (( cycle_num += 1))
  (( fcst_hour = cycle_num * CYCLE_INT )) 

  # update the date string for directory names
  datestr=`date +%Y%m%d%H -d "${start_dt} ${fcst_hour} hours"`

  # update time string for lexicographical comparison
  timestr=`date +%Y:%m:%d_%H -d "${start_dt} ${fcst_hour} hours"`
done

echo "Script completed at `date`, verify outputs at out_root ${out_root}"

#################################################################################
# end

exit 0
