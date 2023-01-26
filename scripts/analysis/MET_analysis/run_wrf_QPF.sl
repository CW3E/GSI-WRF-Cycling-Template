#!/bin/bash
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 24:00:00
#SBATCH --job-name="wrf_QPF"
#SBATCH --export=ALL
#SBATCH --account=cwp106
#SBATCH --mail-user cgrudzien@ucsd.edu
#SBATCH --mail-type BEGIN
#SBATCH --mail-type END
#SBATCH --mail-type FAIL
#################################################################################
# Description
#################################################################################
# This driver script is based on original source code provided by Rachel Weihs
# and Caroline Papadopoulos.  This is re-written to homogenize project structure
# and to include flexibility with batch processing date ranges of data.
#
# The purpose of this script is to compute grid statistics using MET
# after pre-procssing WRF forecast data and StageIV precip data for
# validating the forecast peformance.  Note, some options must be set in the
# companion GridStatConfig file, e.g., the option
#
#   rank_corr_flag      = TRUE;
#
# directs the computation of robust statistics such as Spearman rank correlation.
# These options are costly to compute and significantly increase run time.  For
# rapid diagnostics this can be set to false. 
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

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp129/cgrudzien/GSI-WRF-Cycling-Template"

# control flow to be processed
CTR_FLW="NRT_ecmwf"

# define the case-wise sub-directory
CSE="DD"

# landmask for verification region
MSK="CALatLonPoints"

# root directory for verification data
DATA_ROOT="/cw3e/mead/projects/cnt102/METMODE_PreProcessing/data/StageIV"

# root directory for MET software
SOFT_ROOT="/cw3e/mead/projects/cwp130/scratch/cgrudzien"

# define date range and cycle interval for forecast start dates
START_DT="2022121600"
END_DT="2023011800"
CYCLE_INT="24"

# define min / max forecast hours and cycle interval for verification after start
ANL_MIN="24"
ANL_MAX="240"
ANL_INT="24"

# define the accumulation interval for verification valid times
ACC_INT="24"

# verification domain for the forecast data
DMN="1"

# neighborhodd width for neighborhood methods
NBRHD_WDTH="3"

# number of bootstrap resamplings, set 0 for off
BTSTRP="0"

# Rank correlation computation flag, TRUE or FALSE
RNK_CRR="FALSE"

#################################################################################
# Process data
#################################################################################
# define derived paths
cse="${CSE}/${CTR_FLW}"
in_root="${USR_HME}/data/simulation_io/${cse}"
out_root="${USR_HME}/data/analysis/${cse}/MET_analysis"
scripts_root="${USR_HME}/scripts/analysis/MET_analysis"

# software and data deps.
stageiv_root="${DATA_ROOT}"
met_src="${SOFT_ROOT}/MET_CODE/met-10.0.1.sif"
mask_root="${SOFT_ROOT}/MET_CODE/polygons"

# change to scripts directory
cmd="cd ${scripts_root}"
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
cycle_hour=0

# directory string
dirstr=`date +%Y%m%d%H -d "${start_dt} ${cycle_hour} hours"`

# loop condition
loopstr=`date +%Y:%m:%d_%H -d "${start_dt} ${cycle_hour} hours"`

