#!/bin/bash

# WPS configure and compile steps, based on COMET tutorial for
# WRF v4.4 / WPS 4.4
# sets COMET specific environment for intelmpi 2019.5.281

# NOTE: set serial (0) or parallel (1) build with the below
export wps_thread=0

# change to intel mpi
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2019.5.281
module load intelmpi/2019.5.281

# set up zlib, libpng, jasperlib
#module load jasper
#Use this for non module version, note issues with DART
export JASPERLIB="/usr/lib64"
export JASPERINC="/usr/include"
export LD_LIBRARY_PATH=/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Set up netcdf
export MODULEPATH=/share/apps/compute/modulefiles/applications:$MODULEPATH
module load hdf5/1.10.7
module load netcdf/4.7.4intelmpi
export NETCDF="/share/apps/compute/netcdf/intel2019/intelmpi"
export HDF5="/share/apps/compute/hdf5/intel2019/intelmpi"

# Set up compiler version:
export log_version="intelmpi_2019.5.281_netcdf_4.7.4"
export log_file="compile_"$log_version".log"

#Some simple checks
echo "WPS 4.4 compile intel version 2019.5.281, intelmpi, hdf5/1.10.7, and netcdf 4.7.4 on comet" &> $log_file 
echo `module list` >> $log_file  2>&1
echo `which mpif77` >> $log_file  2>&1
echo `which ifort` >> $log_file  2>&1
echo `which ncdump` >> $log_file  2>&1
echo `ls -l $JASPERLIB/libjasper.so` >>  $log_file  2>&1
echo `ls -ltr $JASPERLIB/libjasper.so.1.0.0`  >>  $log_file  2>&1
echo `ls -l $JASPERLIB/libpng.so` >>  $log_file  2>&1
echo `ls -l $JASPERLIB/libpng15.so` >>  $log_file  2>&1
echo `ls -l $JASPERLIB/libz.so` >> $log_file  2>&1
echo `ls -l $JASPERLIB/libz.so.1.2.7` >> $log_file  2>&1
echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}" >> $log_file  2>&1

# Set up WPS directory / configure
echo "setting up compile directory"   >> $log_file  2>&1
./clean -a >> $log_file  2>&1

# use serial (0) or parallel (1) configuration files
if [ "$wps_thread" -eq 0 ]
then
    echo "WPS serial build configuration" >> $log_file 2>&1
    cp configure.wps-4.4_intelmpi_2019.5.281_comet_serial ./configure.wps  >> $log_file  2>&1
elif [ "$wps_thread" -eq 1 ]
then
    echo "WPS parallel build configuration" >> $log_file 2>&1
    cp configure.wps-4.4_intelmpi_2019.5.281_comet_parallel ./configure.wps  >> $log_file  2>&1
fi

#./configure 
echo "END setting up compile directory"   >> $log_file  2>&1

# compile 
echo "Begin WPS compile" >> $log_file 2>&1
./compile  >> $log_file  2>&1
echo "End of WPS compile" `date` >> $log_file  2>&1
