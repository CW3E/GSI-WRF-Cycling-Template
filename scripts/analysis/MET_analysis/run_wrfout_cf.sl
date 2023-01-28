#!/bin/bash
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 03:00:00
#SBATCH --job-name="wrfcf"
#SBATCH --export=ALL
#SBATCH --account=cwp106
#SBATCH --mail-user cgrudzien@ucsd.edu
#SBATCH --mail-type BEGIN
#SBATCH --mail-type END
#SBATCH --mail-type FAIL
#################################################################################
# Description
#################################################################################
# This driver script is designed as a companion to the WRF preprocessing script
# wrfout_to_cf.ncl to ready WRF outputs for MET. This script is based on original
# source code provided by Rachel Weihs, Caroline Papadopoulos and Daniel
# Steinhoff.  This is re-written to homogenize project structure and to include
# flexibility with batch processing ranges of data from multiple workflows.
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
set -x

# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# work in cdo environment
conda activate cdo
echo `conda list`

# set local environment for ncl and dependencies
module load ncl_ncarg

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp106/cgrudzien/GSI-WRF-Cycling-Template"

# define control flow to analyze 
CTR_FLW="deterministic_forecast_lag06_b0.50"

# define the case-wise sub-directory
CSE="VD"

# define date range and cycle interval for forecast start dates
START_DT="2019021100"
END_DT="2019021400"
CYCLE_INT="24"

# define min / max forecast hours and cycle interval for verification after start
ANL_MIN="24"
ANL_MAX="96"
ANL_INT="24"

# define the accumulation interval for verification valid times
ACC_INT="24"

# verification domain for the forecast data
GRD="d02"

# set to regrid to lat / long for MET compatibility when handling grid errors
RGRD="FALSE"

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

if [ ${RGRD} = "TRUE" ]; then
  gres=(0.08 0.027 0.009)
  lat1=(5 29 35)
  lat2=(65 51 40.5)
  lon1=(162 223.5 235)
  lon2=(272 253.5 240.5)
fi

# loop through the cycle date range
cycle_num=0
cycle_hour=0

# directory string for forecast analysis initialization time
dirstr=`date +%Y%m%d%H -d "${start_dt} ${cycle_hour} hours"`

# loop condition for analysis initialization times
loopstr=`date +%Y:%m:%d_%H -d "${start_dt} ${cycle_hour} hours"`

while [[ ! ${loopstr} > ${end_dt} ]]; do
  # set input paths
  if [[ ${CTR_FLW:0:3} = "NRT" ]]; then
    input_path="${in_root}/${dirstr}/wrfout"
  else
    input_path="${in_root}/${dirstr}/wrfprd/ens_00"
  fi
  
  # loop lead hours for forecast valid time for each initialization time
  lead_num=0
  lead_hour=${ANL_MIN}

  while [[ ${lead_hour} -le ${ANL_MAX} ]]; do
    # define valid times for accumulation    
    (( anl_end_hr = lead_hour + cycle_hour ))
    (( anl_start_hr = anl_end_hr - ACC_INT ))
    anl_end=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_end_hr} hours"`
    anl_start=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_start_hr} hours"`

    # set input file names
    file_1="${input_path}/wrfout_${GRD}_${anl_start}"
    file_2="${input_path}/wrfout_${GRD}_${anl_end}"
    
    # set output path
    output_path="${out_root}/${dirstr}/${GRD}"
    mkdir -p ${output_path}
    
    # set output file name
    output_file="wrfcf_${GRD}_${anl_start}_to_${anl_end}.nc"
    out_name="${output_path}/${output_file}"
    
    if [[ -r ${file_1} && -r ${file_2} ]]; then
      cmd="ncl 'file_in=\"${file_2}\"' "
      cmd+="'file_prev=\"${file_1}\"' " 
      cmd+="'file_out=\"${out_name}\"' wrfout_to_cf.ncl "
      
      echo ${cmd}
      eval ${cmd}

      if [ ${RGRD} = "TRUE" ]; then
        # regrids to lat / lon from native grid with CDO
        cmd="cdo -f nc4 sellonlatbox,${lon1},${lon2},${lat1},${lat2} "
        cmd+="-remapbil,global_${gres} "
        cmd+="-selname,precip,precip_bkt,IVT,IVTU,IVTV,IWV "
        cmd+="${out_name} ${out_name}_tmp"
        echo ${cmd}
        eval ${cmd}

        # Adds forecast_reference_time back in from first output
        cmd="ncks -A -v forecast_reference_time ${out_name} ${out_name}_tmp"
        echo ${cmd}
        eval ${cmd}

        # removes temporary data with regridded cf compliant outputs
        cmd="mv ${out_name}_tmp ${out_name}"
        echo ${cmd}
        eval ${cmd}
      fi

    else
      cmd="${file_1} or ${file_2} not readable or does not exist, "
      cmd+="skipping forecast initialization ${loopstr}, "
      cmd+="forecast hour ${lead_hour}."
      echo ${cmd}
    fi

    (( lead_num += 1 )) 
    (( lead_hour = ANL_MIN + lead_num * ANL_INT )) 

  done

  # update the cycle number
  (( cycle_num += 1))
  (( cycle_hour = cycle_num * CYCLE_INT )) 

  # update the date string for directory names
  dirstr=`date +%Y%m%d%H -d "${start_dt} ${cycle_hour} hours"`

  # update time string for lexicographical comparison
  loopstr=`date +%Y:%m:%d_%H -d "${start_dt} ${cycle_hour} hours"`
done

echo "Script completed at `date`, verify outputs at out_root ${out_root}"

#################################################################################
# end

exit 0
