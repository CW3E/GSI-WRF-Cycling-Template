##################################################################################
# Description
##################################################################################
# This script is designed to ingest a specific  wrfout output file and to
# interpolate fields onto specified pressure levels, organized into heirarchical
# dictionaries containing numpy arrays. Assuming completely heirarchical nesting
# of domains, this provides the x-y grid coordinates for nested domains relative
# to the parent domain, and provides bounds of the nest on that grid. This script
# is then designed for simple numpy based plotting, to be extended further in
# later versions.
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
# Imports
##################################################################################
from netCDF4 import Dataset
import numpy as np
import pickle
import os
from wrf import (
        to_np, get_cartopy, cartopy_xlim, getvar,
        cartopy_ylim, latlon_coords, ll_to_xy,
        )
from wrf_py_utilities import (
        process_D3_vars, process_D3_raw_vars, comp_IVT_IWV,
        )
from py_plt_utilities import STR_INDT, PROJ_ROOT

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast'

# start date time of WRF forecast in YYYYMMDDHH
START_DT = '2019021300'

# pressure levels to interpolate to
PLVS = [250, 500, 700, 850, 925]

# analysis date time of inputs / outputs 
ANL_DT = '2019-02-14_00:00:00'

# domains to be processed, this assumes completely heirarchical nesting
MAX_DOM = 2

# 3D variables to extract and units
IN_VARS = ['z',  'ua', 'va', 'temp', 'rh', 'wspd_wdir']
UNITS =   ['dm', 'kt', 'kt', 'K',    '',   'kts']

# 3D pressure-level interpolated variables to save
OUT_VARS = ['geop', 'u', 'v', 'temp', 'rh', 'wspd']

##################################################################################
# Process data
##################################################################################
# define derived paths
data_root = PROJ_ROOT + '/data/forecast_io/' + CTR_FLW
out_dir = PROJ_ROOT + '/data/analysis/' + CTR_FLW
in_path = data_root + '/' + START_DT + '/wrfprd/ens_00'
out_path = out_dir + '/processed_numpy/' + START_DT
os.system('mkdir -p ' + out_path)

# define all domains
domains = []

# define the total number of vars to process
n_vars = len(IN_VARS)

print('Begin analysis')
print('Processing variables:')
for i in range(n_vars):
    print(STR_INDT + IN_VARS[i] + ' in units ' + UNITS[i] + ' to ' + OUT_VARS[i])

print('Over domains:')
for i in range(1, MAX_DOM + 1):
    print(STR_INDT + 'd0%s'%i)
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
    fname = in_path + '/wrfout_' + domains[i] + '_' + ANL_DT
    print('Opening file ' + fname)
    nc_files.append(Dataset(fname))

    # extract the pressures in domain
    print(STR_INDT + 'Extracting pressure levels')
    p_ds.append(getvar(nc_files[i], 'pressure'))

    # Get the latitude and longitude points of domain
    print(STR_INDT + 'Extracting lat and lon values for grid')
    lat, lon = latlon_coords(p_ds[i])
    lats.append(to_np(lat))
    lons.append(to_np(lon))
    
    # get the boundary of the domain
    x_lim = cartopy_xlim(p_ds[i])
    y_lim = cartopy_ylim(p_ds[i])
    x_lims.append(x_lim)
    y_lims.append(y_lim)
    
    # grid the points in x / y ON THE PARENT DOMAIN 
    print(STR_INDT +\
            'Extracting x / y grid values corresponding to parent domain')
    xx, yy = ll_to_xy(nc_files[0], lat, lon, meta=False)  
    xxs.append(xx)
    yys.append(yy)

# get the cartopy mapping object of parent domain
cart_proj = get_cartopy(p_ds[0])
    
# create storage for data
data = {
        'cart_proj' : cart_proj,
        'date' : ANL_DT,
       }

for i in range(MAX_DOM):
    print('Begin processing domain ' + domains[i])
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
    print(STR_INDT + 'Begin interpolating 3D fields to pressure levels:')
    for pl in PLVS:
        print(STR_INDT * 2+ 'Interpolating pressure level ' + str(pl))
        key = 'pl_' + str(pl)
        data[domains[i]][key] = {}

        for k in range(n_vars):
            print(STR_INDT * 3 + 'Variable ' + IN_VARS[k] +\
                    ' interpolated to ' + OUT_VARS[k])
            pl_var = process_D3_vars(nc_files[i], p_ds[i],
                                     pl, IN_VARS[k], UNITS[k])

            data[domains[i]][key][OUT_VARS[k]] = to_np(pl_var) 
    
    # extract / compute 2D fields and add to data dict
    print(STR_INDT + 'Begin processing 2D fields:')
    print(STR_INDT * 2 + 'Sea level pressure')
    data[domains[i]]['slp'] = to_np(getvar(nc_files[i], 'slp', units='hPa'))
    print(STR_INDT * 2 + 'IVT and IWV')
    ivtm, ivtu, ivtv, iwv = comp_IVT_IWV(nc_files[i], p_ds[i])
    data[domains[i]]['ivtm'] = to_np(ivtm) 
    data[domains[i]]['ivtu'] = to_np(ivtu)
    data[domains[i]]['ivtv'] = to_np(ivtv)
    data[domains[i]]['iwv']  = to_np(iwv) 

    if i >=1:
        print(STR_INDT + 'Find parent grid indices that lie within the nested domain')
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

    print('Finished processing domain ' + domains[i])

print('Completed processing all domains')
fname = out_path + '/start_' + START_DT + '_forecast_' + ANL_DT + '.bin'
print('Writing processed data out to ' + fname)
f = open(fname, 'wb')
pickle.dump(data,f)
f.close()

##################################################################################
# end
