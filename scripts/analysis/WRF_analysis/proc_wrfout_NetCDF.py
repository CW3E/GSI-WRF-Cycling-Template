##################################################################################
# Description
##################################################################################
# This script is designed to work with the companion batch_process_wrfout.sl
# in order to ingest wrf output files over a date range specified by the slurm
# job array and to output interpolated fields defined below into batch files
# with times concatenated over arbitrary ranges.
#
# This is a partial merge of the script into this code base and hasn't been
# fully tested.
#
##################################################################################
# License Statement:
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# 
##################################################################################
# imports
from netCDF4 import Dataset
import sys
import time
import math
import glob
import numpy as np
from wrf import (
                 getvar, interplevel, extract_vars, ALL_TIMES,
                 omp_set_num_threads, omp_get_num_procs, omp_enabled,
                )
from wrf_py_utilities import (
                              USR_HME, STR_INDT, process_D3_vars,
                              process_D3_raw_vars
                             )

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# I/O parameters
CTR_FLW = 'deterministic_forecast'
DOMAIN = 'd02'
F_IN_PATH = sys.argv[1] 
print(F_IN_PATH)
F_OUT_PATH = PROJ_ROOT + 'data/analysis/forecast_io/' +\
             CTR_FLW + '/processed_wrf_out/'

# number of files processed per outfile
N_PER_OUT = 1

# pressure levels to interpolate to
PLS = [
       0.0050,    0.0161,    0.0384,    0.0769,    0.1370,    0.2244,    
       0.3454,    0.5064,    0.7140,    0.9753,    1.2972,    1.6872,
       2.1526,    2.7009,    3.3398,    4.0770,    4.9204,    5.8776,
       6.9567,    8.1655,    9.5119,    11.0038,   12.6492,   14.4559,
       16.4318,   18.5847,   20.9224,   23.4526,   26.1829,   29.1210,
       32.2744,   35.6505,   39.2566,   43.1001,   47.1882,   51.5278,
       56.1260,   60.9895,   66.1253,   71.5398,   77.2396,   83.2310,
       89.5204,   96.1138,   103.0172,  110.2366,  117.7775,  125.6456,
       133.8462,  142.3848,  151.2664,  160.4959,  170.0784,  180.0183,
       190.3203,  200.9887,  212.0277,  223.4415,  235.2338,  247.4085,
       259.9691,  272.9191,  286.2617,  300.0000,  314.1369,  328.6753,
       343.6176,  358.9665,  374.7241,  390.8926,  407.4738,  424.4698,
       441.8819,  459.7118,  477.9607,  496.6298,  515.7200,  535.2322,
       555.1669,  575.5248,  596.3062,  617.5112,  639.1398,  661.1920,
       683.6673,  706.5654,  729.8857,  753.6275,  777.7897,  802.3714,
       827.3713,  852.7880,  878.6201,  904.8659,  931.5236,  958.5911,
       986.0666,  1013.9476, 1042.2319, 1070.9170, 1100.0000,
      ]
N_PLS = len(PLS)

# 2D variables to extract
D2_VARS = [
           'XLAT', 'XLONG', 'SZA', 'HGT',
           'CBASEHT', 'CTOPHT', 'CBASEHT_TOT', 'CTOPHT_TOT', 'CLRNIDX',
           'LANDMASK', 'SSTSK', 'TSK', 'PSFC', 'Q2', 'T2'
          ]
D2_VARS = sorted(D2_VARS)

# 3D variables to extract and interpolate, see utilities below
D3_RAW_VARS = ['QVAPOR', 'CLDFRA'] 
N_D3R = len(D3_RAW_VARS)

# 3D variables to get and interpolate, see utilities below
D3_VARS = ['height', 'temp',]
D3_units = ['dm', 'K',] 
N_D3 = len(D3_VARS)
D3_INT_VARS = sorted(D3_VARS + D3_RAW_VARS)  

