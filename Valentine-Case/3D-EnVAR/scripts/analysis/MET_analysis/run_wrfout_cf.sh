#!/bin/bash

# set environment for COMET
module load ncl_ncarg

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"

# control flow to be processed
CTR_FLW="3denvar_downscale"

# date times defining range of data processed
START_DT="2019021000"
END_DT="2019021100"

# root of all data files for project
data_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data"

# set input paths
input_path_1="${data_root}/cycle_io/${CTR_FLW}/${START_DT}/gsiprd/d01"
input_path_2="${data_root}/cycle_io/${CTR_FLW}/${END_DT}/gsiprd/d01"

# set input file names
file_1="wrfanl_ens_00.2019021000"
file_2="wrfanl_ens_00.2019021100"

# set output path
output_path="${data_root}/analysis/${CTR_FLW}/MET_analysis/${START_DT}"
mkdir -p ${output_path}

# set output file name
output_file="wrf_post_${START_DT}_to_${END_DT}.nc"

statement="ncl 'file_in=\"${input_path_1}/${file_1}\"' 'file_prev=\"${input_path_2}/${file_2}\"                               
    ' 'file_out=\"${output_path}/${output_file}\"' wrfout_to_cf.ncl "

eval ${statement}
