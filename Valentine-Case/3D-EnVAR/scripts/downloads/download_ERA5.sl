#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH -t 48:00:00
#SBATCH -J download_ERA5
#SBATCH --export=ALL

##################################################################################
# Description
##################################################################################
# This is a companion to the download_ERA5.py script which is designed to handle
# long download times with a scheduled job in SLURM.  Parameters for the job
# should be edited in the above, with directory and user settings edited in the
# below.  The ${levels} variable should be set to one of the pre-defined options
# in the download_ERA5.py script as:
#
#    "model_levels" -- the script will download model level data
#    "surf_levels"  -- the script will download surface level data
#    "pres_levels"  -- the script will download pressure level data
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
# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# set the working directory and cd there
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien/TIGGE"
PRJ_HME="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR"
scripts="${PRJ_HME}/scripts/downloads"
cd ${scripts}
eval `echo pwd`

# define which levels to download, see supported options in download_ERA5.py
levels="model_levels"
echo "Downloading ${levels}"

# empty dependency conflicts, work in eccodes environment
conda activate eccodes
echo `conda list`

# run rocoto 
python -u download_ERA5.py ${levels}

echo "Finished download script, verify downloads"

exit 0

##################################################################################
# end