while [[ ! ${loopstr} > ${end_dt} ]]; do
  # set and clean working directory based on looped forecast start date
  work_root="${out_root}/${dirstr}/d0${DMN}"
  rm -f ${work_root}/grid_stat_*.txt
  rm -f ${work_root}/grid_stat_*.stat
  rm -f ${work_root}/grid_stat_*.nc
  rm -f ${work_root}/GridStatConfig

  # loop specified lead hours for valid time for each initialization time
  lead_num=0
  lead_hour=${ANL_MIN}

  while [[ ${lead_hour} -le ${ANL_MAX} ]]; do
    # define valid times for accumulation    
    (( anl_end_hr = lead_hour + cycle_hour ))
    (( anl_start_hr = anl_end_hr - ACC_INT ))
    anl_end=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_end_hr} hours"`
    anl_start=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_start_hr} hours"`

    # Set accumulation initialization string
    inityear=${dirstr:0:4}
    initmon=${dirstr:4:2}
    initday=${dirstr:6:2}
    inithr=${dirstr:8:2}

    # Set up valid time for verification
    validyear=${anl_end:0:4}
    validmon=${anl_end:5:2}
    validday=${anl_end:8:2}
    validhr=${anl_end:11:2}
    
    # Set up singularity container
    statement="singularity instance start -B ${work_root}:/work_root:rw,${stageiv_root}:/stageiv_root:rw,${mask_root}:/mask_root:ro,${scripts_root}:/scripts_root:ro ${met_src} met1"

    echo ${statement}
    eval ${statement}

    # Combine precip to accumulation period 
    statement="singularity exec instance://met1 pcp_combine \
    -sum ${inityear}${initmon}${initday}_${inithr}0000 ${ACC_INT} \
    ${validyear}${validmon}${validday}_${validhr}0000 ${ACC_INT} \
    /work_root/wrfacc_d0${DMN}_${anl_start}_to_${anl_end}.nc \
    -field 'name=\"precip_bkt\";  level=\"(*,*,*)\";' -name \"${ACC_INT}hr_qpf\" \
    -pcpdir /work_root \
    -pcprx \"wrfcf_d0${DMN}_${anl_start}_to_${anl_end}.nc\" "

    echo ${statement}
    eval ${statement}
    
    # Regrid to Stage-IV
    statement="singularity exec instance://met1 regrid_data_plane \
    /work_root/wrfacc_d0${DMN}_${anl_start}_to_${anl_end}.nc \
    /stageiv_root/StageIV_QPE_${validyear}${validmon}${validday}${validhr}.nc \
    /work_root/regridded_wrf_d0${DMN}_${anl_start}_to_${anl_end}.nc -field 'name=\"${ACC_INT}hr_qpf\"; \
    level=\"(*,*)\";' -method BILIN -width 2 -v 1"

    echo ${statement}
    eval ${statement}
    
    # masks are recreated depending on the existence of files from previous loops
    if [[ ! -r ${work_root}/${MSK}_mask_regridded_with_StageIV.nc ]]; then
      statement="singularity exec instance://met1 gen_vx_mask -v 10 \
      /work_root/wrfacc_d0${DMN}_${anl_start}_to_${anl_end}.nc \
      -type poly \
      /mask_root/region/${MSK}.txt \
      /work_root/${MSK}_mask_regridded_with_StageIV.nc"
      echo ${statement}
      eval ${statement}
    fi
    
    # update the GridStatConfigTemplate keeping file in working directory unchanged on inner loop
    if [[ ! -r ${work_root}/GridStatConfig ]]; then
      cat ${scripts_root}/GridStatConfigTemplate \
        | sed "s/NBRHD_WDTH/width = [ ${NBRHD_WDTH} ]/" \
        | sed "s/PLY_MSK/poly = [ \"\/work_root\/${MSK}_mask_regridded_with_StageIV.nc\" ]/" \
        | sed "s/RNK_CRR/rank_corr_flag      = ${RNK_CRR}/" \
        | sed "s/BTSTRP/n_rep    = ${BTSTRP}/" \
        > ${work_root}/GridStatConfig 
    fi

    # RUN GRIDSTAT
    statement="singularity exec instance://met1 grid_stat -v 10 \
    /work_root/regridded_wrf_d0${DMN}_${anl_start}_to_${anl_end}.nc
    /stageiv_root/StageIV_QPE_${validyear}${validmon}${validday}${validhr}.nc \
    /work_root/GridStatConfig
    -outdir /work_root"
    echo ${statement}
    eval ${statement}
    
    # End MET Process and singularity stop
    singularity instance stop met1

    # clean up working directory
    cmd="rm ${work_root}/wrfacc_d0${DMN}_${anl_start}_to_${anl_end}.nc"
    echo ${cmd}
    eval ${cmd}

    cmd="rm ${work_root}/regridded_wrf_d0${DMN}_${anl_start}_to_${anl_end}.nc"
    echo ${cmd}
    eval ${cmd}

    (( lead_num += 1 )) 
    (( lead_hour = ANL_MIN + lead_num * ANL_INT )) 
  done

  cmd="rm ${work_root}/${MSK}_mask_regridded_with_StageIV.nc"
  echo ${cmd}
  eval ${cmd}

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
