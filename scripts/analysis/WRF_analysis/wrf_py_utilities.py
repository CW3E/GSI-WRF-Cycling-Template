##################################################################################
# Description
##################################################################################
# This module contains utility methods for using WRF-py diagnostics and
# interpolation tools to process wrfout files from standard WRF real-data runs.
# IVT and IWV calculations are based on original source code shared with this
# repository, written by Minghua Zheng (UCSD), Alexander Goodman (JPL) and
# Sierra Dabby (UC Berkeley). These methods are imported to use in the companion
# data processing scripts in this repository, but can also be used standalone
# for other data analysis purposes.
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
import cartopy
from wrf import (
                 getvar, interplevel, extract_vars, ALL_TIMES,
                )

##################################################################################
# UTILITY METHODS
##################################################################################
# gets and interpolates variable to pressure level with specified units available 

def process_D3_vars(ds, p_ds, pl, var, unit, cache=None):
    # uses getvar utility from WRF-py
    if unit:
        eta_var = getvar(ds, var, units=unit, cache=cache)
        int_var = interplevel(eta_var, p_ds, pl)

    else:
        eta_var = getvar(ds, var, cache=cache)
        int_var = interplevel(eta_var, p_ds, pl)

    return int_var

##################################################################################
# extracts and interpolates variable to pressure level

def process_D3_raw_vars(ds, p_ds, pl, var, cache=None):
    # uses extract_vars utility from WRF-py
    eta_var = extract_vars(ds, ALL_TIMES, var, cache=cache)[var]
    int_var = interplevel(eta_var, p_ds, pl)

    return int_var

##################################################################################
# if data is staggered in any dimension, interpolate to unstaggered grid

def unstaggered_grid(xarr):
    for dim in xarr.dims:
        if dim.endswith('_stag'):
            new_dim = dim.replace('_stag', '')
            attrs = xarr.attrs
            xarr = (xarr.rename({dim: new_dim})
                          .rolling({new_dim: 2})
                          .mean()
                          .isel({new_dim: slice(1, None)}))
            xarr.attrs.update(attrs)

    return xarr

##################################################################################
# compute IVT / IWV

def comp_IVT_IWV(nc_file, pres):
    # define constant c
    c = 100/9.8
    
    # compute specific humidity in eta coordinates
    qvapor = extract_vars(nc_file, None, "QVAPOR")["QVAPOR"]
    sphd_eta = qvapor / (1 + qvapor)
    
    # compute the minus-c-scaled change in pressures in eta coordinates
    dp_eta = -c * \
             pres.rolling(bottom_top=2).construct('win').diff('win').squeeze()
    
    # extract u component of wind profile over the eta coordinates
    u_eta = getvar(nc_file, 'ua')
    if 'Time' in u_eta.coords:
        u_eta = u_eta.drop('Time')

    # if data is staggered in any dimension, interpolate to unstaggered grid
    u_eta = unstaggered_grid(u_eta)

    # extract v component of wind profile over the eta coordinates
    v_eta = getvar(nc_file, 'va')
    if 'Time' in v_eta.coords:
        v_eta = v_eta.drop('Time')

    # if data is staggered in any dimension, interpolate to unstaggered grid
    v_eta = unstaggered_grid(v_eta)

    # compute du / dv over eta coordinates
    du_eta = u_eta.rolling(bottom_top=2).mean(skipna=False)
    dv_eta = v_eta.rolling(bottom_top=2).mean(skipna=False)

    # VT u component in eta coords 
    vtu_eta = dp_eta * \
              (du_eta * sphd_eta).rolling(bottom_top=2).mean(skipna=False)
    
    # VT v component in eta coords 
    vtv_eta = dp_eta * \
              (dv_eta * sphd_eta).rolling(bottom_top=2).mean(skipna=False)

    # WV in eta coordinates
    wv_eta = dp_eta * \
             sphd_eta.rolling(bottom_top=2).mean(skipna=False)

    # sum the eta levels for the integrated VT / WV over column
    ivtu = vtu_eta.sum('bottom_top') 
    ivtv = vtv_eta.sum('bottom_top') 
    ivw = wv_eta.sum('bottom_top') 

    # ivt compute magnitude
    ivtm = (ivtu**2 + ivtv**2)**(0.5) 

    return ivtm, ivtu, ivtv, ivw

##################################################################################
# end
