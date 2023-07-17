#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 03:00:00
#SBATCH -J build_WPS
#SBATCH --export=ALL

# sets COMET specific environment for intelmpi 2019.5.281
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2019.5.281
module load intelmpi/2019.5.281

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
module load hdf5/1.10.7
module load netcdf/4.7.4intelmpi
export NETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export HDF5="/share/apps/compute/hdf5/intel2019/intelmpi"

# Set up compiler version:
export log_version="intelmpi_2019.5.281_netcdf_4.7.4"
export log_file="compile_"$log_version".log"

# Some simple checks
echo "WPS 4.4.2 compile intel version 2019.5.281, intelmpi, hdf5/1.10.7, and netcdf 4.7.4 on comet" &> $log_file 
echo `module list` >> $log_file  2>&1
echo `which mpif77` >> $log_file  2>&1
echo `which ifort` >> $log_file  2>&1
echo `which ncdump` >> $log_file  2>&1

# Set up WPS directory / configure
echo "setting up compile directory"   >> $log_file  2>&1
./clean -a >> $log_file  2>&1

# Uncomment for a fresh configuration uses built-in Jasper, use option for
# Linux x86_64, Intel compiler    (dmpar)
# for COMET
#./configure --build-grib2-libs

cmd="cp configure.wps-4.4.2_comet_2023-02-14 ./configure.wps  >> $log_file  2>&1"
echo ${cmd}
eval ${cmd}
echo "END setting up compile directory"   >> $log_file  2>&1

# compile 
echo "Begin WPS compile" >> $log_file 2>&1
./compile  >> $log_file  2>&1
echo "End of WPS compile" `date` >> $log_file  2>&1
