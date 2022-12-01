#!/bin/bash
#SBATCH -p compute 
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=12
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=5G
#SBATCH -t 32:00:00
#SBATCH -J batch_process_data 
#SBATCH --export=ALL
#SBATCH --array=0-13

# initiate bash and source bashrc to initialize environement
conda init bash
source /home/cgrudzien/.bashrc

# set the git clone and working directory
USR_HME="/cw3e/mead/projects/cwp130/scratch/cgrudzien"
workdir="$USR_HME/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/scripts/analysis/WRF_analysis"
cd $workdir
eval `echo pwd`

# define the date of the data to process
data_dates=(2019020900 2019020912 2019021000 2019021012 2019021100 2019021112 2019021200 2019021212 2019021300 2019021312 2019021400 2019021412 2019021500 2019021512)
data_date=${data_dates[$SLURM_ARRAY_TASK_ID]}
data_directory="wrfprd/ens_00" 
data_path="$USR_HME/data/cycle_io/$data_date/$data_directory/"
echo $data_path

# empty dependency conflicts, work in wrf_py environment
module purge
echo `module list`
conda activate wrf_py
echo `conda list`

# run the processing script with input of the data path
echo "Processing data"
python -u proc_wrfout_NetCDF.py $data_path >> process_${data_dates[$SLURM_ARRAY_TASK_ID]}.log 2>&1 
