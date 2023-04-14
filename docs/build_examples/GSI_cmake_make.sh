#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 03:00:00
#SBATCH -J build_GSI
#SBATCH --export=ALL

# set COMET`specific environment for intelmpi 2018.1.163
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2018.1.163
module load intelmpi/2018.1.163

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
module load hdf5/1.10.3
module load netcdf/4.6.1
export NETCDF="/opt/netcdf/4.6.1/intel/intelmpi/"
export HDF5="/opt/hdf5/1.10.3/intel/intelmpi/"

# setup lapack
module load lapack
export LAPACK_PATH=" /share/apps/compute/lapack"

# Set log report, named with compiler / netcdf version 
export log_version="intelmpi_2018.1.163_netcdf_4.6.1"
export log_file="compile_"$log_version".log"

#Some simple checks
echo "comGSIv3.7_EnKFv1.3 Intel version 2018.1.163, netcdf 4.6.1, hdf5 1.10.3, intelmpi on comet" &> $log_file 
echo `module list` >> $log_file  2>&1
echo `which mpif77` >> $log_file  2>&1
echo `which ifort` >> $log_file  2>&1
echo `which ncdump` >> $log_file  2>&1

# Cmake step 
echo "Run cmake"   >> $log_file  2>&1
cmake ../comGSIv3.7_EnKFv1.3 >> $log_file  2>&1
echo "END cmake"   >> $log_file  2>&1

# make step -- build GSI
echo "Begin GSI compile" >> $log_file 2>&1
make -j 20 VERBOSE=1 >> $log_file 2>&1
make VERBOSE=1 >> $log_file 2>&1
echo "End of GSI compile" `date` >> $log_file  2>&1
