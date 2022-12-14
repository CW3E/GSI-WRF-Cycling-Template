#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH -t 01:00:00
#SBATCH -J preprocess_ERA5
#SBATCH --export=ALL

##################################################################################
# Description
##################################################################################
# This is a fork of the ERA5 reanalysis preprocessing script written by 
# Xin Zhang, accessed with the ERA5 WRF initialization tutorial at
#
#   https://dreambooker.site/2018/04/20/Initializing-the-WRF-model-with-ERA5/
#
# Last accessed on 2022-11-17 by CJG.
#
# This script is designed to work with an ecmwf_gribtools conda environment for
# the preprocessing the data with gribtools for WRF
#
#     https://anaconda.org/conda-forge/ecmwf_grib
#
# Parameters for the job should be edited in the above, with directory and
# user settings edited in the below.
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
set -x

# start date for the data download
START_DT="2019-02-08"

# end date for the data download
END_DT="2019-02-08"

# location of git clone
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien/TIGGE"

# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

##################################################################################
# Download data
##################################################################################
# directory of ERA5 download
data_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/"
workdir="${data_root}/static/gribbed/ERA5/model_levels"
cd ${workdir}
echo "Move to working directory:"
eval `echo pwd`

# work in eccodes environment
conda activate ecmwf_gribtools
echo `conda list`

# define input and output data
file_in="${START_DT}--${END_DT}_model_levels.grib"
file_out="${START_DT}--${END_DT}_model_levels.grib.1"
grib_set -s deletePV=1,edition=1 ${file_in} ${file_out} 

echo "Finished preprocessing ${file_in} to destination ${file_out}"

exit 0

##################################################################################
# end