# cache variables
CACHE_VARS = ['P', 'PSFC', 'PB', 'PH', 'PHB', 'T', 'QVAPOR', 'HGT', 'U', 'V', 'W']
CACHE_VARS = set.union(set(CACHE_VARS), set(D2_VARS), set(D3_RAW_VARS))
CACHE_VARS = sorted(list(CACHE_VARS))

##################################################################################
# batch processing WRF outputs to NetCDF files

def batch_process_netcdf(names):
    # generate file cache for performance
    wrfin = [Dataset(x) for x in names]
    wrf_cache = extract_vars(wrfin, ALL_TIMES, CACHE_VARS) 
                                          
    # split string name for dates 
    if names[0] == names[-1]:
        # only a single file
        t0_split_name = names[0].split('_')
        date0 = t0_split_name[-2]
        time0 = t0_split_name[-1]
        date_range = date0 + '_' + time0    

    else:
        # contains a date range
        t0_split_name = names[0].split('_')
        t1_split_name = names[-1].split('_')
        date0 = t0_split_name[-2]
        time0 = t0_split_name[-1]
        date1 = t1_split_name[-2]
        time1 = t1_split_name[-1]
        date_range = date0 + '_' + time0 + '-' + date1 + '_' + time1    
    print(STR_INDT + 'Processing dates ' + date_range)
    
    # initialize output NetCDF output file
    out_name = f_out_path + 'processed_' + domain + '_' + date_range + '.nc' 
    print(STR_INDT + 'Creating file ' + out_name)
    
    with Dataset(out_name, 'w', format='NETCDF4') as dst:
        # define reference dataset for NetCDF dimension creation
        src = wrfin[0]
        
        # copy global attributes all at once via dictionary
        dst.setncatts(src.__dict__)
        
        # copy dimensions
        for name, dimension in src.dimensions.items():
            if name == 'bottom_top':
                # set the vertical levels to the interpolated pressure levels
                print(2*STR_INDT + 'Creating dimension ' + name)
                dst.createDimension(name, N_PLS)
        
            elif name[-4:] == 'stag':
                # remove unecessary dimensions
                pass
        
            elif dimension.isunlimited(): 
                # set time as unlimited dimension
                print(2*STR_INDT + 'Creating dimension ' + name)
                dst.createDimension(name, None)
            
            else:
                # copy all other dimensions
                print(2*STR_INDT + 'Creating dimension ' + name)
                dst.createDimension(name, len(dimension))
        
        # extract 2D fields from cache
        for name, variable in src.variables.items():
            if name in D2_VARS:
                print(3*STR_INDT + 'Copying ' + name)
                x = dst.createVariable(name, variable.datatype,
                                       variable.dimensions)
                d2_var = wrf_cache[name]

                # reshape array to dimensions
                d2_data = d2_var.data
                var_shape = np.shape(d2_data)
                if len(var_shape) == 2:
                    y_dim, x_dim = np.shape(d2_data)
                    d2_data = np.reshape(d2_data, [1, y_dim, x_dim])
                    x[:, :, :] = d2_data

                else:
                    x[:, :, :] = d2_data
        
                # set attributes
                d2_attrs = d2_var.attrs
                del d2_attrs['projection']
                x.setncatts(d2_attrs)
        
        if omp_enabled:
            # set opm parameters for parallelism
            omp_np = omp_get_num_procs()
            print(2*STR_INDT + 'Running OpenMP with ' +
                  str(omp_np) + ' processes')
            omp_set_num_threads(omp_np)
        
        # extract the pressures
        p_ds = getvar(wrfin, 'pressure', cache=wrf_cache)
        
        # specific humidity is reference 3D variable for datatype / dimensions
        q_ds = src['QVAPOR']
        
        # interpolate 3D fields to pressure levels
        for k in range(N_D3R):
            print(3*STR_INDT + 'Interpolating ' + D3_RAW_VARS[k])
            x = dst.createVariable(D3_RAW_VARS[k], q_ds.datatype, q_ds.dimensions)

            for i in range(N_PLS):
                print(4*STR_INDT + 'Pressure level ' + str(PLS[i]))
                pl_var = process_D3_raw_vars(wrfin, p_ds, PLS[i], D3_RAW_VARS[k],
                                             cache=wrf_cache)
                # reshape array to dimensions
                if N_PER_OUT == 1:
                    pl_data = pl_var.data
                    y_dim, x_dim = np.shape(pl_data)
                    pl_data = np.reshape(pl_data, [1, 1, y_dim, x_dim]) 
                    x[:, i, :, :] = pl_data

                else:
                    pl_data = pl_var.data
                    t_dim, y_dim, x_dim = np.shape(pl_data)
                    pl_data = np.reshape(pl_data, [t_dim, 1, y_dim, x_dim]) 
                    x[:, i, :, :] = pl_data

            pl_attrs = pl_var.attrs
            del pl_attrs['projection']
            del pl_attrs['_FillValue']
            x.setncatts(pl_attrs)
        
        for k in range(N_D3):
            print(3*STR_INDT + 'Interpolating ' + D3_VARS[k])
            x = dst.createVariable(D3_VARS[k], q_ds.datatype, q_ds.dimensions)
        
            for i in range(N_PLS):
                print(4*STR_INDT + 'Pressure level ' + str(PLS[i]))
                pl_var = process_D3_vars(wrfin, p_ds, PLS[i], D3_VARS[k],
                                         D3_units[k], cache=wrf_cache)
        
                # reshape array to dimensions
                if N_PER_OUT == 1:
                    pl_data = pl_var.data
                    y_dim, x_dim = np.shape(pl_data)
                    pl_data = np.reshape(pl_data, [1, 1, y_dim, x_dim]) 
                    x[:, i, :, :] = pl_data

                else:
                    pl_data = pl_var.data
                    t_dim, y_dim, x_dim = np.shape(pl_data)
                    pl_data = np.reshape(pl_data, [t_dim, 1, y_dim, x_dim]) 
                    x[:, i, :, :] = pl_data
            
            pl_attrs = pl_var.attrs
            del pl_attrs['projection']
            del pl_attrs['_FillValue']
            x.setncatts(pl_attrs)

        print(STR_INDT + 'Completed processing dates ' + date_range)

