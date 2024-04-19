##################################################################################
# Description
##################################################################################
# This will plot IVT and pressure contour data generated from the companion
# script proc_wrfout_np.py.  The plotting script will null out values of the
# parent domain lying in nested domains, currently only developed for two
# domains.  This will plot modified wind barbs for IVT directional components
# and magnitude as a heat map.
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
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import get_cmap
from matplotlib.colorbar import Colorbar as cb
import seaborn as sns
import cartopy.crs as crs
import cartopy.feature as cfeature
import numpy as np
import pickle
import os
from datetime import datetime as dt
from datetime import timedelta
from py_plt_utilities import USR_HME

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast_lag00_b0.00'

# define case-wise sub-directory
CSE="VD"

# start date time of WRF forecast
START_DT = '2019-02-14_00:00:00'

# valid date time for analysis
ANL_DT = '2019-02-14_00:00:00'

# max domain to plot
MAX_DOM = 2

##################################################################################
# Begin plotting
##################################################################################
# convert from iso times
anl_dt = dt.fromisoformat(ANL_DT)
start_dt = dt.fromisoformat(START_DT)

# define derived data paths 
param = CTR_FLW.split('_')[-1]
cse = CSE + '/' + CTR_FLW
data_root = USR_HME + '/data/analysis/' + cse + '/WRF_analysis'
in_path = data_root + '/' + start_dt.strftime('%Y%m%d%H')
out_path = data_root + '/ivt_plots'
os.system('mkdir -p ' + out_path)

# load data
f = open(in_path + '/start_' + START_DT + '_forecast_' + ANL_DT + '.bin', 'rb')
data = pickle.load(f)
f.close()

# load the projection
cart_proj = data['cart_proj']

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.86, .08, .05, .8])
ax1 = fig.add_axes([.05, .08, .8, .8], projection=cart_proj)
ax2 = fig.add_axes(ax1.get_position(), frameon=False)
ax3 = fig.add_axes([0.0, .03, .8, .05], frameon=False)

# hard set the ivt magnitude threshold to target ARs
ivtm_min = 250
ivtm_max = 1200
cnorm = nrm(vmin=ivtm_min, vmax=ivtm_max)
color_map = sns.color_palette('flare', as_cmap=True)

# extract ivtm
ivtm_d01 = data['d01']['ivtm'].flatten()
if MAX_DOM == 2:
    ivtm_d02 = data['d02']['ivtm'].flatten()
    ivtms = [ivtm_d01, ivtm_d02]
else:
    ivtms = [ivtm_d01]

# find the index of values that lie below the ivtm_min
indxs = [[], []]
for i in range(MAX_DOM):
    for k in range(len(ivtms[i])):
        if ivtms[i][k] < ivtm_min:
            indxs[i].append(k)

if MAX_DOM == 2:
    # NaN out all values of d01 that lie in d02
    ivtm_d01[data['d02']['indx']] = np.nan

# NaN out all values of both domains that lie below the threshold
ivtm_d01[indxs[0]] = np.nan
if MAX_DOM == 2:
    ivtm_d02[indxs[1]] = np.nan

# plot ivtm as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=ivtm_d01,
            alpha=1.000,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=20,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

