#!/bin/bash
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 24:00:00
#SBATCH --job-name="run_stageIV_24hr"
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
# and to include felibility with processing date ranges of data.
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
CTR_FLW="deterministic_forecast_early_start_date_test"

# date times defining range of data processed
START_DT="2019021100"
END_DT="2019021100"

# SET UP VALID TIME
sd=2019-02-10
tt=00
      
# define date range and forecast cycle interval
START_DT="2019021100"
END_DT="2019021400"

# WRF ISO date times defining range of data processed
ANL_START="2019-02-14_00:00:00"
ANL_END="2019-02-15_00:00:00"

VALIDYEAR=${sd:0:4}
VALIDMON=${sd:5:2}
VALIDDAY=${sd:8:2}
VALIDHR=${tt}

# SET UP DIRECTORIES OF INPUT/OUTPUT/OBSERVATIONS
# change as a function of lead time, just 1-day lead time for now
lt=1
INITDAY=`expr ${VALIDDAY} - ${lt}`

#####################################################
# Process data
#####################################################
# define derived data paths
proj_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR"
data_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data"
work_root="${data_root}/analysis/${CTR_FLW}/MET_analysis/${START_DT}"
stage_iv_root="${USR_HME}/stageIV"
scripts_home="${proj_root}/scripts/analysis/MET_analysis"
mask_polygon_root="/cw3e/mead/projects/cwp129/cw3e_MET_verification/common_polygons/region/"

## MET Singularity Path
metsrc="${USR_HME}/MET_CODE/met-10.0.0.sif"

# Set up singularity container
echo "singularity instance start -B  ${work_root}:/work_root:rw,${stage_iv_root}:/root_stageiv:ro,${scripts_home}:/scripts:ro ${metsrc} met1"  
singularity instance start -B ${work_root}:/work_root:rw,${stage_iv_root}:/root_stageiv:ro,${mask_polygon_root}:/root_mask:ro,${scripts_home}:/scripts:ro ${metsrc} met1 

## Combine 3-hr precip to 24-hr
statement="singularity exec instance://met1 pcp_combine \
-sum 00000000_000000 1 ${VALIDYEAR}${VALIDMON}${VALIDDAY}_${VALIDHR}0000 24 \
/work_root/test_NRT_pcpcombine_${START_DT}_24A.nc \
-field 'name=\"precip_bkt\";  level=\"(*,*,*)\";' -name \"24hr_qpf\" \
-pcpdir /input \
-pcprx \"wrfcf_gfs_d02_\" \
-v 1"
echo $statement
eval $statement
ST4.2019021400.01h.gz
## Regrid to Stage-IV
statement="singularity exec instance://met1 regrid_data_plane \
/work_root/test_NRT_pcpcombine_${START_DT}_24A.nc \
/root_stageiv/ST4.${START_DT}.nc \
/work_root/regridded_NRT_pcpcombine_${START_DT}_24A.nc -field 'name=\"24hr_qpf\";  level=\"(*,*)\";'  -method BILIN -width 2 -v 1"
echo $statement
eval $statement

## Create mask for Russian River watershed - note, do not need to run this each time, should set up StageIV specific path
statement="singularity exec instance://met1 gen_vx_mask -v 10 \
/work_root/regridded_NRT_pcpcombine_${START_DT}_24A.nc \
-type poly \
/root_mask/Russian_LatLonPoints.txt \
/work_root/Russian_mask_regridded_NRT_pcpcombine_with_StageIV.nc"
echo $statement
eval $statement

## RUN GRIDSTAT
statement="singularity exec instance://met1 grid_stat -v 10 \
/work_root/regridded_NRT_pcpcombine_${START_DT}_24A.nc
/root_stageiv/ST4.${START_DT}.nc \
/scripts/GridStatConfig
-outdir /work_root"
echo $statement
eval $statement

# End MET Process and singularity stop
singularity instance stop met1

# Archive Notes
#singularity exec /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif ls /usr/local/bin
#singularity exec -B /cw3e/mead/projects/cwp129/weihsr/scratch/:/input:ro /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif pcp_combine -sum 00000000_000000 1 20211229_000000 3 /output\test_NRT_pcpcombine_20211229_24A.nc -field 'name="precip";  level="(*,*,*)";' -name "24hr_qpf" -pcpdir /input -pcprx "wrfcf_gfs_d02_" 
#singularity exec -B /cw3e/mead/datasets/cw3e/NRT/2021-2022/NRT_gfs/2021122800/cf/:/input:ro /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif ls /input

## Get default config file from src
#singularity exec -B /cw3e/mead/projects/cwp129/cw3e_MET_verification/driver_scripts:/scripts:rw /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif cp /usr/local/share/met/config/GridStatConfig_default /scripts

#singularity exec instance://met1 pcp_combine -sum 00000000_000000 1 20211229_000000 24 test_NRT_pcpcombine_20211229_24A.nc -field 'name="precip";  level="(L0,*,*)";' -name "24hr_qpf"
#####################################################
# end

exit 0
