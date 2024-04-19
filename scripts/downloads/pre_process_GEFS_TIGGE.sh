#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH -t 01:00:00
#SBATCH -J preprocess_ERA5
#SBATCH --export=ALL

##################################################################################
# Description
##################################################################################
# This is a fork of the GEFS preprocessing script written by 
# Dan Steinhoff, Caroline Papadopoulos, et al.
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
#set -x

# start and end date time for the data to be processed
DT="2019-02-08_18:00:00"
END_DT="2019-02-08_00:00:00"

# define date range and increments
#START_TIME=2019020800
#END_TIME=2019021512
#CYCLE_INT=6

# max forecast hour for the data
FCST=6

# pressure levels (pl), surface levels (sl) or static (st) 
LEVELS=("pl" "sl" "st")

# location of git clone
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien/TIGGE"

# ensemble size
N_ENS=20

# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

##################################################################################
# Download data
##################################################################################

# loop over the date range

  # cut date time into sub parts for file names
  dt=`echo ${DT} | cut -c 1-4,6-7,9-10`
  hr=`echo ${DT} | cut -c 12-13`
  dh=`echo ${DT} | cut -c 1-13`
  
  # directory of ERA5 download
  data_root="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/"
  workdir="${data_root}/static/gribbed/GEFS/${dt}"
  cd ${workdir}
  echo "Move to working directory:"
  eval `echo pwd`
  
  # work in eccodes environment
  conda activate ecmwf_gribtools
  echo `conda list`
  
  for level in ${LEVELS[@]}; do
    # define input and output data based on level
    file_in="TIGGE_geps_1-${N_ENS}_${level}_zh_${dh}_fcst_hrs_0-${FCST}.grib"
    file_out="gep[perturbationNumber].t${hr}z.pgrb_${level}.f[forecastTime]"
    echo "Processing ${file_in} to files ${file_out}"
  
    # copy with grib tools splitting on perturbation number and forecast time
    grib_copy ${file_in} ${file_out}
  done
  
  # loop back through files to add padding to forecast hours and perturbation numbers
  out_files=(gep*)
  
  for file in ${out_files[@]}; do
    # split file name on period
    IFS="."
    read -ra split_name <<< "${file}"
    IFS=""
  
    # padd ensemble number
    ens_n=`echo ${split_name[0]} | cut -c 4- `
    ens_n=`printf %02d ${ens_n}`
  
    # padd forecast hour
    fcst_hr=`echo ${split_name[-1]} | cut -c 2-`
    fcst_hr=`printf %03d ${fcst_hr}`
  
    # begin new name construction
    rename="gep${ens_n}"
  
    # loop elements of the split name, excluding first and last
    ii=1
    name_len=${#split_name[@]}
    (( name_len -= 1 ))
  
    while [[ ${ii} -lt ${name_len} ]]; do
     rename+="."
     rename+=${split_name[ii]}
     (( ii += 1 ))
    done
  
    # add last padded element
    rename+="."
    rename+="f${fcst_hr}"
    
    # rename file if not already padded
    if [[ ${file} != ${rename} ]]; then
      mv ${file} ${rename} 
    fi
  done
   
  echo "Finished preprocessing ${file_in} to destination ${file_out}"

exit 0

##################################################################################
# end
