#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH -t 72:00:00
#SBATCH -J download_GEFS
#SBATCH --export=ALL

##################################################################################
# Description
##################################################################################
# This is a companion to the download_GEFS_TIGGE.py script which is designed to
# handle long download times with a scheduled job in SLURM.  Parameters for the
# job should be edited in the above, with directory and user settings edited in
# the below.  Data call settings are set directly in the Python script.
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

# empty dependency conflicts, work in eccodes environment
conda activate eccodes
echo `conda list`

# run rocoto 
python -u download_GEFS_TIGGE.py

echo "Finished download script, verify downloads"

exit 0

##################################################################################
# end
