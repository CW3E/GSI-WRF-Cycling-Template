#!/bin/bash

set -x

# set environment for COMET
module purge
module load ncl_ncarg
module list

# root directory for git clone
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"

# set input paths
input_path_1="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/cycle_io/2019021400/gsiprd/d01"
input_path_2="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/cycle_io/2019021500/gsiprd/d01"

# set input file names
file_1="wrfanl_ens_00.2019021400"
file_2="wrfanl_ens_00.2019021500"

# set output path
output_path="."

# set output file name
output_file="wrf_post.nc"

statement="ncl 'file_in=\"${input_path_1}/${file_1}\"' 'file_prev=\"${input_path_2}/${file_2}\"                               
    ' 'file_out=\"${output_path}/${output_file}\"' wrfout_to_cf.ncl "

eval ${statement}
