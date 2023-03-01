#!/bin/bash
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 01:30:00
#SBATCH --job-name="gridstat"
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
# validating the forecast peformance. Note, bootstrapped confidence intervals
# and rank correlation statitistics are costly to compute and significantly
# increase run time.  For rapid diagnostics these options should be turned off.
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
USR_HME="/cw3e/mead/projects/cwp106/scratch/cgrudzien/GSI-WRF-Cycling-Template"

# control flow to be processed
CTR_FLW="GFS"

# verification domain for the forecast data
GRD="0.25"

# define the case-wise sub-directory
CSE="VD"

# landmask for verification region
MSK="CA_Climate_Zone_16_Sierra"

# root directory for verification data
DATA_ROOT="/cw3e/mead/projects/cwp106/scratch/cgrudzien/DATA"

# root directory for MET software
SOFT_ROOT="/cw3e/mead/projects/cwp106/scratch/cgrudzien/SOFT_ROOT"

# define date range and cycle interval for forecast start dates
START_DT="2019020800"
END_DT="2019021400"
CYCLE_INT="24"

# define min / max forecast hours and cycle interval for verification after start
ANL_MIN="24"
ANL_MAX="240"
ANL_INT="24"

# define the verification field
VRF_FLD="QPF"

# specify thresholds levels for verification
CAT_THR="[ >0.0, >=10.0, >=25.4, >=50.8, >=101.6 ]"

# define the accumulation interval for verification valid times
ACC_INT="24"

# define the interpolation method and related parameters
INT_SHPE="SQUARE"
INT_MTHD="BUDGET"
INT_WDTH="3"

# neighborhodd width for neighborhood methods
NBRHD_WDTH="25"

# number of bootstrap resamplings, set 0 for off
BTSTRP="0"

# rank correlation computation flag, TRUE or FALSE
RNK_CRR="FALSE"

# compute accumulation from cf file, TRUE or FALSE
CMP_ACC="FALSE"

# optionally define an output prefix based on settings
PRFX="${INT_SHPE}_${INT_MTHD}_${INT_WDTH}"

#################################################################################
# Process data
#################################################################################
# define derived paths
cse="${CSE}/${CTR_FLW}"
stageiv_root="${DATA_ROOT}/StageIV"
out_root="${USR_HME}/data/analysis/${cse}/MET_analysis"
scripts_root="${USR_HME}/scripts/analysis/MET_analysis"

# software and data deps.
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
end_dt=`date +%Y-%m-%d_%H -d "${end_dt}"`

# loop through the date range
cycle_num=0
cycle_hour=0

# directory string
dirstr=`date +%Y%m%d%H -d "${start_dt} ${cycle_hour} hours"`

# loop condition
loopstr=`date +%Y-%m-%d_%H -d "${start_dt} ${cycle_hour} hours"`

