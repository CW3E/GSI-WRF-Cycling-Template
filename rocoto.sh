#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH -t 120:00:00
#SBATCH -J GSI-WRF-Cycling-Template
#SBATCH --export=ALL

# run rocoto 
python -u rocoto_utilities.py
