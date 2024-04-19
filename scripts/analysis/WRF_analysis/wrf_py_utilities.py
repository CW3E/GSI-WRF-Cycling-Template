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
