#!/bin/bash
set -x

# WRFDA configure and compile steps, based on COMET tutorial for
# WRF v4.4 / WPS 4.4
# sets COMET specific environment for intelmpi 2019.5.281
# change to intel mpi
module purge
export MODULEPATH=/share/apps/compute/modulefiles:$MODULEPATH
module load intel/2019.5.281
module load intelmpi/2019.5.281

# set up zlib, libpng, jasperlib
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

# WRFDA specific, from Michael Murphy
export BUFR=1
export CRTM=1
export NETCDF_classic=1 # have to turn classic on or it complains

# Set log report, named with compiler / netcdf version 
export log_version="intelmpi_2019.5.281_netcdf_4.7.4"
export log_file="compile_"$log_version".log"

#Some simple checks
echo "WRFDA 4.4 compile intel version 2019.5.281, intelmpi, hdf5/1.10.7, and netcdf 4.7.4 on comet" &> $log_file 
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

# Set up WRFDA directory / configure
echo "setting up compile directory"   >> $log_file  2>&1
./clean -aa >> $log_file  2>&1

# uncomment for fresh configuration file
#./configure wrfda
#
# if making fresh configure note the following
# Use 66  will have AVX2 optimization, needs so flag fixing after configure
# 
# 	64. (serial)  65. (smpar)  66. (dmpar)  67. (dm+sm)   INTEL (ifort/icc): HSW/BDW
# 
# 	1=basic   (for nesting)
# 
# Need to fix the configure.wrf file for COMET configuration:
# 
# 	% cp -pr configure.wrf  configure.wrf_66_orig
# 	% cp -pr configure.wrf configure.wrf-4.3.1_intelmpi_2019.5.281_comet
# 
# edit configure.wrf-4.3.1_intelmpi_2019.5.281_comet :
# 
# 	(base) [cpapadop@comet-ln2 WRF-4.3.1]$ diff configure.wrf-4.3.1_intelmpi_2019.5.281_comet  configure.wrf_66_orig 
# 	142,144c142,143
# 	< OPTAVX          =       -xCORE-AVX2
# 	< CFLAGS_LOCAL    =       -w -O3 -ip $(OPTAVX) #-xHost -fp-model fast=2 -no-prec-div -no-prec-sqrt -ftz -no-multibyte-chars -xCORE-AVX2 # -DRSL0_ONLY
# 	< LDFLAGS_LOCAL   =       -ip $(OPTAVX) #-xHost -fp-model fast=2 -no-prec-div -no-prec-sqrt -ftz -align all -fno-alias -fno-common -xCORE-AVX2
# 	---
# 	> CFLAGS_LOCAL    =       -w -O3 -ip -xHost -fp-model fast=2 -no-prec-div -no-prec-sqrt -ftz -no-multibyte-chars -xCORE-AVX2 # -DRSL0_ONLY
# 	> LDFLAGS_LOCAL   =       -ip -xHost -fp-model fast=2 -no-prec-div -no-prec-sqrt -ftz -align all -fno-alias -fno-common -xCORE-AVX2
# 	147c146
# 	< FCOPTIM         =       -O3 $(OPTAVX)
# 	---
# 	> FCOPTIM         =       -O3
# 	156c155
# 	< FCBASEOPTS_NO_G =       -ip -fp-model precise -w -ftz -align all -fno-alias $(FORMAT_FREE) $(BYTESWAPIO) $(OPTAVX) #-xHost -fp-model fast=2 -no-heap-arrays -no-prec-div -no-prec-sqrt -fno-common -xCORE-AVX2
# 	---
# 	> FCBASEOPTS_NO_G =       -ip -fp-model precise -w -ftz -align all -fno-alias $(FORMAT_FREE) $(BYTESWAPIO) -xHost -fp-model fast=2 -no-heap-arrays -no-prec-div -no-prec-sqrt -fno-common -xCORE-AVX2
# 	(base) [cpapadop@comet-ln2 WRF-4.3.1]$ 
# 	
# 
cp configure.wrfda-4.4_intelmpi_2019.5.281_comet ./configure.wrf  >> $log_file  2>&1
echo "END setting up compile directory"   >> $log_file  2>&1


echo "Begin wrf compile" >> $log_file 2>&1
# Uncomment to run compile, can be tested to this point
# for debugging without this step
./compile -j 20 all_wrfvar >> $log_file 2>&1

echo "End of WRFDA compile" `date` >> $log_file  2>&1