while [[ ! ${loopstr} > ${end_dt} ]]; do
  # set and clean working directory based on looped forecast start date
  work_root="${out_root}/${dirstr}/${GRD}"
  mkdir -p ${work_root}
  rm -f ${work_root}/grid_stat_${PRFX}_*.txt
  rm -f ${work_root}/grid_stat_${PRFX}_*.stat
  rm -f ${work_root}/grid_stat_${PRFX}_*.nc
  rm -f ${work_root}/GridStatConfig_${PRFX}

  # loop specified lead hours for valid time for each initialization time
  lead_num=0
  lead_hour=${ANL_MIN}

  while [[ ${lead_hour} -le ${ANL_MAX} ]]; do
    # define valid times for accumulation    
    (( anl_end_hr = lead_hour + cycle_hour ))
    (( anl_start_hr = anl_end_hr - ACC_INT ))
    anl_end=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_end_hr} hours"`
    anl_start=`date +%Y-%m-%d_%H_%M_%S -d "${start_dt} ${anl_start_hr} hours"`

    validyear=${anl_end:0:4}
    validmon=${anl_end:5:2}
    validday=${anl_end:8:2}
    validhr=${anl_end:11:2}
    
    # forecast file name based on forecast initialization and lead
    pdd_hr=`printf %03d $(( 10#${lead_hour} ))`
    for_f_in="${CTR_FLW}_${ACC_INT}${VRF_FLD}_${dirstr}_F${pdd_hr}.nc"

    # obs file defined in terms of valid time
    obs_f_in="StageIV_QPE_${validyear}${validmon}${validday}${validhr}.nc"

    # Set up singularity container with directory privileges
    cmd="singularity instance start -B ${work_root}:/work_root:rw,"
    cmd+="${stageiv_root}:/stageiv_root:ro,${mask_root}:/mask_root:ro,"
    cmd+="${scripts_root}:/scripts_root:ro ${met_src} met1"

    echo ${cmd}
    eval ${cmd}

    if [[ ${CMP_ACC} = "TRUE" ]]; then
      # check for input file based on output from run_wrfout_cf.sl
      if [[ -r "${work_root}/wrfcf_${GRD}_${anl_start}_to_${anl_end}.nc" ]]; then
        # Set accumulation initialization string
        inityear=${dirstr:0:4}
        initmon=${dirstr:4:2}
        initday=${dirstr:6:2}
        inithr=${dirstr:8:2}

        # Combine precip to accumulation period 
        cmd="singularity exec instance://met1 pcp_combine \
        -sum ${inityear}${initmon}${initday}_${inithr}0000 ${ACC_INT} \
        ${validyear}${validmon}${validday}_${validhr}0000 ${ACC_INT} \
        /work_root/${PRFX}_${for_f_in} \
        -field 'name=\"precip_bkt\";  level=\"(*,*,*)\";' -name \"${VRF_FLD}_${ACC_INT}hr\" \
        -pcpdir /work_root \
        -pcprx \"wrfcf_${GRD}_${anl_start}_to_${anl_end}.nc\" "
        echo ${cmd}; eval ${cmd}
      
      else
        cmd="pcp_combine input file ${work_root}/wrfcf_${GRD}_${anl_start}_to_${anl_end}.nc is not "
        cmd+="readable or does not exist, skipping pcp_combine for "
        cmd+="forecast initialization ${loopstr}, forecast hour ${lead_hour}." 
        echo ${cmd}
      fi
    else
      # copy the preprocessed data to the working directory from the data root
      in_path="${DATA_ROOT}/${CTR_FLW}/Precip/${dirstr}/${for_f_in}"
      if [[ -r "${in_path}" ]]; then
        cmd="cp -L ${in_path} ${work_root}/${PRFX}_${for_f_in}"
        echo ${cmd}
        eval ${cmd}
      else
        echo "Source file ${in_path} not found."
      fi
    fi
    
    if [[ -r "${work_root}/${PRFX}_${for_f_in}" ]]; then
      if [[ -r "${stageiv_root}/${obs_f_in}" ]]; then
        # masks are recreated depending on the existence of files from previous loops
        # NOTE: need to determine under what conditions would this file need to update
        if [[ ! -r "${work_root}/${MSK}_mask_regridded_with_StageIV.nc" ]]; then
          cmd="singularity exec instance://met1 gen_vx_mask -v 10 \
          /stageiv_root/${obs_f_in} \
          -type poly \
          /mask_root/CA_Climate_Zone/${MSK}.poly \
          /work_root/${MSK}_mask_regridded_with_StageIV.nc"
          echo ${cmd}
          eval ${cmd}
        fi

        # update GridStatConfigTemplate archiving file in working directory unchanged on inner loop
        if [[ ! -r ${work_root}/GridStatConfig ]]; then
          cat ${scripts_root}/GridStatConfigTemplate \
            | sed "s/INT_MTHD/method = ${INT_MTHD}/" \
            | sed "s/INT_WDTH/width = ${INT_WDTH}/" \
            | sed "s/INT_SHPE/shape      = ${INT_SHPE}/" \
            | sed "s/RNK_CRR/rank_corr_flag      = ${RNK_CRR}/" \
            | sed "s/VRF_FLD/name       = \"${VRF_FLD}_${ACC_INT}hr\"/" \
            | sed "s/CAT_THR/cat_thresh = ${CAT_THR}/" \
            | sed "s/PLY_MSK/poly = [ \"\/work_root\/${MSK}_mask_regridded_with_StageIV.nc\" ]/" \
            | sed "s/BTSTRP/n_rep    = ${BTSTRP}/" \
            | sed "s/NBRHD_WDTH/width = [ ${NBRHD_WDTH} ]/" \
            | sed "s/PRFX/output_prefix    = \"${PRFX}\"/" \
            > ${work_root}/GridStatConfig_${PRFX} 
        fi

        # Run gridstat
        cmd="singularity exec instance://met1 grid_stat -v 10 \
        /work_root/${PRFX}_${for_f_in} \
        /stageiv_root/${obs_f_in} \
        /work_root/GridStatConfig_${PRFX} \
        -outdir /work_root"
        echo ${cmd}
        eval ${cmd}
        
      else
        cmd="Observation verification file ${stageiv_root}/${obs_f_in} is not "
        cmd+=" readable or does not exist, skipping grid_stat for forecast "
        cmd+="initialization ${loopstr}, forecast hour ${lead_hour}." 
        echo ${cmd}
      fi

    else
      cmd="gridstat input file ${out_root}/${PRFX}_${for_f_in} is not readable " 
      cmd+=" or does not exist, skipping grid_stat for forecast initialization "
      cmd+="${loopstr}, forecast hour ${lead_hour}." 
      echo ${cmd}
    fi

    # End MET Process and singularity stop
    singularity instance stop met1

    # clean up working directory
    cmd="rm -f ${work_root}/${PRFX}_${for_f_in}"
    echo ${cmd}; eval ${cmd}

    (( lead_num += 1 )) 
    (( lead_hour = ANL_MIN + lead_num * ANL_INT )) 
  done

  # update the cycle number
  (( cycle_num += 1))
  (( cycle_hour = cycle_num * CYCLE_INT )) 

  # update the date string for directory names
  dirstr=`date +%Y%m%d%H -d "${start_dt} ${cycle_hour} hours"`

  # update time string for lexicographical comparison
  loopstr=`date +%Y-%m-%d_%H -d "${start_dt} ${cycle_hour} hours"`
done

echo "Script completed at `date`, verify outputs at out_root ${out_root}"

#################################################################################
# end

exit 0
