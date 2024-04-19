#!/bin/bash
#SBATCH -p compute 
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=6
#SBATCH --mem-per-cpu=5G
#SBATCH -t 01:00:00
#SBATCH -J batch_process_data 
#SBATCH --export=ALL
#SBATCH --array=0-3
##################################################################################
# Description
##################################################################################
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
# SET GLOBAL PARAMETERS
##################################################################################
# set the  git clone directory, case study and control flow
USR_HME="/cw3e/mead/projects/cwp106/scratch/GSI-WRF-Cycling-Template"
CSE="VD"
CTR_FLW="deterministic_forecast_lag00_b0.00"

# define date range and increments for start time of simulations
START_TIME=2019021100
END_TIME=2019021400
CYCLE_INT=24

# starting forecast hour to process
FCST_MIN=24

# interval of forecast data outputs after FCST_MIN to process
FCST_INT=24

# max forecast hour to process
FCST_MAX=96

##################################################################################
# Contruct job array and environment for submission
##################################################################################
# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# empty dependency conflicts (esp NetCDF), work in wrf_py environment
module purge
echo `module list`
conda activate /home/cgrudzien/miniconda3/envs/wrf_py
echo `conda list`

# define derived paths
wrk_dir="${USR_HME}/scripts/analysis/WRF_analysis"
echo "Work directory ${wrk_dir}"

in_root="${USR_HME}/data/simulation_io/${CSE}/${CTR_FLW}"
echo "Data input root ${in_root}"

out_root="${USR_HME}/data/analysis/${CSE}/${CTR_FLW}/WRF_analysis"
echo "Data output root ${out_root}"

# create arrays to store the date dependent paths
in_paths=()
out_paths=()

# Convert START_TIME from 'YYYYMMDDHH' format to start_time Unix date format
start_time="${START_TIME:0:8} ${START_TIME:8:2}"
start_time=`date -d "${start_time}"`

# Convert END_TIME from 'YYYYMMDDHH' format to start_time Unix date format
# end time is used a loop condition for date range
end_time="${END_TIME:0:8} ${END_TIME:8:2}"
end_time=`date -d "${end_time}"`
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
while [[ ${timestr} < ${end_time} ]]; do
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
