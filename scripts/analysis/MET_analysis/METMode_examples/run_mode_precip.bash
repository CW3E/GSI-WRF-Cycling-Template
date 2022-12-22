#! /bin/bash
# source /home/ldehaan/.bashrc
source /home/mzheng/.bashrc

# Set up netcdf library
#export NETCDF="/apps/netcdf-4.4.1.1_gnu_fortran_4.8.5-11"
#export LD_LIBRARY_PATH="/apps/netcdf-4.4.1.1_gnu_fortran_4.8.5-11/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
#export LD_LIBRARY_PATH="/apps/netcdf-4.4.1.1_gnu_fortran_4.8.5-11/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
#export HDF5="/apps/hdf-1.10.1_gnu_4.8.5-11"
#export LD_LIBRARY_PATH="/apps/hdf-1.10.1_gnu_4.8.5-11/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export file1="wrf.24hrprecip.2019012600_2019020100.nc"
export file2="StageIV_QPE_2019020100.nc"
which ncdump
#source /home/mzheng/.bashrc
which netcdf
which MET_NETCDF
        /apps/MET_8.0_gnu/bin/mode  \
        $file1 \
        $file2 \
	../MODEConfigPrecip_WRF_StageIV_13mm_orig \
	    -outdir ../output
