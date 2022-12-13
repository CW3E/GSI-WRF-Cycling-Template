#!/bin/bash
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 24:00:00
#SBATCH --job-name="24hr_QPF"
#SBATCH --export=ALL
#SBATCH --account=cwp130
#SBATCH --mail-user cgrudzien@ucsd.edu
#SBATCH --mail-type BEGIN
#SBATCH --mail-type END
#SBATCH --mail-type FAIL
#####################################################
# Description
#####################################################
# This driver script is based on original source code provided by Rachel Weihs
# and Caroline Papadopoulos.  This is re-written to homogenize project structure
# and to include flexibility with batch processing date ranges of data.
#
# The purpose of this script is to compute grid statistics using MET
# after pre-procssing WRF forecast data and StageIV precip data for
# validating the forecast peformance.
#
#####################################################
# License Statement
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
# SET GLOBAL PARAMETERS 
#####################################################
# uncoment to make verbose for debugging
set -x

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"

# control flow to be processed
CTR_FLW="deterministic_forecast_vbc_early_start_date_test"

# define date range and forecast cycle interval inclusively
START_DT="2019021100"
END_DT="2019021400"
CYCLE_INT="24"

# WRF ISO date times defining range of data processed for each forecast
# initialization as above
ANL_START="2019-02-14_00:00:00"
ANL_END="2019-02-15_00:00:00"

#####################################################
# Process data
#####################################################
# define derived paths
proj_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR"
data_root="${proj_root}/data"
scripts_home="${proj_root}/scripts/analysis/MET_analysis"
stageiv_root="${USR_HME}/DATA/stageIV"
met_root="${USR_HME}/MET_CODE"
met_src="${met_root}/met-10.0.1.sif"
mask_root="${met_root}/polygons"

# Convert START_DT from 'YYYYMMDDHH' format to start_dt in Unix date format, e.g. "Fri May  6 19:50:23 GMT 2005"
if [ `echo "${START_DT}" | awk '/^[[:digit:]]{10}$/'` ]; then
  start_dt=`echo "${START_DT}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  echo "ERROR: start time, '${START_DT}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

start_dt=`date -d "${start_dt}"`

# Convert END_DT from 'YYYYMMDDHH' format to end_dt in isoformat YYYY:MM:DD_HH
if [ `echo "${END_DT}" | awk '/^[[:digit:]]{10}$/'` ]; then
  end_dt=`echo "${END_DT}" | sed 's/\([[:digit:]]\{2\}\)$/ \1/'`
else
  echo "ERROR: end time, '${END_DT}', is not in 'yyyymmddhh' or 'yyyymmdd hh' format"
  exit 1
fi

end_dt=`date +%Y:%m:%d_%H -d "${end_dt}"`

# loop through the date range
cycle_num=0
fcst_hour=0

# directory string
datestr=`date +%Y%m%d%H -d "${start_dt} ${fcst_hour} hours"`

# loop condition
timestr=`date +%Y:%m:%d_%H -d "${start_dt} ${fcst_hour} hours"`

while [[ ! ${timestr} > ${end_dt} ]]; do
  # set working directory based on looped forecast start date
  work_root="${data_root}/analysis/${CTR_FLW}/MET_analysis/${datestr}"

  # Set forecast initialization string
  inityear=${datestr:0:4}
  initmon=${datestr:4:2}
  initday=${datestr:6:2}
  inithr=${datestr:8:2}

  # Set up valid time for verification
  validyear=${ANL_END:0:4}
  validmon=${ANL_END:5:2}
  validday=${ANL_END:8:2}
  validhr=${ANL_END:11:2}
  
  # Set up singularity container
  statement="singularity instance start -B ${work_root}:/work_root:rw,${stageiv_root}:/root_stageiv:rw,${mask_root}:/mask_root:ro,${scripts_home}:/scripts:ro ${met_src} met1"

  echo ${statement}
  eval ${statement}

  # Combine precip to 24 hour 
  # NOTE: this should be re-written in an future version for arbitrary leads
  # based on analysis times
  statement="singularity exec instance://met1 pcp_combine \
  -sum ${inityear}${initmon}${initday}_${inithr}0000 24\
  ${validyear}${validmon}${validday}_${validhr}0000 24 \
  /work_root/wrf_combined_post_${ANL_START}_to_${ANL_END}.nc \
  -field 'name=\"precip_bkt\";  level=\"(*,*,*)\";' -name \"24hr_qpf\" \
  -pcpdir /work_root \
  -pcprx \"wrf_post_${ANL_START}_to_${ANL_END}.nc\" "

  echo ${statement}
  eval ${statement}
  
  # Regrid to Stage-IV
  statement="singularity exec instance://met1 regrid_data_plane \
  /work_root/wrf_combined_post_${ANL_START}_to_${ANL_END}.nc \
  /root_stageiv/StageIV_QPE_${validyear}${validmon}${validday}${validhr}.nc \
  /work_root/regridded_wrf_${ANL_START}_to_${ANL_END}.nc -field 'name=\"24hr_qpf\"; \
  level=\"(*,*)\";' -method BILIN -width 2 -v 1"

  echo ${statement}
  eval ${statement}
  
  statement="singularity exec instance://met1 gen_vx_mask -v 10 \
  /work_root/wrf_combined_post_${ANL_START}_to_${ANL_END}.nc \
  -type poly \
  /mask_root/region/CALatLonPoints.txt \
  /work_root/CA_mask_regridded_with_StageIV.nc"
  echo ${statement}
  eval ${statement}
  
  # RUN GRIDSTAT
  statement="singularity exec instance://met1 grid_stat -v 10 \
  /work_root/regridded_wrf_${ANL_START}_to_${ANL_END}.nc
  /root_stageiv/StageIV_QPE_${validyear}${validmon}${validday}${validhr}.nc \
  /scripts/GridStatConfig
  -outdir /work_root"
  echo ${statement}
  eval ${statement}
  
  # End MET Process and singularity stop
  singularity instance stop met1

  # update the cycle number
  (( cycle_num += 1))
  (( fcst_hour = cycle_num * CYCLE_INT )) 

  # update the date string for directory names
  datestr=`date +%Y%m%d%H -d "${start_dt} ${fcst_hour} hours"`

  # update time string for lexicographical comparison
  timestr=`date +%Y:%m:%d_%H -d "${start_dt} ${fcst_hour} hours"`
done

#####################################################
# end

exit 0