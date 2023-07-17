#!/bin/bash
#SBATCH -p compute
#SBATCH --nodes=1
#SBATCH --mem=120G
#SBATCH -t 03:00:00
#SBATCH -J build_WRF
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

# Set log report, named with compiler / netcdf version 
export log_version="intelmpi_2019.5.281_netcdf_4.7.4"
export log_file="compile_"$log_version".log"

#Some simple checks
echo "WRF 4.4 compile intel version 2019.5.281, intelmpi, hdf5/1.10.7, and netcdf 4.7.4 on comet" &> $log_file 
echo `module list` >> $log_file  2>&1
echo `which mpif77` >> $log_file  2>&1
echo `which ifort` >> $log_file  2>&1
echo `which ncdump` >> $log_file  2>&1

# Set up WRF directory / configure
echo "setting up compile directory"   >> $log_file  2>&1
./clean -a >> $log_file  2>&1

# uncomment for fresh configuration file
#./configure 

# if making fresh configure note the following
# Use 66  will have AVX2 optimization, needs so flag fixing after configure
# 
# 	64. (serial)  65. (smpar)  66. (dmpar)  67. (dm+sm)   INTEL (ifort/icc): HSW/BDW
# 
# 	1=basic   (for nesting)
# 
# Need to fix the configure.wrf file for COMET configuration:
# 
# 	diff configure.wrf-4.4.2_comet  configure.wrf_66_orig 
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
# 

cmd="cp configure.wrf-4.4.2_comet_2023-02-14 ./configure.wrf  >> $log_file  2>&1"
echo ${cmd}
eval ${cmd}
echo "END setting up compile directory"   >> $log_file  2>&1

echo "Begin wrf compile" >> $log_file 2>&1
# Uncomment to run compile, can be tested to this point
# for debugging without this step
./compile -j 20 em_real >> $log_file 2>&1

echo "End of wrf compile" `date` >> $log_file  2>&1
