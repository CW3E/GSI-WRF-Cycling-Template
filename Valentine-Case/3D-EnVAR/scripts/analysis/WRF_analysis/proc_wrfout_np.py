##################################################################################
# Description
##################################################################################
#
##################################################################################
# License Statement
##################################################################################
#
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
# 
##################################################################################
# imports / exports
from netCDF4 import Dataset
import numpy as np
import pickle
import os
from wrf import (
        to_np, get_cartopy, cartopy_xlim, getvar,
        cartopy_ylim, latlon_coords, ll_to_xy,
        )
from wrf_py_utilities import (
        process_D3_vars, process_D3_raw_vars, comp_IVT_IWV, str_indt,
        )

##################################################################################
# set data processing parameters

START_DATE = '2019021400'

# path to project 
PROJ_DIR = '/cw3e/mead/projects/cwp130/scratch/cgrudzien/' +\
                   'GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR'

# input / save file directory path
INPUT_DATA_ROOT = PROJ_DIR + '/data/forecast_io/deterministic_forecast'
OUTPUT_DATA_ROOT = PROJ_DIR + '/data/analysis/deterministic_forecast'

##################################################################################
# process data
f_in_path = INPUT_DATA_ROOT + '/' + START_DATE + '/wrfprd/ens_00'
f_out_path = OUTPUT_DATA_ROOT + '/processed_numpy/' + START_DATE
os.system('mkdir -p ' + f_out_path)

# pressure levels to interpolate to and date of inputs / outputs
pls = [250, 500, 700, 850, 925]
date = '2019-02-14_00:00:00'

# domains to be processed, this assumes completely heirarchical nesting
MAX_DOM = 2

# 3D variables to extract and units
in_vars = ['z',  'ua', 'va', 'temp', 'rh', 'wspd_wdir']
units =   ['dm', 'kt', 'kt', 'K',    '',   'kts']

# 3D pressure-level interpolated variables to save
out_vars = ['geop', 'u', 'v', 'temp', 'rh', 'wspd']

##################################################################################
# process data

# define all domains
domains = []

# define the total number of vars to process
n_vars = len(in_vars)

for i in range(1, MAX_DOM + 1):
    exec('domains.append(\'d0%i\')'%i)

nc_files = []
p_ds = []
lats = []
lons = []
x_lims = []
y_lims = []
xxs = []
yys = []

for i in range(MAX_DOM):
    # Open the NetCDF files
    nc_files.append(Dataset(f_in_path + '/wrfout_' + domains[i] + '_' + date))

    # extract the pressures in domain
    p_ds.append(getvar(nc_files[i], 'pressure'))

    # Get the latitude and longitude points of domain
    lat, lon = latlon_coords(p_ds[i])
    lats.append(to_np(lat))
    lons.append(to_np(lon))
    
    # get the boundary of the domain
    x_lim = cartopy_xlim(p_ds[i])
    y_lim = cartopy_ylim(p_ds[i])
    x_lims.append(x_lim)
    y_lims.append(y_lim)
    
    # grid the points in x / y ON THE PARENT DOMAIN 
    xx, yy = ll_to_xy(nc_files[0], lat, lon, meta=False)  
    xxs.append(xx)
    yys.append(yy)

# get the cartopy mapping object of parent domain
cart_proj = get_cartopy(p_ds[0])
    
# create storage for data
data = {
        'cart_proj' : cart_proj,
        'date' : date,
       }

for i in range(MAX_DOM):
    # add grid data under domain key
    data[domains[i]] = { 
                        'xx' : xxs[i],
                        'yy' : yys[i],
                        'lons' : lons[i],
                        'lats' : lats[i],
                        'x_lim' : x_lims[i],
                        'y_lim' : y_lims[i],
                       }

    # interpolate 3D fields to pressure levels and add to data dict
    for pl in pls:
        key = 'pl_' + str(pl)
        data[domains[i]][key] = {}

        for k in range(n_vars):
            pl_var = process_D3_vars(nc_files[i], p_ds[i],
                                     pl, in_vars[k], units[k])

            data[domains[i]][key][out_vars[k]] = to_np(pl_var) 
    
    # extract / compute 2D fields and add to data dict
    data[domains[i]]['slp'] = to_np(getvar(nc_files[i], 'slp', units='hPa'))
    ivtm, ivtu, ivtv, iwv = comp_IVT_IWV(nc_files[i], p_ds[i])
    data[domains[i]]['ivtm'] = to_np(ivtm) 
    data[domains[i]]['ivtu'] = to_np(ivtu)
    data[domains[i]]['ivtv'] = to_np(ivtv)
    data[domains[i]]['iwv']  = to_np(iwv) 

    if i >=1:
        # find the min / max indices of the nest grid
        d_end = [
                   [np.min(xxs[i]), np.max(xxs[i])],
                   [np.min(yys[i]), np.max(yys[i])],
                  ]
        
        lines = len(xxs[0])
        indx = []
        
        # find all indices of the parent domain that lie within the nest
        for j in range(lines):
            if (
                xxs[0][j] >= d_end[0][0] and\
                xxs[0][j] <= d_end[0][1] and\
                yys[0][j] >= d_end[1][0] and\
                yys[0][j] <= d_end[1][1]
               ):
                indx.append(j)

        # append indices for the values of the parent domain lying in the nest
        data[domains[i]]['indx'] = indx,

f = open(f_out_path + '/start_' + START_DATE + '_forecast_' + date + '.txt', 'wb')
pickle.dump(data,f)
f.close()

##################################################################################
# end