##################################################################################
# process data

# Read out variables and pressure levels to process
print('Extracting 2D Vars')
for name in D2_VARS:
    print(STR_INDT + name)

print('Interpolating ' + str(N_PLS) + ' pressure levels:')
for name in PLS:
    print(STR_INDT + str(name))

print('Interpolating 3D Vars to pressure levels:')
for name in D3_INT_VARS:
    print(STR_INDT + name)

# time processing
t0 = time.time()
print('Batch processing start')

# create sorted list of file names, bash wild card for dates
fnames = sorted(glob.glob(F_IN_PATH + 'wrfout_' + DOMAIN + '*'))

# reduce the full list to the observation times for the particular simulation
fnames = fnames[16:64]
num_f = len(fnames)

# Compute number of batches based on number of files per output
n_batch = int(math.ceil(len(fnames) / N_PER_OUT))
print(str(n_batch) + ' total batches of ' + str(N_PER_OUT) +
      ' files per batch combined in processed outputs')

# loop file names in increments of N_PER_OUT
for k in range(n_batch):
    if k == (n_batch - 1):
        print('Start batch ' + str(k+1) + ' of ' + str(n_batch))
        batch_process_netcdf(fnames[k * N_PER_OUT:])
    else:
        print('Start batch ' + str(k+1) + ' of ' + str(n_batch))
        batch_process_netcdf(fnames[k * N_PER_OUT : (k+1) * N_PER_OUT])

t1 = time.time()
print('Batch processing complete')
print('Ellapsed ' + str( (t1 - t0) / 60 ) + ' minutes - Processed ' +
      str(num_f) + ' files')

##################################################################################
# end
