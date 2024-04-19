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
