#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH -t 48:00:00
#SBATCH -J download_ERA5
#SBATCH --export=ALL

# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# set the git clone and working directory
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"
workdir="${USR_HME}/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/static/gribbed"
cd ${workdir}
eval `echo pwd`

# define which levels to download, see supported options in download_ERA5.py
levels="model_levels"
echo "Downloading ${levels}"

# empty dependency conflicts, work in wrf_py environment
module purge
echo `module list`
conda activate eccodes
echo `conda list`

# run rocoto 
python -u download_ERA5.py ${levels}
