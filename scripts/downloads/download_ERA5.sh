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
# initiate bash and source bashrc to initialize environement
conda init bash
source /home/USERNAME/.bashrc

# set the working directory and cd there
CLNE_HME="/cw3e/mead/projects/cwp106/scratch"
scripts="${CLNE_HME}/scripts/downloads"
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

##################################################################################
# end

exit 0
