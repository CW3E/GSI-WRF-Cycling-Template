#!/bin/bash
#SBATCH -p compute 
#SBATCH --nodes=7
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=6
#SBATCH --mem-per-cpu=5G
#SBATCH -t 04:00:00
#SBATCH -J batch_process_data 
#SBATCH --export=ALL
#SBATCH --array=0-25
##################################################################################
# Description
##################################################################################
#
##################################################################################
# License Statement
##################################################################################
#
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
# SET GLOBAL PARAMETERS
##################################################################################
# set the control flow, git clone and working directory
USR_HME="/cw3e/mead/projects/cwp106/scratch/cgrudzien"
PRJ_DIR="${USR_HME}/GSI-WRF-Cycling-Template/Common-Case/3D-EnVAR"
CTR_FLW="deterministic_forecast_treatment_run"

# define date range and increments for start time of simulations
START_TIME=2021012200
END_TIME=2021012800
CYCLE_INT=24

# starting forecast hour to process
FCST_MIN=0

# interval of forecast data outputs after FCST_MIN to process
FCST_INT=24

# max forecast hour to process
FCST_MAX=120

##################################################################################
# Contruct job array and environment for submission
##################################################################################
# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# empty dependency conflicts (esp NetCDF), work in wrf_py environment
module purge
echo `module list`
conda activate wrf_py
echo `conda list`

# define derived paths
wrk_dir="${PRJ_DIR}/scripts/analysis/WRF_analysis"
echo "Work directory $wrk_dir"

in_root="${PRJ_DIR}/data/simulation_io/${CTR_FLW}"
echo "Data input root $in_root"

out_root="${PRJ_DIR}/data/analysis/${CTR_FLW}/WRF_analysis"
echo "Data output root $out_root"

# create arrays to store the date dependent paths
in_paths=()
out_paths=()

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

# end time is used a loop condition for date range
end_time=`date +%Y-%m-%d_%H:%M:%S -d "${end_time}"`

# loop through the date range and construct the IO paths
cycle_num=0
start_hour=0

# directory string
datestr=`date +%Y%m%d%H -d "${start_time} ${start_hour} hours"`

# loop condition and start time iso string
timestr=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${start_hour} hours"`

# initialize array for start times of forecasts in iso format
start_times=()

echo "For each start time:"
while [[ ! ${timestr} > ${end_time} ]]; do
  # update the date string for directory names
  datestr=`date +%Y%m%d%H -d "${start_time} ${start_hour} hours"`
  in_paths+=("${in_root}/${datestr}/wrfprd/ens_00")
  out_paths+=("${out_root}/${datestr}")

  # update time string for lexicographical comparison and read in python
  timestr=`date +%Y-%m-%d_%H:%M:%S -d "${start_time} ${start_hour} hours"`
  start_times+=("${timestr}")

  # update the cycle number
  (( cycle_num += 1))
  (( start_hour = cycle_num * CYCLE_INT ))

done

##################################################################################
# run the processing script calling the data paths, start times and fcst hrs
cd ${wrk_dir}
echo "Running from working directory `pwd`"
indx=${SLURM_ARRAY_TASK_ID}

echo "Processing data for job index ${indx}"
in_i=${in_paths[$indx]}
out_i=${out_paths[$indx]}
start_i=${start_times[$indx]}

statement="python -u proc_wrfout_np.py ${in_i} ${out_i} ${start_i} ${FCST_MIN}"
statement+=" ${FCST_INT} ${FCST_MAX} > process_${start_i}.log 2>&1"

echo ${statement}
eval ${statement}

##################################################################################
# end

exit 0
