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
source /home/cgrudzien/.bashrc

# set the working directory and cd there
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"
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