if MAX_DOM == 2:
    # plot ivtm as intensity in scatter / heat plot for nested domain
    ax1.scatter(x=data['d02']['lons'], y=data['d02']['lats'],
                c=ivtm_d02,
                alpha=0.600,
                cmap=color_map,
                norm=cnorm,
                marker='.',
                s=1,
                edgecolor='none',
                transform=crs.PlateCarree(),
               )

    # bottom boundary
    ax1.plot(
             [data['d02']['x_lim'][0], data['d02']['x_lim'][1]],
             [data['d02']['y_lim'][0], data['d02']['y_lim'][0]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # top boundary
    ax1.plot(
             [data['d02']['x_lim'][0], data['d02']['x_lim'][1]],
             [data['d02']['y_lim'][1], data['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # left boundary
    ax1.plot(
             [data['d02']['x_lim'][0], data['d02']['x_lim'][0]],
             [data['d02']['y_lim'][0], data['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # right boundary
    ax1.plot(
             [data['d02']['x_lim'][1], data['d02']['x_lim'][1]],
             [data['d02']['y_lim'][0], data['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )

# add slp contour plot
c_pl = ''
c_var = 'slp'
c_var_pl = np.array(data['d01'][c_var]).flatten()
c_var_levels =[1000, 1008, 1016, 1024]

# shape contour data for contour function in x / y coordinates
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
c_indx = np.shape(np.array(lons))
c_var_pl = np.reshape(c_var_pl, c_indx)
xx = np.reshape(data['d01']['xx'], c_indx)
yy = np.reshape(data['d01']['yy'], c_indx)

# keep min / max values for plot boundaries
x_min = np.min(xx)
x_max = np.max(xx)
y_min = np.min(yy)
y_max = np.max(yy)

# make contour plot with inline labels
CS = ax2.contour(
                 xx,
                 yy,
                 c_var_pl,
                 colors='black',
                 linestyles='dashdot',
                 levels=c_var_levels,
                )

ax2.clabel(CS, CS.levels, inline=True, fontsize=20)

# add geog / cultural features
ax1.add_feature(cfeature.COASTLINE)
ax1.add_feature(cfeature.STATES)
ax1.add_feature(cfeature.BORDERS)

# Add ivt u / v directional barbs plotting every w_kth point above the threshold
w_k = 1000
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
ivtx = lons.flatten()
ivty = lats.flatten()
ivtu = data['d01']['ivtu'].flatten() 
ivtv = data['d01']['ivtv'].flatten()

# delete the ivt vectors that fall below the threshold
ivtx = np.delete(ivtx, indxs[0])
ivty = np.delete(ivty, indxs[0])
ivtu = np.delete(ivtu, indxs[0])
ivtv = np.delete(ivtv, indxs[0])

barb_incs = {
             'half':50,
             'full':100,
             'flag':500,
            }

ax1.barbs(
          ivtx[int(w_k/2)::w_k], ivty[int(w_k/2)::w_k],
          ivtu[int(w_k/2)::w_k], ivtv[int(w_k/2)::w_k],
          transform=crs.PlateCarree(), 
          length=7,
          barb_increments=barb_incs,
         )

# create barb legend
ax3.barbs(
        [0, 0.5, 1],
        [0, 0, 0],
        [50, 100, 500],
        [0, 0, 0],
        length=10,
        barb_increments=barb_incs,
        )

ax3.set_xlim([-0.15, 1.2])
ax3.set_ylim([0.0, 0.05])
ax3.tick_params(
        bottom=False,
        labelbottom=False,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        top=False,
        labeltop=False,
        )

ax2.tick_params(
        bottom=False,
        labelbottom=False,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        top=False,
        labeltop=False,
        )

ax3.text(0.02, 0, 'IVT Magnitude 50',  {'fontsize': 18})
ax3.text(0.52, 0, 'IVT Magnitude 100', {'fontsize': 18})
ax3.text(1.02, 0, 'IVT Magnitude 500', {'fontsize': 18})

# Add a color bar
cb(ax=ax0, cmap=color_map, norm=cnorm)
ax0.tick_params(
    labelsize=21,
    )

# Set the map bounds
ax1.set_xlim(data['d01']['x_lim'])
ax1.set_ylim(data['d01']['y_lim'])
ax2.set_xlim([x_min, x_max])
ax2.set_ylim([y_min, y_max])
ax2.set_position(ax1.get_position())

# Add the gridlines
ax1.gridlines(color='black', linestyle='dotted')

# make title and save figure
title1 = anl_dt.strftime('%Y-%m-%dT%H') + r' - IVT $kg $ $m^{-1} s^{-1}$ ' +\
        c_pl + ' ' + c_var + ' contours'
title2 = 'fzh - ' + start_dt.strftime('%Y-%m-%dT%H') + ' ' + param

plt.figtext(.50, .96, title1, horizontalalignment='center',
        verticalalignment='center', fontsize=22)
plt.figtext(.50, .91, title2, horizontalalignment='center',
        verticalalignment='center', fontsize=22)

fig.savefig(out_path + '/' + CTR_FLW + '_' + anl_dt.strftime('%Y-%m-%dT%H') +\
        '_fzh_' + start_dt.strftime('%Y-%m-%dT%H') + '_ivt_' + c_var + '.png')
plt.show()

##################################################################################
# end
