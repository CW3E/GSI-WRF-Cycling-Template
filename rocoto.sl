#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH -t 48:00:00
#SBATCH -J GSI-WRF-Cycling-Template
#SBATCH --export=ALL

# set up rocoto workflow code root
ROCOTO_WORKFLOW_DIR="/cw3e/mead/projects/cwp106/scratch/cgrudzien/GSI_cycling_test/"

# prepend the ROCOTO_WORKFLOW_DIR to the PYTHONPATH to find the workflow call / utilities 
export PYTHONPATH=$ROCOT_WORKFLOW_DIR:$PYTHONPATH

# run rocoto 
python start_rocoto.py
