##################################################################################
# Description
##################################################################################
# This script is designed to ingest a specific wrfout output file and to
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
# Copyright 2022 CW3E, Contact Colin Grudzien cgrudzien@ucsd.edu
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
import sys
from datetime import datetime as dt
from datetime import timedelta
from wrf import (
        to_np, get_cartopy, cartopy_xlim, getvar,
        cartopy_ylim, latlon_coords, ll_to_xy,
        )
from wrf_py_utilities import (
        process_D3_vars, process_D3_raw_vars, comp_IVT_IWV,
        )
from py_plt_utilities import STR_INDT

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# read in paths and start / analysis date time from function call
IN_DIR = sys.argv[1] 
OUT_DIR = sys.argv[2]
START_DT = sys.argv[3]
ANL_START = int(sys.argv[4])
ANL_INT = int(sys.argv[5])
ANL_END = int(sys.argv[6])

# pressure levels to interpolate to
PLVS = [250, 500, 700, 850, 925]

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
# make output root
os.system('mkdir -p ' + OUT_DIR)
anl_hrs = range(ANL_START, ANL_END + 1, ANL_INT)

# convert to date time object
start_dt = dt.fromisoformat(START_DT)

# define the total number of vars to process
n_vars = len(IN_VARS)

print('Begin analysis of simulations starting on ' + START_DT)
print('Processing variables:')
for i in range(n_vars):
    print(STR_INDT + IN_VARS[i] + ' in units ' + UNITS[i] + ' to ' + OUT_VARS[i])
    
domains = []
print('Over domains:')
for i in range(1, MAX_DOM + 1):
    print(STR_INDT + 'd0%s'%i)
    exec('domains.append(\'d0%i\')'%i)
    
# loop over analysis hours
for hr in anl_hrs:
    # output formatted analysis date time string
    anl_dt = start_dt + timedelta(hours=hr)
    anl_dt = anl_dt.strftime('%Y-%m-%d_%H:%M:%S')
    print(STR_INDT + 'Begin analysis of simulation hour ' + anl_dt)

    # define storage for each domain's output files
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
        fname = IN_DIR + '/wrfout_' + domains[i] + '_' + anl_dt
        print(STR_INDT * 2 + 'Opening file ' + fname)
        try:
            nc_files.append(Dataset(fname))
        except:
            print(fname + ' does not exist, skipping')
            pass
    
        # extract the pressures in domain
        print(STR_INDT * 2 + 'Extracting pressure levels')
        p_ds.append(getvar(nc_files[i], 'pressure'))
    
        # Get the latitude and longitude points of domain
        print(STR_INDT * 2 + 'Extracting lat and lon values for grid')
        lat, lon = latlon_coords(p_ds[i])
        lats.append(to_np(lat))
        lons.append(to_np(lon))
        
        # get the boundary of the domain
        x_lim = cartopy_xlim(p_ds[i])
        y_lim = cartopy_ylim(p_ds[i])
        x_lims.append(x_lim)
        y_lims.append(y_lim)
        
        # grid the points in x / y ON THE PARENT DOMAIN 
        print(STR_INDT * 2 +\
                'Extracting x / y grid values corresponding to parent domain')
        xx, yy = ll_to_xy(nc_files[0], lat, lon, meta=False)  
        xxs.append(xx)
        yys.append(yy)
    
    # get the cartopy mapping object of parent domain
    cart_proj = get_cartopy(p_ds[0])
        
    # create storage for data
    data = {
            'cart_proj' : cart_proj,
            'date' : anl_dt,
           }
    
    for i in range(MAX_DOM):
        print(STR_INDT * 2 + 'Begin processing domain ' + domains[i])
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
        print(STR_INDT * 2 + 'Begin interpolating 3D fields to pressure levels:')
        for pl in PLVS:
            print(STR_INDT * 3 + 'Interpolating pressure level ' + str(pl))
            key = 'pl_' + str(pl)
            data[domains[i]][key] = {}
    
            for k in range(n_vars):
                print(STR_INDT * 4 + 'Variable ' + IN_VARS[k] +\
                        ' interpolated to ' + OUT_VARS[k])
                pl_var = process_D3_vars(nc_files[i], p_ds[i],
                                         pl, IN_VARS[k], UNITS[k])
    
                data[domains[i]][key][OUT_VARS[k]] = to_np(pl_var) 
        
        # extract / compute 2D fields and add to data dict
        print(STR_INDT * 2 + 'Begin processing 2D fields:')
        print(STR_INDT * 3 + 'Sea level pressure')
        data[domains[i]]['slp'] = to_np(getvar(nc_files[i], 'slp', units='hPa'))
        print(STR_INDT * 3 + 'IVT and IWV')
        ivtm, ivtu, ivtv, iwv = comp_IVT_IWV(nc_files[i], p_ds[i])
        data[domains[i]]['ivtm'] = to_np(ivtm) 
        data[domains[i]]['ivtu'] = to_np(ivtu)
        data[domains[i]]['ivtv'] = to_np(ivtv)
        data[domains[i]]['iwv']  = to_np(iwv) 
    
        if i >=1:
            print(STR_INDT * 2 +\
                    'Find parent grid indices that lie within the nested domain')
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
    
        print(STR_INDT * 2 + 'Finished processing domain ' + domains[i])
    
    print(STR_INDT * 2 + 'Completed processing all domains')
    fname = OUT_DIR + '/start_' + START_DT + '_forecast_' + anl_dt + '.bin'
    print(STR_INDT * 2 + 'Writing processed data out to ' + fname)
    f = open(fname, 'wb')
    pickle.dump(data,f)
    f.close()

##################################################################################
# end
